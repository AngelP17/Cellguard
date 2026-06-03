# frozen_string_literal: true

module Xyops
  # Xyops::JobContextMapper
  # Maps xyOps run/job context into the shapes CellGuard's budget evaluator and agents expect.
  # Used by budget_guard and gate evaluation to treat workflow failures as first-class signals.
  class JobContextMapper
    def self.to_job_stat_context(run_or_alert)
      return {} unless run_or_alert
      if run_or_alert.is_a?(XyopsWorkflowRun)
        {
          queue_namespace: run_or_alert.queue || "default",
          error_rate: (run_or_alert.metrics["error_rate"] || 0.12).to_f,
          p95_latency_ms: (run_or_alert.metrics["p95_latency_ms"] || 520).to_i,
          xyops_workflow: run_or_alert.workflow.name,
          server: run_or_alert.server
        }
      else
        {}
      end
    end
  end
end
