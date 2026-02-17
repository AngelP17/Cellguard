# frozen_string_literal: true

module Api
  class SimulationsController < ApplicationController
    protect_from_forgery with: :null_session

    def inject_failures
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

      render json: { status: "injected", shard: shard.name, queue: queue }
    end
  end
end
