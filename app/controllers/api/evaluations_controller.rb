# frozen_string_literal: true

module Api
  class EvaluationsController < ApplicationController
    protect_from_forgery with: :null_session

    def create
      shard = Shard.find_by!(name: params.fetch(:shard))
      budget = BudgetEvaluator.new.evaluate!(shard: shard)

      minutes = params.fetch(:window_minutes, 60).to_i
      window_end = Time.current
      window_start = minutes.minutes.ago

      scope = shard.job_stats.where("period_end >= ? AND period_start <= ?", window_start, window_end)
      total = scope.sum(:job_count)
      errors = scope.sum(:error_count)
      error_rate = total.zero? ? 0.0 : (errors.to_f / total)

      payload = {
        "shard_id" => shard.name,
        "queue_namespace" => "default",
        "window_minutes" => minutes,
        "total" => total,
        "errors" => errors,
        "error_rate" => error_rate,
        "p95_latency_ms" => scope.maximum(:latency_p95_ms).to_i,
        "budget_remaining" => budget.budget_remaining.to_f,
        "slo_target" => budget.slo_target.to_f
      }

      classifier_url = ENV.fetch("CLASSIFIER_URL", "http://localhost:8081")
      decision = ClassifierClient.new(base_url: classifier_url).classify!(payload)

      if decision["is_violation"]
        severity = decision["action"] == "alert" ? "severity::1" : "severity::2"
        Incident.create!(
          shard: shard,
          title: "Shard violation: #{decision['reason']}",
          severity_label: severity,
          team_label: "team::Production Engineering::Scalability",
          service_label: "Service::Sidekiq",
          status: "active",
          context: {
            classifier: decision,
            budget: {
              remaining: budget.budget_remaining,
              burn_rate: budget.current_burn_rate
            }
          }
        )
      end

      render json: {
        shard: shard.name,
        budget: {
          remaining: budget.budget_remaining.to_f,
          consumed: budget.budget_consumed.to_f,
          burn_rate: budget.current_burn_rate.to_f,
          gate_open: budget.release_gate_open
        },
        classifier: decision
      }
    rescue KeyError => e
      render json: { error: "bad_request", message: e.message }, status: :bad_request
    end
  end
end
