require "test_helper"
require "securerandom"

class AgentReliabilityFlowTest < ActionDispatch::IntegrationTest
  setup do
    @prev_allow_demo = ENV["ALLOW_DEMO_ENDPOINTS"]
    @prev_classifier_stub = ENV["CLASSIFIER_STUB"]

    ENV["ALLOW_DEMO_ENDPOINTS"] = "true"
    ENV["CLASSIFIER_STUB"] = "true"
  end

  teardown do
    ENV["ALLOW_DEMO_ENDPOINTS"] = @prev_allow_demo
    ENV["CLASSIFIER_STUB"] = @prev_classifier_stub
    AgentConfig.toggle!("chaos_orchestrator", false)
  end

  test "toggle chaos, run agent, observe activity, and resolve incident runbook link" do
    shard_name = "flow-shard-#{SecureRandom.hex(4)}"
    shard = Shard.create!(name: shard_name)
    shard.create_error_budget!(
      slo_target: 0.999,
      window_days: 30,
      window_start: Time.current - 1.hour,
      budget_consumed: 0.01,
      budget_remaining: 0.99,
      current_burn_rate: 0.4,
      release_gate_open: true,
      evaluated_at: Time.current
    )

    shard.job_stats.create!(
      queue_namespace: "default",
      period_start: 10.minutes.ago,
      period_end: Time.current,
      job_count: 1200,
      error_count: 10,
      latency_p95_ms: 220,
      meta: {}
    )

    shard.incidents.create!(
      title: "Pre-existing active incident",
      severity_label: "severity::2",
      team_label: "team::Production Engineering::Scalability",
      service_label: "Service::Sidekiq",
      status: "active",
      context: { classifier: { reason: "preexisting_incident" } }
    )

    post "/api/agents/chaos_orchestrator/toggle", params: { enabled: true }, as: :json
    assert_response :success
    assert_equal true, parsed_json.fetch("enabled")

    post "/api/agents/chaos_orchestrator/run", params: { shard: shard_name }, as: :json
    assert_response :success
    run_payload = parsed_json
    assert_equal true, run_payload.fetch("executed")
    assert_equal "skipped", run_payload.dig("result", "decision")
    assert_includes Array(run_payload.dig("result", "reasons")).join(" "), "incident"

    get "/api/agents/activity", params: { limit: 50 }
    assert_response :success

    activity = parsed_json.find do |entry|
      entry["agent"] == "chaos_orchestrator" && entry["shard"] == shard_name
    end
    assert activity.present?, "expected chaos_orchestrator activity for #{shard_name}"

    post "/api/inject-failures",
      params: { shard: shard_name, error_rate: 0.25, p95_latency_ms: 900, total: 1_000 },
      as: :json
    assert_response :success

    post "/api/evaluate", params: { shard: shard_name }, as: :json
    assert_response :success
    assert_equal false, parsed_json.dig("budget", "gate_open")

    incident = shard.incidents.order(created_at: :desc).first
    assert incident.present?, "expected incident to be created"
    assert incident.context["agent_analysis"].present?, "expected agent analysis in incident context"

    suggested_runbooks = Array(incident.context["suggested_runbooks"])
    assert suggested_runbooks.any?, "expected suggested runbooks"

    first_slug = suggested_runbooks.first["slug"]
    assert first_slug.present?, "expected runbook slug"

    get "/runbooks/#{first_slug}"
    assert_response :success
  end

  private

  def parsed_json
    JSON.parse(response.body)
  end
end
