# frozen_string_literal: true

module Xyops
  # Xyops::EventIngestor
  # Turns raw xyOps alerts + workflow runs into first-class CellGuard concepts:
  # - JobStat records (so budget_evaluator sees them)
  # - Incidents (with rich context)
  # - XyopsJobLink evidence records
  # This is how "xyOps degradation" becomes "CellGuard gate decision + audit proof".
  class EventIngestor
    def initialize(client: nil)
      @client = client || Xyops::Client.new
    end

    # Main entry: given a degrading signal from xyops, create the linked incident + stats
    def ingest_degradation!(shard_name: "shard-default", workflow_name: nil, run_external_id: nil)
      shard = Shard.find_or_create_by!(name: shard_name)
      Xyops::Simulator.seed_workflows!

      # Pull the failing run (or start one if this is the first signal)
      run = if run_external_id
              XyopsWorkflowRun.find_by(external_id: run_external_id)
            else
              recent = XyopsWorkflowRun.recent.first
              recent || Xyops::Simulator.start_degrading_run(workflow_name: workflow_name || "nightly-fulfillment-sync", shard: shard_name)
            end

      # Turn the failure metrics into a JobStat so the SLO engine sees real operational pain
      if run && run.failed?
        ps = run.started_at
        pe = run.completed_at || Time.current
        stat = JobStat.find_or_initialize_by(
          shard: shard,
          queue_namespace: run.queue || "fulfillment",
          period_start: ps,
          period_end: pe
        )
        stat.job_count = 2000
        stat.error_count = (run.metrics["error_rate"].to_f * 2000).round
        stat.latency_p95_ms = (run.metrics["p95_latency_ms"] || 650).to_i
        stat.meta = (stat.meta || {}).merge(
          "xyops" => true,
          "workflow" => run.workflow.name,
          "run_id" => run.external_id,
          "server" => run.server
        )
        stat.save!
      end

      # Create or enrich an incident carrying the xyops evidence
      incident = Incident.find_or_initialize_by(
        shard: shard,
        title: "Workflow degradation: #{run&.workflow&.name || workflow_name}",
        status: "active"
      )
      if incident.new_record?
        incident.severity_label = "high"
        incident.service_label = "xyops-fabric"
        incident.team_label = "platform"
        incident.context = {
          "source" => "xyops",
          "workflow" => run&.workflow&.name,
          "run_id" => run&.external_id,
          "server" => run&.server,
          "suggested_runbooks" => [
            { "slug" => "high-latency", "title" => "High Latency Runbook" },
            { "slug" => "budget-exhaustion", "title" => "Budget Exhaustion" }
          ]
        }
        incident.save!

        # Link the triggering run + alert + snapshot
        if run
          XyopsJobLink.create!(
            incident: incident,
            xyops_workflow_run_id: run.id,
            role: "trigger",
            details: { ingested_at: Time.current.iso8601 }
          )
          if (alert = run.alerts.critical.first || run.alerts.active.first)
            XyopsJobLink.create!(incident: incident, xyops_alert_id: alert.id, role: "evidence")
          end
        end
      end

      incident
    end

    # Called when healing succeeds - attach the remediation run as evidence
    def attach_remediation!(incident:, remediation_run_external_id:)
      run = XyopsWorkflowRun.find_by(external_id: remediation_run_external_id)
      return unless run && incident

      XyopsJobLink.create!(
        incident: incident,
        xyops_workflow_run_id: run.id,
        role: "remediation",
        details: { attached_by: "healing", at: Time.current.iso8601 }
      )

      # Also mark the original failure run as resolved context if present
      incident.update!(status: "investigating", context: (incident.context || {}).merge("remediation_attached" => true))
      incident
    end
  end
end
