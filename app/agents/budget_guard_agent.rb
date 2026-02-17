# frozen_string_literal: true

module Agents
  # BudgetGuardAgent monitors error budget burn rate and predicts exhaustion.
  # It can trigger alerts, recommend escalations, and even initiate chaos drills
  # to validate system resilience before budget is exhausted.
  class BudgetGuardAgent < BaseAgent
    class << self
      def description
        "Monitors error budget burn rate and predicts exhaustion"
      end
    end

    def execute
      results = {
        predictions: [],
        alerts: [],
        actions: []
      }

      return results if budget.nil?

      # Evaluate current budget state
      BudgetEvaluator.new.evaluate!(shard: shard)
      budget.reload

      # Prediction: Time to exhaustion
      hours_to_exhaustion = predict_exhaustion_hours
      if hours_to_exhaustion && hours_to_exhaustion < exhaustion_threshold_hours
        results[:predictions] << {
          type: :budget_exhaustion,
          hours_remaining: hours_to_exhaustion,
          severity: hours_to_exhaustion < 4 ? :critical : :warning
        }

        record_action!(:predicted_exhaustion, {
          hours_remaining: hours_to_exhaustion,
          budget_remaining: budget.budget_remaining.to_f,
          burn_rate: budget.current_burn_rate.to_f,
          auditable: true,
          justification: "Budget will exhaust in #{hours_to_exhaustion.round(1)} hours at current burn rate"
        })

        # Recommend escalation if critical
        if hours_to_exhaustion < 4
          record_action!(:escalation_recommended, {
            reason: "Budget exhaustion imminent",
            auditable: true,
            justification: "Critical: Less than 4 hours until budget exhaustion"
          })
          results[:alerts] << { type: :escalation, reason: "Budget exhaustion in #{hours_to_exhaustion.round(1)}h" }
        end
      end

      # Alert: Critical burn rate
      if budget.current_burn_rate.to_f > critical_burn_rate
        results[:alerts] << {
          type: :high_burn_rate,
          burn_rate: budget.current_burn_rate.to_f,
          threshold: critical_burn_rate
        }

        record_action!(:high_burn_rate_detected, {
          burn_rate: budget.current_burn_rate.to_f,
          threshold: critical_burn_rate
        })

        # Trigger defensive chaos drill if enabled
        if auto_chaos_enabled? && safe_to_run_chaos?
          chaos_result = trigger_defensive_chaos
          results[:actions] << chaos_result if chaos_result
        end
      end

      # Alert: Gate already locked
      if !budget.release_gate_open?
        results[:alerts] << { type: :gate_locked, since: budget.violation_started_at }
        
        record_action!(:gate_locked_detected, {
          locked_since: budget.violation_started_at,
          budget_remaining: budget.budget_remaining.to_f
        })
      end

      results
    end

    private

    def exhaustion_threshold_hours
      AgentConfig.get_float("budget_guard_exhaustion_threshold_hours")
    end

    def critical_burn_rate
      AgentConfig.get_float("budget_guard_critical_burn_rate")
    end

    def critical_remaining
      AgentConfig.get_float("budget_guard_critical_remaining")
    end

    def auto_chaos_enabled?
      AgentConfig.get_bool("budget_guard_auto_chaos")
    end

    def safe_to_run_chaos?
      # Don't run chaos if budget is already exhausted
      return false unless budget.release_gate_open?
      
      # Don't run chaos outside business hours (safety)
      return false unless business_hours?
      
      # Check if we've run chaos recently on this shard
      recent_chaos = AgentExecution
        .for_agent("chaos_orchestrator")
        .where(shard: shard)
        .where("created_at > ?", 2.hours.ago)
        .exists?
      
      !recent_chaos
    end

    def trigger_defensive_chaos
      # Run a short, safe chaos drill to validate resilience
      # This is "defensive" - we're testing before things break
      
      record_action!(:defensive_chaos_initiated, {
        reason: "High burn rate detected - validating resilience",
        auditable: true,
        justification: "Proactive chaos drill triggered by BudgetGuard due to elevated burn rate"
      })

      # Short 10-second partition to validate without major impact
      trigger_chaos!(:partition, {
        mode: "docker",
        duration_seconds: 10
      })

      { type: :defensive_chaos, duration: 10 }
    end
  end
end
