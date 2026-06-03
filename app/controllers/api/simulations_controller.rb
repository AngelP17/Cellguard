# frozen_string_literal: true

module Api
  class SimulationsController < ApplicationController
    include ::Api::StructuredErrors
    include ::Api::TokenGuard

    protect_from_forgery with: :null_session

    def inject_failures
      require_admin_token!
      raise ActionController::Forbidden unless Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"

      shard_name = params.fetch(:shard)
      queue = params.fetch(:queue, "default")
      minutes = params.fetch(:minutes, 5).to_i
      error_rate = params.fetch(:error_rate, 0.10).to_f
      total = params.fetch(:total, 1000).to_i
      p95 = params.fetch(:p95_latency_ms, 650).to_i

      shard = Shard.find_or_create_by!(name: shard_name)
      period_end = Time.current
      period_start = minutes.minutes.ago

      JobStat.create!(
        shard: shard,
        queue_namespace: queue,
        period_start: period_start,
        period_end: period_end,
        job_count: total,
        error_count: (total * error_rate).round,
        latency_p95_ms: p95,
        meta: { injected: true, note: "demo injection" }
      )

      # === FULL fabric seeding (requirement: not just stub text, DB state) ===
      # Creates: workflow_run (with simple fields), warning alert, critical alert,
      # job link, snapshot (simple fields), job_stat, later incident link via evaluator.
      xyops = {}
      begin
        Xyops::Simulator.seed_workflows!
        conn = XyopsConnection.primary

        # 1. Workflow run
        wf = XyopsWorkflow.find_by(name: "nightly-fulfillment-sync") || XyopsWorkflow.first
        run = XyopsWorkflowRun.create!(
          workflow: wf,
          external_id: "run-#{Time.current.to_i}-inj",
          status: "failed",
          started_at: 3.minutes.ago,
          completed_at: Time.current,
          server_id: "print-worker-02",
          server_name: "print-worker-02",
          workflow_name: "nightly-fulfillment-sync",
          failed_job_name: "shipping-label-printer-check",
          context: { queue: queue, error_rate: error_rate, p95: p95 },
          metadata: { injected: true }
        )

        # 2/3. Warning then critical alert
        XyopsAlert.create!(
          connection: conn,
          external_id: "alert-warn-#{run.external_id}",
          severity: "warning",
          title: "Queue latency exceeded threshold",
          server_name: "print-worker-02",
          status: "active",
          fired_at: 2.minutes.ago,
          xyops_workflow_run_id: run.id,
          metadata: { source: "queue-latency" }
        )
        crit_alert = XyopsAlert.create!(
          connection: conn,
          external_id: "alert-crit-#{run.external_id}",
          severity: "critical",
          title: "Workflow failed: high error rate + latency",
          server_name: "print-worker-02",
          status: "active",
          fired_at: 90.seconds.ago,
          xyops_workflow_run_id: run.id,
          metadata: { injected: true }
        )

        # 4. Job link (failed job)
        XyopsJobLink.create!(
          xyops_workflow_run_id: run.id,
          xyops_alert_id: crit_alert.id,
          role: "trigger",
          failed_job_name: "shipping-label-printer-check",
          server_name: "print-worker-02",
          remediation_available: true,
          details: { phase: "degraded" }
        )

        # 5. Snapshot with simple fields
        snap = XyopsSnapshot.create!(
          connection: conn,
          server_id: "print-worker-02",
          server_name: "print-worker-02",
          external_id: "snap-#{Time.current.to_i}",
          captured_at: Time.current,
          cpu_pct: 92.0,
          cpu_percent: 92.0,
          mem_pct: 81.0,
          memory_percent: 81.0,
          network_summary: "redis latency elevated",
          network_status: "degraded",
          process_summary: [{ name: "fulfillment-worker", cpu: 67 }],
          metadata: { trigger: "inject_failures" }
        )
        XyopsJobLink.create!(
          xyops_snapshot_id: snap.id,
          role: "evidence",
          server_name: "print-worker-02"
        )

        # 6. job_stat already created above

        xyops = {
          workflow: "nightly-fulfillment-sync",
          failed_job: "shipping-label-printer-check",
          server: "print-worker-02",
          alert: "queue latency exceeded threshold",
          snapshot_created: true
        }
      rescue StandardError => e
        Rails.logger.warn("[xyops] fabric seed failed: #{e.message}")
      end

      render json: {
        status: "injected",
        shard: shard.name,
        queue: queue,
        xyops: xyops
      }
    end
  end
end
