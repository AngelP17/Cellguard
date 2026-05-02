class MarketingController < ApplicationController
  def home
    @shard = Shard.find_by(name: "shard-default") || Shard.create!(name: "shard-default")
    @budget = @shard.error_budget || @shard.create_error_budget!(slo_target: 0.999, window_days: 30, window_start: Time.current)
    BudgetEvaluator.new.evaluate!(shard: @shard) if @budget.evaluated_at.nil? || @budget.evaluated_at < 2.minutes.ago
    @budget.reload

    # Ensure demo data exists so the UI never shows empty states
    DemoDataService.ensure_all!

    @incidents = @shard.incidents.order(created_at: :desc).limit(5).to_a
    @incidents = Incident.recent.limit(5).to_a if @incidents.empty?

    @agent_status = AgentConfig.agents
    @recent_activity = AgentScheduler.recent_activity(limit: 5)
  end
end
