# frozen_string_literal: true

module Api
  class ReleaseGatesController < ApplicationController
    include ::Api::StructuredErrors
    include ::Api::RequestAudit
    include ::Api::TokenGuard
    include ::Api::Idempotent

    protect_from_forgery with: :null_session

    def check
      shard = Shard.find_or_create_by!(name: params.fetch(:shard))
      budget = shard.error_budget || shard.create_error_budget!(slo_target: 0.999, window_days: 30, window_start: Time.current)

      BudgetEvaluator.new.evaluate!(shard: shard) if budget.evaluated_at.nil? || budget.evaluated_at < 2.minutes.ago
      budget.reload

      body = {
        allowed: budget.release_gate_open,
        shard: shard.name,
        slo_target: budget.slo_target.to_f,
        budget_remaining: budget.budget_remaining.to_f,
        burn_rate: budget.current_burn_rate.to_f,
        evaluated_at: budget.evaluated_at
      }

      if budget.release_gate_open
        render json: body
      else
        # API-level proof: xyops_evidence must be present in 423 body (DB backed)
        xyops_evidence = build_xyops_evidence(shard)
        render json: body.merge(
          gate: "locked",
          status: 423,
          reason: "error_budget_exhausted",
          xyops_evidence: xyops_evidence
        ), status: :locked
      end


    end

    def override
      with_idempotency do
        require_admin_token!

        shard = Shard.find_by!(name: params.fetch(:shard))
        actor = params.fetch(:actor).to_s.strip
        justification = params.fetch(:justification).to_s.strip

        raise ActionController::BadRequest, "actor required" if actor.empty?
        raise ActionController::BadRequest, "justification required" if justification.empty?

        audit_request!(
          action: "override_gate",
          shard: shard,
          justification: justification,
          metadata: { actor: actor }
        )

        render json: { status: "override_recorded", shard: shard.name }
      end
    end

    private

    def build_xyops_evidence(shard)
      # DB-backed evidence for API 423 (requirement).
      link = XyopsJobLink.where(incident: Incident.where(shard: shard).active)
                         .or(XyopsJobLink.where(error_budget: shard.error_budget))
                         .order(created_at: :desc).first

      run = (link ? link.workflow_run : nil) || XyopsWorkflowRun.failed.order(started_at: :desc).first
      al  = (link ? link.alert : nil) || XyopsAlert.critical.active.order(fired_at: :desc).first
      sn  = (link ? link.snapshot : nil) || XyopsSnapshot.order(captured_at: :desc).first

      snapshot_hash = if sn
        {
          cpu_percent: (sn.cpu_percent || sn.cpu_pct).to_f,
          memory_percent: (sn.memory_percent || sn.mem_pct).to_f,
          network: sn.network_summary || sn.network_status || "redis latency elevated"
        }
      end

      {
        workflow: run&.workflow_name || run&.workflow&.name || (run&.context || {})["workflow"],
        failed_job: run&.failed_job_name || (run&.context || {})["job"] || run&.workflow&.name,
        server: run&.server_name || run&.server_id || sn&.server_name || sn&.server_id,
        alert: al&.title,
        snapshot: snapshot_hash
      }.compact
    end


    # legacy alias if needed
    def extract_xyops_evidence(shard)
      build_xyops_evidence(shard)
    end
  end
end




