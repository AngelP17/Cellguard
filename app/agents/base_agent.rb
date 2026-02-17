# frozen_string_literal: true

module Agents
  # Base class for all autonomous agents in CellGuard
  # Agents are autonomous workers that make decisions and take actions
  # based on system state. All actions are auditable.
  class BaseAgent
    class << self
      def agent_name
        name.demodulize.underscore.sub(/_agent\z/, "")
      end

      def description
        "No description provided"
      end

      def enabled?
        AgentConfig.enabled?(agent_name)
      end

      # Run the agent with full audit trail
      def run(shard: nil)
        return nil unless enabled?

        execution = AgentExecution.start!(agent_name, shard)
        
        begin
          Rails.logger.info "[Agent:#{agent_name}] Starting execution##{execution.id}"
          
          result = new(shard: shard, execution: execution).execute
          
          execution.complete!(result)
          broadcast_activity(execution)
          
          Rails.logger.info "[Agent:#{agent_name}] Execution##{execution.id} completed"
          result
        rescue StandardError => e
          execution.fail!(e.message)
          broadcast_activity(execution)
          Rails.logger.error "[Agent:#{agent_name}] Execution##{execution.id} failed: #{e.message}"
          raise e
        end
      end

      # Run agent on all shards
      def run_all
        return [] unless enabled?

        Shard.find_each.map do |shard|
          run(shard: shard)
        end.compact
      end

      private

      def broadcast_activity(execution)
        # Broadcast to any connected dashboard clients
        ActionCable.server.broadcast(
          "agent_activity",
          {
            agent: execution.agent_name,
            action: execution.action_taken,
            shard: execution.shard&.name,
            status: execution.status,
            created_at: execution.created_at
          }
        )
      rescue StandardError
        # Don't fail execution if broadcast fails
      end
    end

    attr_reader :shard, :execution

    def initialize(shard:, execution:)
      @shard = shard
      @execution = execution
      @actions_taken = []
    end

    # Override in subclasses
    def execute
      raise NotImplementedError
    end

    protected

    # Record an action taken by this agent
    def record_action!(action, details = {})
      @actions_taken << {
        action: action,
        details: details,
        timestamp: Time.current
      }

      execution.update!(
        action_taken: action,
        action_details: @actions_taken,
        shard: shard
      )

      # Also create audit log for significant actions
      if details[:auditable]
        AuditLog.create!(
          shard: shard,
          actor: "Agent::#{self.class.agent_name}",
          action: action,
          justification: details[:justification] || "Autonomous agent decision",
          metadata: {
            agent_execution_id: execution.id,
            details: details.except(:auditable, :justification)
          }
        )
      end

      action
    end

    # Get the error budget for current shard
    def budget
      @budget ||= shard.error_budget
    end

    # Predict time to budget exhaustion
    def predict_exhaustion_hours
      return nil if budget.nil? || budget.current_burn_rate <= 0

      remaining_budget = budget.budget_remaining.to_f
      burn_rate = budget.current_burn_rate.to_f

      return nil if burn_rate <= 0

      hours_remaining = remaining_budget / burn_rate
      hours_remaining * budget.window_days * 24
    end

    # Check if we're in business hours (for intelligent alerting)
    def business_hours?
      hour = Time.current.hour
      weekday = Time.current.wday

      hour >= 9 && hour < 18 && weekday >= 1 && weekday <= 5
    end

    # Safely execute chaos operation
    def trigger_chaos!(operation, params = {})
      return false unless demo_or_safe_environment?

      record_action!(:chaos_triggered, {
        operation: operation,
        params: params,
        auditable: true,
        justification: "Autonomous chaos engineering drill"
      })

      # Actually trigger via ChaosController logic
      ChaosService.new(shard).execute(operation, params)
    rescue StandardError => e
      record_action!(:chaos_failed, { error: e.message })
      false
    end

    # Safely heal system
    def trigger_heal!
      record_action!(:heal_triggered, {
        auditable: true,
        justification: "Autonomous healing response"
      })

      ChaosService.new(shard).heal
    rescue StandardError => e
      record_action!(:heal_failed, { error: e.message })
      false
    end

    private

    def demo_or_safe_environment?
      Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"
    end
  end
end
