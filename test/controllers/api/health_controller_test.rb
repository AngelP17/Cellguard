require "test_helper"

class Api::HealthControllerTest < ActionDispatch::IntegrationTest
  test "healthz returns ok" do
    get "/api/healthz"
    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal "ok", body["status"]
  end

  test "readyz returns readiness state" do
    get "/api/readyz"
    assert_includes [200, 503], @response.status
    body = JSON.parse(@response.body)
    assert_includes %w[ready degraded], body["status"]
    assert body["checks"].key?("database")
    assert body["checks"].key?("redis")
    assert body["checks"].key?("sidekiq")
    assert body["checks"].key?("classifier")
  end

  test "status returns version and component state" do
    get "/api/status"
    assert_response :success
    body = JSON.parse(@response.body)
    assert_equal CellGuardVersion.label, body["version"]
    assert body["components"].key?("database")
  end
end
