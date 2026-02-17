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

    if total.zero?
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

    actual_error_rate = errors.to_f / total
    allowed_error_rate = 1.0 - budget.slo_target.to_f

    consumed = if allowed_error_rate <= 0
      0.0
    else
      (actual_error_rate / allowed_error_rate)
    end

    remaining = [1.0 - consumed, 0.0].max

    hours_elapsed = [(window_end - window_start) / 1.hour, 1.0].max
    hours_total = budget.window_days * 24.0
    burn_rate = consumed / (hours_elapsed / hours_total)

    gate_open = remaining > 0.0

    budget.update!(
      budget_consumed: consumed.round(8),
      budget_remaining: remaining.round(8),
      current_burn_rate: burn_rate.round(4),
      release_gate_open: gate_open,
      violation_started_at: gate_open ? nil : (budget.violation_started_at || Time.current),
      evaluated_at: Time.current
    )

    budget
  end
end
