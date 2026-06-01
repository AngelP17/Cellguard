require "test_helper"

class IdempotencyTest < ActionDispatch::IntegrationTest
  setup do
    @shard = Shard.find_or_create_by!(name: "test-shard-idem")
    @shard.create_error_budget!(
      slo_target: 0.999, window_days: 30, window_start: Time.current,
      budget_consumed: 0, budget_remaining: 1, current_burn_rate: 0,
      release_gate_open: true, evaluated_at: Time.current
    )
    @original_allow = ENV["ALLOW_DEMO_ENDPOINTS"]
    @original_token = ENV["CELLGUARD_TOKEN"]
    IdempotencyStore.reset!
  end

  teardown do
    ENV["ALLOW_DEMO_ENDPOINTS"] = @original_allow
    ENV["CELLGUARD_TOKEN"] = @original_token
  end

  test "replays cached response when same key + same body" do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "idem-token"

    body = { shard: @shard.name, actor: "test", justification: "Test override" }.to_json
    headers = { "X-CELLGUARD-TOKEN" => "idem-token", "X-Idempotency-Key" => "test-key-123", "Content-Type" => "application/json" }

    post "/api/release-gate/override", params: body, headers: headers
    first_status = @response.status
    first_body = @response.body

    post "/api/release-gate/override", params: body, headers: headers
    assert_equal first_status, @response.status
    assert_equal first_body, @response.body
    assert_equal "true", @response.headers["X-Idempotent-Replay"]
  end

  test "rejects same key with different body as conflict" do
    ENV["ALLOW_DEMO_ENDPOINTS"] = nil
    ENV["CELLGUARD_TOKEN"] = "idem-token"

    key = "conflict-key-456"
    body1 = { shard: @shard.name, actor: "test", justification: "First" }.to_json
    body2 = { shard: @shard.name, actor: "test", justification: "Different" }.to_json
    headers = { "X-CELLGUARD-TOKEN" => "idem-token", "X-Idempotency-Key" => key, "Content-Type" => "application/json" }

    post "/api/release-gate/override", params: body1, headers: headers
    assert_response :success

    post "/api/release-gate/override", params: body2, headers: headers
    assert_response :conflict
  end
end

class StateAlertComponentTest < ActiveSupport::TestCase
  test "renders error level with alert role" do
    component = Ui::StateAlertComponent.new(level: :error, title: "Boom", message: "Something broke")
    assert_includes component.classes, "cg-state-alert--error"
  end

  test "defaults to info level" do
    component = Ui::StateAlertComponent.new(title: "Heads up")
    assert_includes component.classes, "cg-state-alert--info"
  end

  test "rejects unknown levels" do
    component = Ui::StateAlertComponent.new(level: :bogus, title: "x")
    assert_includes component.classes, "cg-state-alert--info"
  end
end

class SkeletonComponentTest < ActiveSupport::TestCase
  test "maps known kinds to size classes" do
    assert_equal "h-3 w-full", Ui::SkeletonComponent.new(kind: :text).classes
    assert_equal "h-8 w-20", Ui::SkeletonComponent.new(kind: :metric).classes
  end

  test "falls back to text size for unknown kind" do
    assert_equal "h-3 w-full", Ui::SkeletonComponent.new(kind: :unknown).classes
  end
end
