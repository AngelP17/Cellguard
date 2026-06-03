# frozen_string_literal: true

class BudgetEvaluator
  def evaluate!(shard:)
    budget = shard.error_budget || shard.create_error_budget!(
      slo_target: 0.999,
      window_days: 30,
      window_start: Time.current,
      budget_consumed: 0,
      budget_remaining: 1,
      current_burn_rate: 0,
      release_gate_open: true
    )

    window_end = Time.current
    window_start = [budget.window_start || budget.window_days.days.ago, budget.window_days.days.ago].max

    scope = shard.job_stats.where("period_end >= ? AND period_start <= ?", window_start, window_end)

    total = scope.sum(:job_count)
    errors = scope.sum(:error_count)

    # === xyOps execution fabric awareness (P1/P2) ===
    # Recent failed xyops workflow runs + critical alerts on this shard count as operational signals
    # that accelerate budget burn. This is how CellGuard "governs" the fabric.
    # Hardened: recent successful remediation runs "forgive" recent failures for the demo loop.
    xyops_penalty = 0.0
    recent_failed_runs = 0
    begin
      Xyops::Simulator.seed_workflows! if defined?(Xyops::Simulator)
      recent_runs = XyopsWorkflowRun.failed.where("started_at >= ?", 30.minutes.ago)
      recent_failed_runs = recent_runs.count

      recent_remed_success = XyopsWorkflowRun.where(status: "succeeded")
                                             .where("started_at >= ?", 10.minutes.ago)
                                             .where("context->>'remediation_for' IS NOT NULL OR context->>'remediation' IS NOT NULL").exists?

      if recent_failed_runs > 0 && !recent_remed_success
        # Each critical xyops failure adds a meaningful penalty (demo tuned to reliably cross 1.0 burn)
        xyops_penalty = [0.18 * recent_failed_runs, 0.55].min
      end
      # Also pull any active critical alerts from the fabric (forgiven if remediation just succeeded)
      crit_alerts = XyopsAlert.critical.active.where("fired_at >= ?", 20.minutes.ago).count
      xyops_penalty += 0.12 if crit_alerts > 0 && !recent_remed_success
    rescue StandardError
      # Simulator not present or tables missing in some envs — fail closed (no penalty)
      xyops_penalty = 0.0
    end


    if total.zero? && xyops_penalty.zero?
      budget.update!(
        budget_consumed: 0,
        budget_remaining: 1,
        current_burn_rate: 0,
        release_gate_open: true,
        violation_started_at: nil,
        evaluated_at: Time.current
      )
      return budget
    end

    # Compute base from job_stats safely. If no job_stats (total==0) but we have xyops signals,
    # base_consumed=0 and we still apply the penalty below (this is the case that was producing NaN).
    base_consumed = 0.0
    if total > 0
      actual_error_rate = errors.to_f / total.to_f
      allowed_error_rate = 1.0 - budget.slo_target.to_f

      base_consumed = if allowed_error_rate <= 0
        0.0
      else
        (actual_error_rate / allowed_error_rate)
      end
    end

    base_consumed = 0.0 if base_consumed.to_f.nan? || base_consumed.to_f.infinite?

    # Apply xyops operational penalty (makes gate lock faster when fabric is hurting)
    consumed = base_consumed + (xyops_penalty || 0.0)
    consumed = [consumed, 1.0].min

    # Guard NaN/inf from edge cases in seeded or weird data (demo safety)
    # Do this immediately after any division or addition that could produce NaN.
    consumed = 0.0 if consumed.to_f.nan? || consumed.to_f.infinite?

    remaining = [1.0 - consumed, 0.0].max

    hours_elapsed = [(window_end - window_start) / 1.hour, 1.0].max
    hours_total = budget.window_days * 24.0
    burn_rate = if hours_total > 0 && hours_elapsed > 0
      consumed / (hours_elapsed / hours_total)
    else
      0.0
    end

    burn_rate = 0.0 if burn_rate.to_f.nan? || burn_rate.to_f.infinite?

    gate_open = remaining > 0.0



    was_open = budget.release_gate_open
    budget.update!(
      budget_consumed: consumed.round(8),
      budget_remaining: remaining.round(8),
      current_burn_rate: burn_rate.round(4),
      release_gate_open: gate_open,
      violation_started_at: gate_open ? nil : (budget.violation_started_at || Time.current),
      evaluated_at: Time.current
    )

    # On transition to locked, capture rich xyops evidence snapshot + create linked incident
    if !gate_open && was_open
      begin
        Xyops::Simulator.seed_workflows!
        snap = Xyops::Simulator.capture_snapshot(server_id: "print-worker-02", context: { reason: "gate_lock", burn_rate: burn_rate.round(2) })

        ingestor = Xyops::EventIngestor.new
        inc = ingestor.ingest_degradation!(shard_name: shard.name)

        # Link the snapshot and any recent failed run directly to the budget record for audit credibility
        failed_run = XyopsWorkflowRun.failed.order(started_at: :desc).first
        if failed_run
          XyopsJobLink.create!(
            error_budget: budget,
            xyops_workflow_run_id: failed_run.id,
            role: "evidence",
            details: { gate_locked_at: Time.current.iso8601, burn_rate: burn_rate.round(4) }
          )
        end
        if snap[:id]
          XyopsJobLink.create!(
            error_budget: budget,
            xyops_snapshot_id: snap[:id],
            role: "evidence",
            details: { captured_on_lock: true }
          )
        end

        # Also ensure the incident knows about the gate decision
        inc&.update!(context: (inc.context || {}).merge("gate_locked" => true, "burn_rate" => burn_rate.round(4)))
      rescue StandardError => e
        Rails.logger.warn("[BudgetEvaluator] xyops evidence capture on lock failed: #{e.message}")
      end
    end

    budget
  end
end
