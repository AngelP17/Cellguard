# frozen_string_literal: true

# Generates realistic demo data when the database is empty.
# Called from controllers to ensure the UI never shows empty states.
class DemoDataService
  INCIDENT_TITLES = [
    "Redis connection pool exhausted on shard-default",
    "Sidekiq queue latency spike detected",
    "Database replication lag exceeded 5s threshold",
    "API error rate breaching SLO target",
    "Memory pressure on primary web nodes",
    "Cache hit ratio dropped below 85%",
    "Background job failure rate elevated",
    "Third-party payment gateway timeout",
    "CDN origin fetch latency degradation",
    "Search index lag causing stale results"
  ].freeze

  SEVERITY_LABELS = %w[critical high medium low info].freeze
  STATUSES = %w[active investigating resolved].freeze
  TEAM_LABELS = %w[platform sre backend data infra].freeze
  SERVICE_LABELS = %w[api web worker search payments notifications].freeze

  AUDIT_ACTIONS = [
    { action: "release_gate_override", actor: "operator@cellguard.io", justification: "Emergency patch for CVE-2024-1234. Risk accepted under incident #1042." },
    { action: "budget_evaluation", actor: "budget_guard_agent", justification: "Scheduled evaluation: burn rate 1.2x within threshold." },
    { action: "chaos_drill_executed", actor: "chaos_orchestrator", justification: "Redis partition drill completed successfully. MTTR 4m 12s." },
    { action: "incident_auto_resolved", actor: "healing_agent", justification: "Latency recovered after scaling workers. Auto-closed per policy." },
    { action: "runbook_triggered", actor: "incident_response_agent", justification: "Matched incident context to redis-recovery runbook with 0.94 confidence." },
    { action: "release_gate_override", actor: "sre-oncall@cellguard.io", justification: "Rollback authorization for bad deploy v2.4.1. Post-mortem scheduled." }
  ].freeze

  AGENT_NAMES = %w[budget_guard chaos_orchestrator incident_response healing].freeze

  class << self
    def ensure_all!
      shard = ensure_shard!
      ensure_incidents!(shard)
      ensure_audit_logs!(shard)
      ensure_agent_executions!(shard)
      ensure_error_budget!(shard)
    end

    def ensure_shard!
      Shard.find_or_create_by!(name: "shard-default")
    end

    def ensure_incidents!(shard, count: 6)
      return if Incident.where(shard: shard).count >= count

      count.times do |i|
        created_at = Time.current - (i * 4).hours - rand(10..120).minutes
        resolved_at = i < 3 ? created_at + rand(5..20).minutes : nil
        status = resolved_at ? "resolved" : (i == 3 ? "investigating" : "active")
        severity = SEVERITY_LABELS[i % SEVERITY_LABELS.length]

        Incident.create!(
          shard: shard,
          title: INCIDENT_TITLES[i % INCIDENT_TITLES.length],
          severity_label: severity,
          team_label: TEAM_LABELS[i % TEAM_LABELS.length],
          service_label: SERVICE_LABELS[i % SERVICE_LABELS.length],
          status: status,
          context: incident_context(i, severity),
          created_at: created_at,
          updated_at: resolved_at || created_at
        )
      end
    end

    def ensure_audit_logs!(shard, count: 8)
      return if AuditLog.where(shard: shard).count >= count

      count.times do |i|
        template = AUDIT_ACTIONS[i % AUDIT_ACTIONS.length]
        AuditLog.create!(
          shard: shard,
          actor: template[:actor],
          action: template[:action],
          justification: template[:justification],
          metadata: { source: "demo_data", index: i },
          created_at: Time.current - (i * 2).hours - rand(5..45).minutes
        )
      end
    end

    def ensure_agent_executions!(shard, count: 12)
      return if AgentExecution.where(shard: shard).count >= count

      incidents = shard.incidents.to_a

      count.times do |i|
        agent_name = AGENT_NAMES[i % AGENT_NAMES.length]
        status = i % 7 == 0 ? "failed" : "completed"
        created_at = Time.current - (i * 3).hours - rand(5..60).minutes
        started_at = created_at
        completed_at = status == "completed" ? created_at + (rand(1_000..8_000) / 1000.0) : created_at + (rand(500..2_000) / 1000.0)

        AgentExecution.create!(
          agent_name: agent_name,
          shard: shard,
          incident: incidents.sample,
          status: status,
          action_taken: agent_action(agent_name, status),
          action_details: agent_action_details(agent_name, status),
          result: agent_result(agent_name, status),
          error_message: status == "failed" ? "Simulated failure for demo purposes" : nil,
          started_at: started_at,
          completed_at: completed_at,
          created_at: created_at,
          updated_at: completed_at || created_at
        )
      end
    end

    def ensure_error_budget!(shard)
      budget = shard.error_budget || shard.create_error_budget!(
        slo_target: 0.999,
        window_days: 30,
        window_start: 30.days.ago
      )

      return if budget.budget_consumed.to_f.positive?

      budget.update!(
        budget_consumed: 0.08,
        budget_remaining: 0.92,
        current_burn_rate: 1.2,
        release_gate_open: true,
        evaluated_at: Time.current,
        violation_started_at: nil
      )
    end

    private

    def incident_context(index, severity)
      {
        severity_assessment: {
          level: severity,
          response_time_sla: severity == "critical" ? "5m" : (severity == "high" ? "15m" : "30m"),
          confidence: 0.85 + (rand * 0.14)
        },
        classifier: {
          reason: "burning_error_budget",
          confidence: 0.91
        },
        affected_scope: "shard-default / #{SERVICE_LABELS[index % SERVICE_LABELS.length]}",
        notes: index < 2 ? [
          { "text" => "Initial triage complete. Root cause identified.", "actor" => "sre-oncall@cellguard.io", "created_at" => 10.minutes.ago }
        ] : []
      }
    end

    def agent_action(agent_name, status)
      return "failed" if status == "failed"

      case agent_name
      when "budget_guard" then "evaluation_completed"
      when "chaos_orchestrator" then (rand > 0.5 ? "drill_executed" : "drill_skipped")
      when "incident_response" then "runbook_suggested"
      when "healing" then "auto_resolved"
      else "completed"
      end
    end

    def agent_action_details(agent_name, status)
      return [] if status == "failed"

      details = case agent_name
      when "budget_guard"
        { details: { burn_rate: 1.2, budget_remaining: 0.92, recommendation: "monitor" } }
      when "chaos_orchestrator"
        { details: { drill_type: "redis_partition", duration_seconds: 20, safety_checks_passed: true } }
      when "incident_response"
        { details: { matched_runbook: "redis-recovery", confidence: 0.94 } }
      when "healing"
        { details: { action: "scaled_workers", from: 4, to: 8, reason: "queue_depth > 1000" } }
      else
        {}
      end

      [details]
    end

    def agent_result(agent_name, status)
      return { error: "Simulated demo failure" } if status == "failed"

      case agent_name
      when "budget_guard"
        { decision: "monitor", reasons: ["Burn rate 1.2x within threshold", "Gate remains open"] }
      when "chaos_orchestrator"
        { decision: "executed", reasons: ["Safety checks passed", "Business hours window active"], drill: { status: "success", rationale: "Validated Redis failover path" } }
      when "incident_response"
        { decision: "runbook_suggested", reasons: ["High confidence match", "Severity >= high"] }
      when "healing"
        { decision: "healed", reasons: ["Auto-scaling succeeded", "Latency recovered"] }
      else
        {}
      end
    end
  end
end
