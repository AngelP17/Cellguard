# frozen_string_literal: true

module Xyops
  # Xyops::Simulator
  # Produces deterministic, realistic xyOps data for the closed-loop demo and development.
  # Never used in real prod unless explicitly configured. All data is persisted to the xyops_* tables
  # so that incidents, gate decisions, and audit logs have durable cross-system evidence.
  module Simulator
    DEFAULT_SHARD = "shard-default"

    def self.ensure_connection!
      XyopsConnection.ensure_default_stub!
    end

    def self.connection
      @connection ||= XyopsConnection.ensure_default_stub!
    end

    # Seed a small set of representative production workflows if none exist
    def self.seed_workflows!
      # Always use the live default to avoid stale cached ids from test cleanups
      conn = XyopsConnection.ensure_default_stub!
      # clear any bad cache
      @connection = conn
      return if XyopsWorkflow.where(xyops_connection_id: conn.id).exists?

      [
        { external_id: "wf-prod-deploy-api", name: "deploy-production-api", category: "production" },
        { external_id: "wf-nightly-fulfillment", name: "nightly-fulfillment-sync", category: "production" },
        { external_id: "wf-reconcile-queue", name: "reconcile-queue-workers", category: "maintenance" },
        { external_id: "wf-shipping-label", name: "shipping-label-printer-check", category: "production" },
        { external_id: "wf-restart-worker", name: "restart-print-worker", category: "remediation" },
        { external_id: "wf-chaos-partition", name: "chaos-partition-test", category: "chaos-test" }
      ].each do |attrs|
        XyopsWorkflow.create!(
          connection: conn,
          external_id: attrs[:external_id],
          name: attrs[:name],
          category: attrs[:category],
          status: "active",
          last_run_at: 45.minutes.ago,
          metadata: { owner: "platform", criticality: (attrs[:category] == "production" ? "high" : "medium") }
        )
      end
    end


    def self.workflows(shard: nil, limit: 20)
      seed_workflows!
      XyopsWorkflow.active.recent.limit(limit).map do |wf|
        {
          id: wf.external_id,
          name: wf.name,
          category: wf.category,
          last_run_at: wf.last_run_at,
          status: wf.status
        }
      end
    end

    def self.workflow_run(external_id:)
      run = XyopsWorkflowRun.find_by(external_id: external_id)
      return nil unless run
      serialize_run(run)
    end

    # Simulate a production workflow run that is starting to degrade (queue latency climbing)
    def self.start_degrading_run(workflow_name: "nightly-fulfillment-sync", shard: DEFAULT_SHARD, server: "print-worker-02")
      seed_workflows!
      wf = XyopsWorkflow.find_by(name: workflow_name) || XyopsWorkflow.first

      run = XyopsWorkflowRun.create!(
        workflow: wf,
        external_id: "run-#{Time.current.to_i}-#{SecureRandom.hex(3)}",
        status: "running",
        started_at: 3.minutes.ago,
        server_id: server,
        server_name: server,
        workflow_name: workflow_name,
        failed_job_name: "shipping-label-printer-check",
        context: {
          shard: shard,
          queue: "fulfillment",
          job: workflow_name,
          params: { batch: 4200 }
        },
        metadata: { batch: 4200 },
        metrics: { queue_depth: 1240, p95_latency_ms: 480 }
      )

      # Immediately surface a warning alert (this is what CellGuard will ingest)
      alert = XyopsAlert.create!(
        connection: connection,
        external_id: "alert-#{run.external_id}",
        severity: "warning",
        title: "Queue latency exceeded threshold",
        description: "fulfillment queue p95 latency 480ms (threshold 250ms)",
        source: "queue-latency",
        fired_at: 90.seconds.ago,
        xyops_workflow_run_id: run.id,
        context: { shard: shard, server: server }
      )

      XyopsJobLink.create!(
        xyops_workflow_run_id: run.id,
        xyops_alert_id: alert.id,
        role: "trigger",
        details: { reason: "degrading latency detected by xyops monitor" }
      )

      serialize_run(run)
    end

    # Simulate the job starting to fail / burn budget (called during inject)
    def self.record_job_failure(run_external_id: nil, error_rate: 0.15, p95: 650, server: nil)
      run = if run_external_id
              XyopsWorkflowRun.find_by(external_id: run_external_id)
            else
              XyopsWorkflowRun.where(status: "running").order(started_at: :desc).first
            end
      return unless run

      run.update!(
        status: "failed",
        completed_at: Time.current,
        exit_code: 1,
        logs_summary: "ERROR: shipping label generation timed out after 650ms p95; 15% errors in batch",
        metrics: run.metrics.merge("error_rate" => error_rate, "p95_latency_ms" => p95),
        context: run.context.merge("server_id" => (server || run.server_id))
      )

      # Escalate alert to critical
      if (alert = run.alerts.active.first)
        alert.update!(severity: "critical", resolved_at: nil, title: "Workflow failed: high error rate + latency")
      end

      # Snapshot the bad state (this becomes the "what was running" proof)
      snap = capture_snapshot(server_id: run.server_id, context: { trigger: "workflow_failure", run: run.external_id })

      XyopsJobLink.create!(
        xyops_workflow_run_id: run.id,
        xyops_snapshot_id: snap[:id],
        role: "evidence",
        details: { phase: "failure", burn_contributor: true }
      )

      serialize_run(run)
    end

    def self.capture_snapshot(server_id: "print-worker-02", context: {})
      ensure_connection!
      snap = XyopsSnapshot.create!(
        connection: connection,
        server_id: server_id,
        server_name: server_id,
        external_id: "snap-#{Time.current.to_i}",
        captured_at: Time.current,
        cpu_pct: (context[:cpu] || (82 + rand(12))).round(1),
        cpu_percent: (context[:cpu] || (82 + rand(12))).round(1),
        mem_pct: (context[:mem] || (71 + rand(10))).round(1),
        memory_percent: (context[:mem] || (71 + rand(10))).round(1),
        disk_pct: (context[:disk] || 44.2),
        redis_latency_ms: (context[:redis] || (580 + rand(120))),
        queue_depth: (context[:queue] || (1800 + rand(600))),
        network_status: context[:net] || "ok",
        network_summary: "redis latency elevated",
        process_summary: [
          { name: "fulfillment-worker", pid: 1842, cpu: 67.4, mem_mb: 412 },
          { name: "label-printer", pid: 2211, cpu: 31.9, mem_mb: 188 }
        ],
        metadata: context
      )
      { id: snap.id, server_id: snap.server_id, captured_at: snap.captured_at, summary: snap.summary }
    end

    def self.recent_alerts(shard: nil, since: 30.minutes.ago, limit: 10)
      XyopsAlert.where("fired_at >= ?", since).order(fired_at: :desc).limit(limit).map do |a|
        {
          id: a.external_id,
          severity: a.severity,
          title: a.title,
          source: a.source,
          fired_at: a.fired_at,
          resolved: a.resolved?,
          run_id: a.xyops_workflow_run&.external_id
        }
      end
    end

    def self.job_history(shard:, since:, limit: 50)
      XyopsWorkflowRun.where("started_at >= ?", since)
                      .order(started_at: :desc)
                      .limit(limit)
                      .map { |r| serialize_run(r) }
    end

    # The critical safety path: healing agent (or operator) requests remediation
    # In real life this would be behind approval gates in the UI + token.
    def self.trigger_remediation(name:, params: {}, approval_token: nil)
      ensure_connection!
      wf = XyopsWorkflow.find_by(name: name) || XyopsWorkflow.find_by(name: "restart-print-worker")

      run = XyopsWorkflowRun.create!(
        workflow: wf,
        external_id: "rem-#{Time.current.to_i}-#{SecureRandom.hex(4)}",
        status: "running",
        started_at: Time.current,
        server_id: params[:server] || "print-worker-02",
        server_name: params[:server] || "print-worker-02",
        workflow_name: wf.name,
        failed_job_name: params[:for_run] || "unknown",
        context: { shard: params[:shard] || DEFAULT_SHARD, remediation_for: params[:for_run], params: params },
        metadata: { remediation: true },
        metrics: {}
      )

      # Simulate quick successful remediation (deterministic for demo)
      run.update!(
        status: "succeeded",
        completed_at: Time.current + 4.seconds,
        exit_code: 0,
        logs_summary: "Remediation completed: worker restarted, queue drained, latency back to 89ms p95"
      )

      # Capture post-remediation snapshot proving recovery
      snap = capture_snapshot(server_id: run.server_id, context: { trigger: "remediation_complete", cpu: 19.4, redis: 41 })

      XyopsJobLink.create!(
        xyops_workflow_run_id: run.id,
        xyops_snapshot_id: snap[:id],
        role: "remediation",
        details: { approved_by: approval_token || "healing-agent", outcome: "success" }
      )

      { status: "completed", run_id: run.external_id, workflow: wf.name, snapshot_id: snap[:id] }
    end

    def self.serialize_run(run)
      {
        id: run.external_id,
        workflow: run.workflow.name,
        status: run.status,
        server: run.server,
        started_at: run.started_at,
        completed_at: run.completed_at,
        duration_ms: run.duration_ms,
        exit_code: run.exit_code,
        context: run.context,
        metrics: run.metrics
      }
    end

    # Reset all xyops demo state (used by reset-demo rake/runner)
    def self.reset!
      XyopsJobLink.delete_all
      XyopsAlert.delete_all
      XyopsWorkflowRun.delete_all
      XyopsSnapshot.delete_all
      XyopsWorkflow.delete_all
      # keep the connection
      XyopsConnection.where.not(name: "local-xyops").delete_all
    end

    # --- Interface methods expected by Xyops::Client when in simulator mode ---

    def self.healthy?
      true
    end

    def self.workflow_run(id)
      run = XyopsWorkflowRun.find_by(external_id: id) || XyopsWorkflowRun.order(created_at: :desc).first
      return nil unless run
      {
        id: run.external_id,
        workflow: run.workflow&.name || "unknown",
        status: run.status,
        server: run.server_id,
        started_at: run.started_at,
        completed_at: run.completed_at,
        metadata: run.context
      }
    end

    def self.trigger_remediation!(workflow:, payload: {})
      wf = XyopsWorkflow.find_by(name: workflow) || XyopsWorkflow.first
      run = XyopsWorkflowRun.create!(
        workflow: wf,
        external_id: "rem-#{Time.current.to_i}-#{SecureRandom.hex(4)}",
        status: "succeeded",
        started_at: Time.current,
        completed_at: Time.current + 2.seconds,
        server_id: payload[:server] || "print-worker-02",
        context: { remediation: true, workflow: workflow, payload: payload },
        metrics: {}
      )
      { status: "completed", run_id: run.external_id, workflow: workflow }
    end
  end
end
