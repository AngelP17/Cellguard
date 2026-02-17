# frozen_string_literal: true

class SreScorecardService
  RECENT_WINDOW_DAYS = 30
  GATE_TREND_WINDOW_DAYS = 7
  SPARKLINE_BARS = %w[▁ ▂ ▃ ▄ ▅ ▆ ▇ █].freeze

  def initialize(shard:)
    @shard = shard
  end

  def snapshot
    {
      scorecards: {
        chaos: chaos_scorecard,
        mttr: mttr_scorecard,
        gate_locks: gate_lock_scorecard
      },
      chaos_insight: chaos_insight
    }
  end

  private

  attr_reader :shard

  def chaos_scorecard
    rows = recent_chaos_executions
    total = rows.size
    executed = rows.count { |row| execution_decision(row) == "executed" }
    successful = rows.count { |row| execution_decision(row) == "executed" && drill_successful?(row) }
    skipped = rows.count { |row| %w[skip skipped noop].include?(execution_decision(row)) }
    recommended = rows.count { |row| execution_decision(row) == "recommended" }

    success_rate = if executed.positive?
      ((successful.to_f / executed) * 100.0).round(1)
    end

    {
      success_rate: success_rate,
      success_rate_label: success_rate ? "#{success_rate}%" : "N/A",
      successful: successful,
      executed: executed,
      skipped: skipped,
      recommended: recommended,
      total: total
    }
  end

  def mttr_scorecard
    resolved = shard.incidents
      .where(status: "resolved")
      .where(created_at: RECENT_WINDOW_DAYS.days.ago..)

    durations = resolved.map do |incident|
      next if incident.updated_at.blank? || incident.created_at.blank?

      ((incident.updated_at - incident.created_at) / 60.0).round(1)
    end.compact

    avg = durations.sum / durations.size.to_f if durations.any?

    {
      minutes: avg&.round(1),
      label: avg ? "#{avg.round(1)} min" : "N/A",
      resolved_count: resolved.count
    }
  end

  def gate_lock_scorecard
    today = Time.current.beginning_of_day
    recent_start = today - (GATE_TREND_WINDOW_DAYS - 1).days
    previous_start = recent_start - GATE_TREND_WINDOW_DAYS.days
    previous_end = recent_start - 1.second

    recent_series = gate_lock_series(from: recent_start, to: Time.current)
    previous_total = gate_lock_scope(from: previous_start, to: previous_end).count
    recent_total = recent_series.sum

    trend = if recent_total > previous_total
      :up
    elsif recent_total < previous_total
      :down
    else
      :flat
    end

    delta = recent_total - previous_total
    delta_label = delta.positive? ? "+#{delta}" : delta.to_s

    {
      recent_total: recent_total,
      previous_total: previous_total,
      trend: trend,
      trend_label: "#{trend.to_s.upcase} #{delta_label} vs previous #{GATE_TREND_WINDOW_DAYS}d",
      sparkline: sparkline_for(recent_series),
      series: recent_series
    }
  end

  def chaos_insight
    latest = recent_chaos_executions.first
    enabled = AgentConfig.enabled?("chaos_orchestrator")

    return disabled_insight unless enabled
    return no_execution_insight if latest.blank?

    decision = execution_decision(latest)
    reasons = execution_reasons(latest)

    {
      enabled: true,
      decision: decision,
      decision_label: decision.to_s.humanize,
      reason: reasons.first || "No skip reason recorded",
      reasons: reasons,
      last_run_at: latest.created_at,
      drill_rationale: extract_drill_rationale(latest),
      auto_chaos_enabled: AgentConfig.get_bool("chaos_orchestrator_enabled")
    }
  end

  def disabled_insight
    {
      enabled: false,
      decision: "disabled",
      decision_label: "Disabled",
      reason: "Chaos orchestrator is disabled. Enable it to collect drill decisions.",
      reasons: ["Chaos orchestrator is disabled."],
      last_run_at: nil,
      drill_rationale: nil,
      auto_chaos_enabled: false
    }
  end

  def no_execution_insight
    {
      enabled: true,
      decision: "pending",
      decision_label: "No Runs Yet",
      reason: "No chaos decision recorded yet. Trigger a run to capture guardrail reasoning.",
      reasons: [],
      last_run_at: nil,
      drill_rationale: nil,
      auto_chaos_enabled: AgentConfig.get_bool("chaos_orchestrator_enabled")
    }
  end

  def recent_chaos_executions
    @recent_chaos_executions ||= AgentExecution
      .for_agent("chaos_orchestrator")
      .where(shard: shard)
      .where(created_at: RECENT_WINDOW_DAYS.days.ago..)
      .recent
      .limit(200)
      .to_a
  end

  def execution_decision(execution)
    result = execution.result.is_a?(Hash) ? execution.result : {}
    raw = result["decision"] || result[:decision]
    return raw.to_s if raw.present?

    return "failed" if execution.failed?
    return "skipped" if execution.action_taken.to_s == "drill_skipped"

    "unknown"
  end

  def execution_reasons(execution)
    result = execution.result.is_a?(Hash) ? execution.result : {}
    reasons = Array(result["reasons"] || result[:reasons]).map(&:to_s).reject(&:blank?)

    if reasons.empty?
      reason = result["reason"] || result[:reason]
      reasons << reason.to_s if reason.present?
    end

    if reasons.empty?
      detail = extract_action_details(execution)
      reasons.concat(Array(detail["reasons"] || detail[:reasons]).map(&:to_s).reject(&:blank?))
    end

    reasons.presence || ["No detailed reason recorded"]
  end

  def extract_drill_rationale(execution)
    result = execution.result.is_a?(Hash) ? execution.result : {}
    drill = result["drill"] || result[:drill]
    drill_hash = drill.is_a?(Hash) ? drill : {}
    drill_hash["rationale"] || drill_hash[:rationale]
  end

  def extract_action_details(execution)
    detail = Array(execution.action_details).last
    return {} unless detail.is_a?(Hash)

    details_hash = detail["details"] || detail[:details]
    details_hash.is_a?(Hash) ? details_hash : {}
  end

  def drill_successful?(execution)
    result = execution.result.is_a?(Hash) ? execution.result : {}
    drill = result["drill"] || result[:drill]
    drill_hash = drill.is_a?(Hash) ? drill : {}
    status = drill_hash["status"] || drill_hash[:status]
    status.to_s == "success"
  end

  def gate_lock_scope(from:, to:)
    shard.incidents
      .where(created_at: from..to)
      .where(
        "title ILIKE :term OR context -> 'classifier' ->> 'reason' = :reason",
        term: "%burning_error_budget%",
        reason: "burning_error_budget"
      )
  end

  def gate_lock_series(from:, to:)
    counts_by_day = gate_lock_scope(from: from, to: to)
      .group("DATE(created_at)")
      .count
      .transform_keys { |date| date.to_date }

    (0...GATE_TREND_WINDOW_DAYS).map do |offset|
      day = from.to_date + offset.days
      counts_by_day.fetch(day, 0)
    end
  end

  def sparkline_for(values)
    return "No data" if values.blank?
    return SPARKLINE_BARS.first * values.length if values.max.to_i.zero?

    max = values.max.to_f
    values.map do |value|
      index = ((value / max) * (SPARKLINE_BARS.length - 1)).round
      SPARKLINE_BARS[index]
    end.join
  end
end
