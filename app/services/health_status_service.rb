# frozen_string_literal: true

# Fetches the current system health status and exposes it to the layout.
# Cached for 10 seconds to avoid hammering the API.
class HealthStatusService
  class << self
    def current
      Rails.cache.fetch("cellguard:health_status", expires_in: 10.seconds) do
        fetch
      end
    rescue StandardError => e
      Rails.logger.warn("[HealthStatusService] cache fetch skipped: #{e.class}: #{e.message}") if defined?(Rails)
      fetch
    end

    def badge_label
      status = current
      case status
      when "ok", "ready" then "Healthy"
      when "degraded" then "Degraded"
      else "Unknown"
      end
    end

    def badge_class
      status = current
      case status
      when "ok", "ready" then "cg-health-badge cg-health-badge--ok"
      when "degraded" then "cg-health-badge cg-health-badge--warn"
      else "cg-health-badge cg-health-badge--unknown"
      end
    end

    private

    def fetch
      response = Faraday.get("http://localhost:3000/api/readyz") { |req| req.options.timeout = 2 }
      body = JSON.parse(response.body) rescue {}
      body["status"] || "unknown"
    rescue StandardError
      "unknown"
    end
  end
end
