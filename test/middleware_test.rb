require "test_helper"

class RequestIdMiddlewareTest < ActionDispatch::IntegrationTest
  test "response carries an X-Request-Id even when client does not send one" do
    get "/api/healthz"
    assert_response :success
    rid = @response.headers["X-Request-Id"]
    assert rid.present?
    assert_match(/\A[A-Za-z0-9_\-]{1,128}\z/, rid)
  end

  test "response echoes a well-formed client X-Request-Id" do
    client_id = "abc-123-test"
    get "/api/healthz", headers: { "X-Request-Id" => client_id }
    assert_equal client_id, @response.headers["X-Request-Id"]
  end

  test "malformed client X-Request-Id is replaced with a generated one" do
    get "/api/healthz", headers: { "X-Request-Id" => "bad id with spaces" }
    rid = @response.headers["X-Request-Id"]
    assert_not_equal "bad id with spaces", rid
    assert_match(/\A[A-Za-z0-9_\-]{1,128}\z/, rid)
  end
end

class RateLimitMiddlewareTest < ActionDispatch::IntegrationTest
  setup do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "test-token-rl"
  end

  teardown do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
  end

  test "unauthenticated audit-logs requests are rate limited" do
    paths = 70.times.map { "/api/audit-logs?shard=shard-default&_n=#{rand(1_000_000)}" }
    last_status = nil
    paths.each do |path|
      get path
      last_status = @response.status
      break if last_status == 429
    end
    assert_equal 429, last_status
    assert_equal "application/json", @response.media_type
  end
end

class MetricsEndpointTest < ActionDispatch::IntegrationTest
  test "metrics endpoint returns counters, gauges, and timings" do
    MetricsRegistry.increment(:test_counter, by: 3)
    MetricsRegistry.gauge(:test_gauge, 42)
    get "/api/metrics"
    assert_response :success
    body = JSON.parse(@response.body)
    assert body["counters"].present?
    assert body["gauges"].present?
    assert body["timings"].is_a?(Hash)
    assert body["process"]["pid"] == Process.pid
  end
end

class CircuitBreakerTest < ActiveSupport::TestCase
  test "opens after threshold failures and short-circuits subsequent calls" do
    breaker = CircuitBreaker.new(name: "test", failure_threshold: 2, reset_timeout: 60)

    assert_equal :closed, breaker.state
    assert_raises(StandardError) { breaker.call { raise "boom" } }
    assert_raises(StandardError) { breaker.call { raise "boom" } }
    assert_equal :open, breaker.state

    assert_raises(CircuitBreaker::CircuitOpenError) { breaker.call { "should not run" } }
  end

  test "transitions to half-open after reset timeout and closes on success" do
    breaker = CircuitBreaker.new(name: "test", failure_threshold: 1, reset_timeout: 0)
    assert_raises(StandardError) { breaker.call { raise "boom" } }

    sleep 0.05
    result = breaker.call { "ok" }
    assert_equal "ok", result
    assert_equal :closed, breaker.state
  end
end
