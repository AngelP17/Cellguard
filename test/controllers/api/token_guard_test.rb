require "test_helper"

class Api::TokenGuardTest < ActionDispatch::IntegrationTest
  setup do
    @shard = Shard.find_or_create_by!(name: "test-shard-token-guard")
    @shard.create_error_budget!(
      slo_target: 0.999,
      window_days: 30,
      window_start: Time.current,
      budget_consumed: 0,
      budget_remaining: 1,
      current_burn_rate: 0,
      release_gate_open: true,
      evaluated_at: Time.current
    )
    @original_allow_demo = ENV["ALLOW_DEMO_ENDPOINTS"]
    @original_token = ENV["CELLGUARD_TOKEN"]
  end

  teardown do
    ENV["ALLOW_DEMO_ENDPOINTS"] = @original_allow_demo
    ENV["CELLGUARD_TOKEN"] = @original_token
  end

  test "release gate check is public and does not require token" do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "test-secret-token"

    get "/api/release-gate/check", params: { shard: @shard.name }
    assert_response :success
  end

  test "agent status is public and does not require token" do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "test-secret-token"

    get "/api/agents/status"
    assert_response :success
  end

  test "release gate override requires a valid token when not in demo mode" do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "test-secret-token"

    post "/api/release-gate/override",
      params: { shard: @shard.name, actor: "test", justification: "Test" },
      as: :json
    assert_response :unauthorized

    post "/api/release-gate/override",
      params: { shard: @shard.name, actor: "test", justification: "Test" },
      headers: { "X-CELLGUARD-TOKEN" => "wrong-token" },
      as: :json
    assert_response :unauthorized

    post "/api/release-gate/override",
      params: { shard: @shard.name, actor: "test", justification: "Test" },
      headers: { "X-CELLGUARD-TOKEN" => "test-secret-token" },
      as: :json
    assert_response :success
  end

  test "agent toggle requires a valid token when not in demo mode" do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "test-secret-token"

    post "/api/agents/budget_guard/toggle", params: { enabled: true }, as: :json
    assert_response :unauthorized

    post "/api/agents/budget_guard/toggle",
      params: { enabled: true },
      headers: { "X-CELLGUARD-TOKEN" => "test-secret-token" },
      as: :json
    assert_response :success
  end

  test "incident acknowledge requires a valid token when not in demo mode" do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "test-secret-token"

    incident = Incident.create!(
      shard: @shard,
      title: "Test incident",
      severity_label: "high",
      status: "active"
    )

    post "/api/incidents/#{incident.id}/acknowledge", params: { actor: "test" }, as: :json
    assert_response :unauthorized

    post "/api/incidents/#{incident.id}/acknowledge",
      params: { actor: "test" },
      headers: { "X-CELLGUARD-TOKEN" => "test-secret-token" },
      as: :json
    assert_response :success
  end
end
