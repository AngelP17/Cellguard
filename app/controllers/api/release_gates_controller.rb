# frozen_string_literal: true

module Api
  class ReleaseGatesController < ApplicationController
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
        render json: body.merge(
          reason: "Error budget exhausted. Override requires justification + audit log.",
          violation_started_at: budget.violation_started_at
        ), status: :locked
      end
    end

    def override
      shard = Shard.find_by!(name: params.fetch(:shard))
      actor = params.fetch(:actor).to_s.strip
      justification = params.fetch(:justification).to_s.strip

      raise ActionController::BadRequest, "actor required" if actor.empty?
      raise ActionController::BadRequest, "justification required" if justification.empty?

      AuditLog.create!(
        shard: shard,
        actor: actor,
        action: "override_gate",
        justification: justification,
        metadata: { ip: request.remote_ip, user_agent: request.user_agent }
      )

      render json: { status: "override_recorded", shard: shard.name }
    end
  end
end
