require "test_helper"

class BudgetEvaluatorTest < ActiveSupport::TestCase
  test "returns full budget when no stats exist" do
    shard = Shard.create!(name: "test-shard")

    budget = BudgetEvaluator.new.evaluate!(shard: shard)

    assert_equal 1.0, budget.budget_remaining.to_f
    assert budget.release_gate_open
  end

  test "locks gate when consumed budget exceeds 1.0" do
    shard = Shard.create!(name: "burning-shard")
    shard.create_error_budget!(
      slo_target: 0.999,
      window_days: 30,
      window_start: 1.day.ago,
      budget_consumed: 0,
      budget_remaining: 1,
      current_burn_rate: 0,
      release_gate_open: true
    )

    shard.job_stats.create!(
      queue_namespace: "default",
      period_start: 30.minutes.ago,
      period_end: Time.current,
      job_count: 1000,
      error_count: 200,
      latency_p95_ms: 500,
      meta: {}
    )

    budget = BudgetEvaluator.new.evaluate!(shard: shard)

    assert_equal false, budget.release_gate_open
    assert_operator budget.budget_remaining.to_f, :<=, 0.0
  end
end
