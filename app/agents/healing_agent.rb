# frozen_string_literal: true

module Agents
  # HealingAgent attempts automatic recovery from detected faults.
  # It operates with a "do no harm" philosophy:
  # - Only heals in safe conditions
  # - Requires approval for high-impact actions
  # - Has maximum retry limits
  # - Full audit trail of all healing attempts
  class HealingAgent < BaseAgent
    class << self
      def description
        "Attempts automatic recovery from detected faults"
      end

      # Check if healing is needed and safe
      def should_heal?(shard)
        return false unless enabled?

        # Check for stuck chaos (partition not healed)
        recent_chaos = AgentExecution
          .for_agent("chaos_orchestrator")
          .where(shard: shard)
          .where("created_at > ?", 5.minutes.ago)
          .where("action_taken LIKE ?", "%chaos_triggered%")
          .exists?

        # Check for gate locked but recoverable
        budget = shard.error_budget
        gate_locked = budget && !budget.release_gate_open?

        recent_chaos || gate_locked
      end
    end

    def execute
      results = {
        assessments: [],
        healing_attempts: [],
        recommendations: []
      }

      # Assess current system state
      assessment = assess_system_health
      results[:assessments] << assessment

      record_action!(:health_assessment, assessment)

      # Determine healing strategy
      strategy = determine_healing_strategy(assessment)

      if strategy.nil?
        results[:recommendations] << { type: :monitor, reason: "No healing needed" }
        return results
      end

      record_action!(:healing_strategy_selected, {
        strategy: strategy,
        auto_approve: auto_recover_enabled? && strategy[:safety_score] > 0.8
      })

      # Execute or recommend
      if auto_recover_enabled? && strategy[:safety_score] > 0.8
        attempt = execute_healing(strategy)
        results[:healing_attempts] << attempt

        record_action!(:healing_executed, {
          strategy: strategy,
          result: attempt,
          auditable: true,
          justification: "Auto-healing executed with safety score #{strategy[:safety_score]}"
        })
      else
        results[:recommendations] << {
          type: :approval_required,
          strategy: strategy,
          reason: "Manual approval required for healing action"
        }

        record_action!(:healing_recommended, {
          strategy: strategy,
          auditable: true,
          justification: "Healing recommended but requires manual approval"
        })
      end

      results
    end

    private

    def assess_system_health
      assessment = {
        timestamp: Time.current,
        gate_status: budget&.release_gate_open? ? :open : :locked,
        budget_remaining: budget&.budget_remaining&.to_f,
        burn_rate: budget&.current_burn_rate&.to_f,
        recent_chaos: recent_chaos_active?,
        recent_incidents: recent_active_incidents.count,
        heal_safe: false
      }

      # Determine if healing is safe
      assessment[:heal_safe] = healing_safe?(assessment)
      assessment
    end

    def healing_safe?(assessment)
      # Don't heal if already attempting
      return false if healing_in_progress?

      # Don't heal if too many recent healing attempts
      return false if recent_healing_attempts >= max_retry_attempts

      # Don't heal outside safe environments without explicit enable
      return false unless safe_environment?

      # Don't heal during active incidents (unless chaos-related)
      return false if assessment[:recent_incidents] > 0 && !assessment[:recent_chaos]

      true
    end

    def determine_healing_strategy(assessment)
      return nil unless assessment[:heal_safe]

      # Strategy 1: Heal chaos if active
      if assessment[:recent_chaos]
        return {
          type: :chaos_heal,
          description: "Restore network connectivity after chaos drill",
          safety_score: 0.95,
          max_duration: 30
        }
      end

      # Strategy 2: Re-evaluate budget if locked
      if assessment[:gate_status] == :locked && assessment[:budget_remaining].to_f > 0
        return {
          type: :budget_revaluation,
          description: "Re-evaluate error budget with fresh data",
          safety_score: 0.9,
          max_duration: 60
        }
      end

      # Strategy 3: Suggest manual review
      if assessment[:burn_rate].to_f > 2.0
        return {
          type: :escalation,
          description: "Escalate to on-call for manual intervention",
          safety_score: 0.3, # Low safety score = requires approval
          max_duration: 0
        }
      end

      nil
    end

    def execute_healing(strategy)
      case strategy[:type]
      when :chaos_heal
        execute_chaos_heal
      when :budget_revaluation
        execute_budget_revaluation
      when :escalation
        execute_escalation
      else
        { success: false, error: "Unknown strategy type" }
      end
    end

    def execute_chaos_heal
      result = trigger_heal!
      
      # Re-evaluate after healing
      sleep 2 # Brief wait for network to restore
      BudgetEvaluator.new.evaluate!(shard: shard)

      {
        type: :chaos_heal,
        success: result.present?,
        follow_up: :reevaluated
      }
    end

    def execute_budget_revaluation
      # Force a fresh budget evaluation
      old_budget = budget&.budget_remaining.to_f
      
      BudgetEvaluator.new.evaluate!(shard: shard)
      budget.reload
      
      new_budget = budget.budget_remaining.to_f

      {
        type: :budget_revaluation,
        success: true,
        budget_before: old_budget,
        budget_after: new_budget,
        gate_open: budget.release_gate_open?
      }
    end

    def execute_escalation
      # Create audit log for escalation
      AuditLog.create!(
        shard: shard,
        actor: "HealingAgent",
        action: "escalation_recommended",
        justification: "High burn rate detected - manual intervention required",
        metadata: {
          burn_rate: budget&.current_burn_rate,
          budget_remaining: budget&.budget_remaining
        }
      )

      {
        type: :escalation,
        success: true,
        message: "Escalation recorded in audit log"
      }
    end

    def recent_chaos_active?
      AgentExecution
        .for_agent("chaos_orchestrator")
        .where(shard: shard)
        .where("created_at > ?", 10.minutes.ago)
        .where("action_taken LIKE ?", "%chaos_triggered%")
        .exists?
    end

    def recent_active_incidents
      shard.incidents.where(status: ["active", "investigating"])
    end

    def healing_in_progress?
      AgentExecution
        .for_agent("healing")
        .where(shard: shard)
        .where(status: :running)
        .exists?
    end

    def recent_healing_attempts
      AgentExecution
        .for_agent("healing")
        .where(shard: shard)
        .where("created_at > ?", 1.hour.ago)
        .count
    end

    def max_retry_attempts
      AgentConfig.get_int("healing_max_retry_attempts")
    end

    def auto_recover_enabled?
      AgentConfig.get_bool("healing_auto_recover")
    end

    def safe_environment?
      Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"
    end
  end
end
