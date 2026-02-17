# frozen_string_literal: true

require "json"
require "net/http"

class ClassifierClient
  def initialize(base_url:)
    @base_url = base_url
  end

  def classify!(payload)
    return classify_stub(payload) if ENV["CLASSIFIER_STUB"] == "true"

    uri = URI.join(@base_url, "/classify")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req.body = JSON.dump(payload)

    res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    raise "classifier_error status=#{res.code} body=#{res.body}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end

  private

  def classify_stub(payload)
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
