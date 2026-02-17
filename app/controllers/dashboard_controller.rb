class DashboardController < ApplicationController
  def index
    @shard = Shard.find_by(name: params[:shard] || "shard-default") || Shard.create!(name: "shard-default")
    @budget = @shard.error_budget || @shard.create_error_budget!(slo_target: 0.999, window_days: 30, window_start: Time.current)

    BudgetEvaluator.new.evaluate!(shard: @shard) if @budget.evaluated_at.nil? || @budget.evaluated_at < 2.minutes.ago
    @budget.reload

    @incidents = @shard.incidents.order(created_at: :desc).limit(10)
    @audit_logs = @shard.audit_logs.order(created_at: :desc).limit(10)

    # Agent system data
    @agent_status = AgentConfig.agents
    @agent_activity = AgentScheduler.recent_activity(limit: 10)

    # Run agents automatically on dashboard load (if enabled)
    run_autonomous_agents
  end

  private

  def run_autonomous_agents
    return unless AgentConfig.global_enabled?

    begin
      AgentScheduler.run_agent_on_shard("budget_guard", @shard.name)
      AgentScheduler.run_agent_on_shard("healing", @shard.name)
      AgentScheduler.run_agent_on_shard("incident_response", @shard.name)
      AgentScheduler.run_agent_on_shard("chaos_orchestrator", @shard.name)
    rescue StandardError => e
      Rails.logger.error "[Dashboard] Agent execution failed: #{e.message}"
    end
  end
end
