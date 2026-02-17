# frozen_string_literal: true

module Api
  class IngestController < ApplicationController
    protect_from_forgery with: :null_session

    def job_stat
      require_env_demo_or_token!

      shard = Shard.find_or_create_by!(name: params.fetch(:shard))
      queue = params.fetch(:queue_namespace)
      ps = Time.iso8601(params.fetch(:period_start))
      pe = Time.iso8601(params.fetch(:period_end))

      stat = JobStat.find_or_initialize_by(
        shard: shard,
        queue_namespace: queue,
        period_start: ps,
        period_end: pe
      )

      stat.job_count = params.fetch(:job_count).to_i
      stat.error_count = params.fetch(:error_count).to_i
      stat.latency_p95_ms = params.fetch(:latency_p95_ms).to_i
      stat.meta = (stat.meta || {}).merge(params[:meta].is_a?(Hash) ? params[:meta] : {})

      stat.save!
      render json: { status: "ok" }
    end

    private

    def require_env_demo_or_token!
      return if Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"

      token = request.headers["X-CELLGUARD-TOKEN"].to_s
      expected = ENV.fetch("CELLGUARD_TOKEN")
      return if token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)

      raise ActionController::Forbidden
    end
  end
end
