class DashboardController < ApplicationController
  def index
    @shard = Shard.find_by(name: params[:shard] || "shard-default") || Shard.create!(name: "shard-default")
    @budget = @shard.error_budget || @shard.create_error_budget!(slo_target: 0.999, window_days: 30, window_start: Time.current)

    BudgetEvaluator.new.evaluate!(shard: @shard) if @budget.evaluated_at.nil? || @budget.evaluated_at < 2.minutes.ago
    @budget.reload

    # Ensure demo data exists so the UI never shows empty states
    DemoDataService.ensure_all!

    # Run agents automatically on dashboard load (if enabled)
    run_autonomous_agents

    @incidents = @shard.incidents.order(created_at: :desc).limit(10).to_a
    @audit_logs = @shard.audit_logs.order(created_at: :desc).limit(10).to_a
    @incident_scope = :shard
    @audit_scope = :shard

    if @incidents.empty?
      @incidents = Incident.recent.limit(10).to_a
      @incident_scope = :global
    end

    if @audit_logs.empty?
      @audit_logs = AuditLog.recent.limit(10).to_a
      @audit_scope = :global
    end

    # Agent system data
    @agent_status = AgentConfig.agents
    @agent_activity = AgentScheduler.recent_activity(limit: 10)
    snapshot = SreScorecardService.new(shard: @shard).snapshot
    @sre_scorecards = snapshot[:scorecards]
    @chaos_insight = snapshot[:chaos_insight]

    # Dependency health for degraded state banner
    @dependency_health = check_dependency_health

    # === xyOps Operations Fabric (evidence FROM DB models, not static) ===
    begin
      Xyops::Simulator.seed_workflows! if defined?(Xyops::Simulator)
      @xyops_connection = XyopsConnection.primary
      @xyops_workflows = XyopsWorkflow.active.recent.limit(6).to_a
      @xyops_alerts = XyopsAlert.active.recent.limit(5).to_a
      @xyops_recent_runs = XyopsWorkflowRun.recent.limit(5).to_a
      @xyops_latest_snapshot = XyopsSnapshot.order(captured_at: :desc).first
      @xyops_linked_incidents = XyopsJobLink.where.not(incident_id: nil).order(created_at: :desc).limit(3).map(&:incident).uniq
    rescue StandardError => e
      Rails.logger.debug "[dashboard] xyops load skipped: #{e.message}"
      @xyops_connection = XyopsConnection.primary
    end

    # Gate xyops context (DB backed for component)
    @gate_xyops = begin
      run = XyopsWorkflowRun.failed.order(started_at: :desc).first
      al = XyopsAlert.critical.active.order(fired_at: :desc).first
      sn = XyopsSnapshot.order(captured_at: :desc).first
      if run || al || sn
        {
          workflow: run&.workflow_name || run&.workflow&.name,
          failed_job: run&.failed_job_name || run&.context&.dig("job"),
          server_snapshot: run&.server_name || run&.server_id || sn&.server_name,
          alert: al&.title,
          snapshot: sn ? { cpu_percent: (sn.cpu_percent || sn.cpu_pct), memory_percent: (sn.memory_percent || sn.mem_pct), network: (sn.network_summary || "elevated") } : nil
        }.compact
      end
    rescue
      nil
    end
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

  def check_dependency_health
    health = { redis: :unknown, classifier: :unknown, sidekiq: :unknown }
    Rails.cache.fetch("cellguard:dashboard:health", expires_in: 10.seconds) do
      health[:redis] = redis_up? ? :ok : :down
      health[:classifier] = classifier_up? ? :ok : :down
      health[:sidekiq] = sidekiq_up? ? :ok : :down
      health
    end
  end

  def redis_up?
    return false unless defined?(Redis)
    Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"), timeout: 1).ping == "PONG"
  rescue StandardError
    false
  end

  def classifier_up?
    require "net/http"
    require "uri"
    url = URI.parse(ENV.fetch("CLASSIFIER_URL", "http://localhost:8081") + "/healthz")
    Net::HTTP.start(url.host, url.port, open_timeout: 1, read_timeout: 1) { |http| http.get(url.path) }.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end

  def sidekiq_up?
    return true unless defined?(Sidekiq)
    require "sidekiq/api"
    Sidekiq::ProcessSet.new.size.positive?
  rescue StandardError
    false
  end
end
