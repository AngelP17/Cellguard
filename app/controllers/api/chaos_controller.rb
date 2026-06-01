# frozen_string_literal: true

require "shellwords"

module Api
  class ChaosController < ApplicationController
    include ::Api::StructuredErrors
    include ::Api::RequestAudit
    include ::Api::TokenGuard

    protect_from_forgery with: :null_session

    def partition
      require_admin_token!
      guard_demo!

      mode = params.fetch(:mode, "docker")
      seconds = params.fetch(:duration_seconds, 20).to_i

      result = case mode
      when "docker"
        ChaosService.new(nil).execute(:partition, mode: "docker", duration_seconds: seconds)
      when "tc"
        ChaosService.new(nil).execute(
          :partition,
          mode: "tc",
          duration_seconds: seconds,
          delay_ms: params.fetch(:delay_ms, 250).to_i,
          loss_percent: params.fetch(:loss_percent, 5).to_i
        )
      else
        return render json: { error: "unknown_mode" }, status: :bad_request
      end

      audit_request!(
        action: "chaos_partition",
        shard: Shard.find_by(name: "shard-default"),
        justification: "Chaos partition: mode=#{mode} seconds=#{seconds}",
        metadata: { mode: mode, seconds: seconds, result_status: result[:status].to_s }
      )

      if result[:status] == :failed
        render json: { error: "chaos_failed", details: result }, status: :unprocessable_entity
      else
        render json: result
      end
    end

    def heal
      require_admin_token!
      guard_demo!

      result = ChaosService.new(nil).heal
      audit_request!(
        action: "chaos_heal",
        shard: Shard.find_by(name: "shard-default"),
        justification: "Chaos heal triggered"
      )
      render json: { status: "heal_attempted", result: result }
    end

    private

    def guard_demo!
      return if Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"

      raise ActionController::Forbidden
    end
  end
end
