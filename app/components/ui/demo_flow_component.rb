module Ui
  class DemoFlowComponent < ViewComponent::Base
    # The flagship 15-step closed-loop story condensed for the operator:
    # xyOps runs workflow → degrades → CellGuard ingests → evaluates → locks (423) →
    # incident + evidence → healing proposes xyops remediation → approve → execute →
    # re-eval → gate reopens → full cross-system audit.
    STEPS = [
      { num: 1, label: "xyOps: Run Workflow", endpoint: "internal", code: "running", status: :complete, time: "2m ago" },
      { num: 2, label: "xyOps: Degrade Detected", endpoint: "alert+job", code: "warning", status: :complete, time: "90s ago" },
      { num: 3, label: "CellGuard: Ingest Evidence", endpoint: "ingest+job-stat", code: "202", status: :complete, time: "80s ago" },
      { num: 4, label: "Evaluate + Classify", endpoint: "POST /api/evaluate", code: "200", status: :complete, time: "70s ago" },
      { num: 5, label: "Gate LOCKED", endpoint: "GET /release-gate/check", code: "423 Locked", status: :active, time: "now" },
      { num: 6, label: "Incident + xyOps Snapshot", endpoint: "auto", code: "INC-####", status: :pending, time: "pending" },
      { num: 7, label: "Healing: Propose Remediation", endpoint: "xyops run", code: "approval?", status: :pending, time: "pending" },
      { num: 8, label: "Operator Approves", endpoint: "audit", code: "AUD-####", status: :pending, time: "pending" },
      { num: 9, label: "xyOps: Execute Remediation", endpoint: "trigger", code: "succeeded", status: :pending, time: "pending" },
      { num: 10, label: "Re-evaluate SLO", endpoint: "POST /evaluate", code: "200", status: :pending, time: "pending" },
      { num: 11, label: "Gate REOPENS", endpoint: "check", code: "200 OK", status: :pending, time: "pending" }
    ].freeze
  end
end

