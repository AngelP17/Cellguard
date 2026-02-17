# frozen_string_literal: true

module Agents
  # ChaosOrchestratorAgent intelligently schedules and executes chaos engineering drills.
  # It considers:
  # - Current system health (budget remaining)
  # - Time since last drill
  # - Business hours (safety)
  # - Recent incident history
  #
  # This agent brings scientific rigor to chaos engineering by ensuring
  # experiments are safe, scheduled, and meaningful.
  class ChaosOrchestratorAgent < BaseAgent
    class << self
      def description
        "Intelligently schedules chaos engineering drills"
      end

      # Schedule a drill for a specific time
      def schedule_drill(shard, scheduled_at: nil)
        scheduled_at ||= 1.hour.from_now
        
        # In production, this would queue to Sidekiq/Redis
        # For now, we log the intent
        Rails.logger.info "[ChaosOrchestrator] Drill scheduled for #{shard.name} at #{scheduled_at}"
        
        # Create audit trail
        AuditLog.create!(
          shard: shard,
          actor: "ChaosOrchestratorAgent",
          action: "drill_scheduled",
          justification: "Scheduled chaos engineering drill",
          metadata: { scheduled_at: scheduled_at }
        )
        
        { scheduled: true, for: scheduled_at }
      end
    end

    def execute
      results = {
        decision: :noop,
        reason: nil,
        reasons: [],
        drill: nil,
        guardrails: {}
      }

      guardrails = guardrail_assessment
      results[:guardrails] = guardrails.except(:allowed, :reasons)

      unless guardrails[:allowed]
        results[:decision] = :skipped
        results[:reason] = guardrails[:reasons].first
        results[:reasons] = guardrails[:reasons]

        record_action!(:drill_skipped, {
          reasons: guardrails[:reasons],
          guardrails: results[:guardrails]
        })

        return results
      end

      # Determine drill type based on system state
      drill = select_drill_type
      
      if drill.nil?
        results[:decision] = :skip
        results[:reason] = "No suitable drill type for current state"
        results[:reasons] = [results[:reason]]

        record_action!(:drill_skipped, {
          reasons: results[:reasons],
          guardrails: results[:guardrails]
        })

        return results
      end

      record_action!(:drill_selected, {
        drill_type: drill[:type],
        params: drill[:params],
        rationale: drill[:rationale]
      })

      # Execute or recommend based on auto-chaos setting
      if auto_chaos_enabled?
        execution_result = execute_drill(drill)
        results[:decision] = :executed
        results[:drill] = execution_result
        
        record_action!(:drill_executed, {
          drill: drill,
          result: execution_result,
          auditable: true,
          justification: "Autonomous chaos drill: #{drill[:rationale]}"
        })
      else
        results[:decision] = :recommended
        results[:drill] = drill
        
        record_action!(:drill_recommended, {
          drill: drill,
          auditable: true,
          justification: "Recommend chaos drill: #{drill[:rationale]}"
        })
      end

      results
    end

    private

    def guardrail_assessment
      checks = {
        enabled: self.class.enabled?,
        gate_open: budget&.release_gate_open?,
        budget_safe: budget&.budget_remaining.to_f >= 0.2,
        business_hours: business_hours?,
        interval_ok: !recent_drill_exists?,
        incident_window_clear: !recent_incident_exists?
      }

      reasons = []
      reasons << "Agent is disabled." unless checks[:enabled]
      reasons << "Release gate is locked; skipping chaos drill." unless checks[:gate_open]
      reasons << "Budget remaining below 20%; drill suppressed for safety." unless checks[:budget_safe]
      reasons << "Outside business hours (09:00-18:00); drill deferred." unless checks[:business_hours]
      reasons << "Minimum chaos interval has not elapsed yet." unless checks[:interval_ok]
      reasons << "Recent active incident detected; drill paused." unless checks[:incident_window_clear]

      checks.merge(allowed: reasons.empty?, reasons: reasons)
    end

    def recent_drill_exists?
      min_interval = AgentConfig.get_int("chaos_min_interval_hours")
      
      AgentExecution
        .for_agent("chaos_orchestrator")
        .where(shard: shard)
        .where("created_at > ?", min_interval.hours.ago)
        .exists?
    end

    def recent_incident_exists?
      shard.incidents
        .where("created_at > ?", 4.hours.ago)
        .where(status: ["active", "investigating"])
        .exists?
    end

    def auto_chaos_enabled?
      AgentConfig.get_bool("chaos_orchestrator_enabled") && 
        demo_or_safe_environment?
    end

    def demo_or_safe_environment?
      Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"
    end

    # Select the most appropriate drill type based on system state
    def select_drill_type
      burn_rate = budget.current_burn_rate.to_f
      remaining = budget.budget_remaining.to_f

      # High burn rate = test resilience with network partition
      if burn_rate > 1.5
        return {
          type: :partition,
          params: { mode: "docker", duration_seconds: 15 },
          rationale: "High burn rate detected - testing partition resilience",
          safety_score: 0.8
        }
      end

      # Medium burn rate = add latency to test degradation handling
      if burn_rate > 1.0
        return {
          type: :degrade,
          params: { mode: "tc", duration_seconds: 20, delay_ms: 100, loss_percent: 2 },
          rationale: "Elevated burn rate - testing graceful degradation",
          safety_score: 0.9
        }
      end

      # Low burn rate = short connectivity test
      if remaining > 0.5
        return {
          type: :partition,
          params: { mode: "docker", duration_seconds: 10 },
          rationale: "Routine resilience validation",
          safety_score: 0.95
        }
      end

      nil
    end

    def execute_drill(drill)
      case drill[:type]
      when :partition
        trigger_chaos!(:partition, drill[:params])
      when :degrade
        trigger_chaos!(:partition, drill[:params]) # Uses same endpoint with tc mode
      else
        { error: "Unknown drill type" }
      end
    end
  end
end
