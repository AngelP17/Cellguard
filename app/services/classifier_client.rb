# frozen_string_literal: true

require "json"
require "net/http"

class ClassifierClient
  def self.circuit_breaker
    @circuit_breaker ||= CircuitBreaker.new(
      name: "classifier",
      failure_threshold: 5,
      reset_timeout: 30,
      exceptions: [StandardError]
    )
  end

  def initialize(base_url:)
    @base_url = base_url
  end

  def classify!(payload)
    MetricsRegistry.time(:classifier_request_ms) do
      self.class.circuit_breaker.call do
        return classify_stub(payload) if ENV["CLASSIFIER_STUB"] == "true"
        classify_remote(payload)
      end
    end
  rescue CircuitBreaker::CircuitOpenError => e
    MetricsRegistry.increment(:classifier_circuit_open)
    Rails.logger.warn({ event: "classifier_circuit_open", circuit: e.circuit_name }.to_json) if defined?(Rails)
    raise
  end

  private

  def classify_remote(payload)
    uri = URI.join(@base_url, "/classify")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["X-Request-Id"] = RequestIdMiddleware.current.to_s if RequestIdMiddleware.current
    req.body = JSON.dump(payload)
    req.read_timeout = 5
    req.open_timeout = 2

    res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    raise "classifier_error status=#{res.code}" unless res.is_a?(Net::HTTPSuccess)

    MetricsRegistry.increment(:classifier_requests_total, tags: { status: "ok" })
    JSON.parse(res.body)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    MetricsRegistry.increment(:classifier_requests_total, tags: { status: "timeout" })
    raise
  rescue StandardError => e
    MetricsRegistry.increment(:classifier_requests_total, tags: { status: "error" })
    raise
  end

  def classify_stub(payload)
    MetricsRegistry.increment(:classifier_requests_total, tags: { status: "stub" })
    error_rate = payload["error_rate"].to_f
    p95 = payload["p95_latency_ms"].to_i
    is_violation = (error_rate >= 0.12) || (p95 >= 800)

    {
      "is_violation" => is_violation,
      "action" => is_violation ? "alert" : "noop",
      "reason" => is_violation ? "burning_error_budget" : "healthy"
    }
  end
end
