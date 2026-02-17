require "test_helper"

class Api::ReleaseGatesControllerTest < ActionDispatch::IntegrationTest
  test "check returns 200 for initialized shard" do
    shard = Shard.find_or_create_by!(name: "test-shard-#{Time.now.to_i}")
    shard.create_error_budget!(
      slo_target: 0.999,
      window_days: 30,
      window_start: Time.current,
      budget_consumed: 0,
      budget_remaining: 1,
      current_burn_rate: 0,
      release_gate_open: true,
      evaluated_at: Time.current
    )

    get "/api/release-gate/check", params: { shard: shard.name }

    assert_response :success
  end
end
