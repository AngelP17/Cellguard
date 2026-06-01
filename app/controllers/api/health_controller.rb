# frozen_string_literal: true

# Health and readiness endpoints for Docker, load balancers, and operators.
#
# - GET /healthz  : liveness probe (process is up)
# - GET /readyz   : readiness probe (all dependencies reachable)
# - GET /status   : detailed status including version and component states
module Api
  class HealthController < ApplicationController
    include ::Api::StructuredErrors

    def healthz
      render json: { status: "ok", time: Time.current.iso8601 }
    end

    def readyz
      checks = {
        database: database_check,
        redis: redis_check,
        sidekiq: sidekiq_check,
        classifier: classifier_check
      }

      all_ok = checks.values.all? { |c| c[:status] == "ok" }

      render json: {
        status: all_ok ? "ready" : "degraded",
        checks: checks,
        time: Time.current.iso8601
      }, status: all_ok ? :ok : :service_unavailable
    end

    def status
      render json: {
        status: "ok",
        version: ::CellGuardVersion.label,
        git_sha: ::CellGuardVersion.git_sha,
        time: Time.current.iso8601,
        components: {
          database: database_check,
          redis: redis_check,
          sidekiq: sidekiq_check,
          classifier: classifier_check
        }
      }
    end

    private

    def database_check
      ActiveRecord::Base.connection.execute("SELECT 1")
      { status: "ok" }
    rescue StandardError => e
      { status: "down", error: e.message }
    end

    def redis_check
      url = ENV["REDIS_URL"].presence || "redis://localhost:6379/0"
      redis = Redis.new(url: url, timeout: 2)
      pong = redis.ping
      { status: pong == "PONG" ? "ok" : "down", response: pong.to_s }
    rescue StandardError => e
      { status: "down", error: e.message }
    ensure
      redis&.close
    end

    def sidekiq_check
      require "sidekiq/api"
      ps = Sidekiq::ProcessSet.new
      count = ps.size
      if count.positive?
        { status: "ok", workers: count }
      else
        { status: "down", workers: 0, note: "no registered sidekiq processes" }
      end
    rescue StandardError => e
      { status: "down", error: e.message }
    end

    def classifier_check
      require "net/http"
      require "uri"
      url = ENV["CLASSIFIER_URL"].presence || "http://localhost:8081"
      uri = URI.parse("#{url}/healthz")
      response = Net::HTTP.start(uri.host, uri.port, open_timeout: 2, read_timeout: 2) do |http|
        http.get(uri.path)
      end

      if response.is_a?(Net::HTTPSuccess)
        { status: "ok", url: url }
      else
        { status: "down", url: url, code: response.code.to_i }
      end
    rescue StandardError => e
      { status: "down", error: e.message }
    end
  end
end
