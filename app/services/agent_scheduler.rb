# frozen_string_literal: true

# Scheduler service for autonomous agents
# Runs agents at configured intervals
# Can be triggered by:
# - Cron/scheduled job (production)
# - Background job (Sidekiq)
# - Manual invocation (dashboard)
class AgentScheduler
  AGENTS = [
    ::Agents::BudgetGuardAgent,
    ::Agents::ChaosOrchestratorAgent,
    ::Agents::IncidentResponseAgent,
    ::Agents::HealingAgent
  ].freeze

  class << self
    def enqueue!
      AgentSchedulerJob.perform_async
    end

    # Run all enabled agents across all shards
    def run_all
      return [] unless AgentConfig.global_enabled?

      results = []
      
      AGENTS.each do |agent_class|
        next unless agent_class.enabled?
        
        agent_results = agent_class.run_all
        results.concat(agent_results) if agent_results.present?
      rescue StandardError => e
        Rails.logger.error "[AgentScheduler] #{agent_class.agent_name} failed: #{e.message}"
      end

      results
    end

    # Enqueue all enabled agents across all shards for parallel execution
    def run_all_parallel
      return [] unless AgentConfig.global_enabled?

      jobs = []
      enabled_agents = AGENTS.select(&:enabled?)
      return jobs if enabled_agents.empty?

      Shard.find_each do |shard|
        enabled_agents.each do |agent_class|
          jid = AgentRunJob.perform_async(agent_class.agent_name, shard.name)
          jobs << { jid: jid, agent: agent_class.agent_name, shard: shard.name }
        end
      end

      jobs
    end

    # Run a specific agent on all shards
    def run_agent(agent_name)
      agent_class = find_agent_class(agent_name)
      return nil unless agent_class&.enabled?

      agent_class.run_all
    end

    # Run a specific agent on a specific shard
    def run_agent_on_shard(agent_name, shard_name)
      agent_class = find_agent_class(agent_name)
      shard = Shard.find_by(name: shard_name)
      
      return nil unless agent_class&.enabled?
      return nil unless shard

      agent_class.run(shard: shard)
    end

    # Get status of all agents
    def status
      {
        global_enabled: AgentConfig.global_enabled?,
        agents: AGENTS.map do |agent_class|
          {
            name: agent_class.agent_name,
            enabled: agent_class.enabled?,
            description: agent_class.description,
            recent_executions: AgentExecution.for_agent(agent_class.agent_name).today.count
          }
        end,
        last_execution: AgentExecution.recent.first&.created_at
      }
    end

    # Get recent activity across all agents
    def recent_activity(limit: 20)
      AgentExecution.recent.limit(limit).map do |execution|
        {
          id: execution.id,
          agent: execution.agent_name,
          shard: execution.shard&.name,
          status: execution.status,
          action: execution.action_taken,
          description: execution.description,
          created_at: execution.created_at,
          duration_ms: execution.duration_ms
        }
      end
    end

    private

    def find_agent_class(name)
      AGENTS.find { |a| a.agent_name == name }
    end
  end

  # Instance methods for fine-grained control
  attr_reader :shard

  def initialize(shard)
    @shard = shard
  end

  def run_enabled_agents
    return [] unless AgentConfig.global_enabled?

    AGENTS.map do |agent_class|
      next unless agent_class.enabled?
      agent_class.run(shard: shard)
    end.compact
  end
end
