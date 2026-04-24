module Ui
  class DemoFlowComponent < ViewComponent::Base
    STEPS = [
      { num: 1, label: "Check Gate", endpoint: "GET /api/release_gates", code: "200 OK", status: :complete, time: "2s ago" },
      { num: 2, label: "Inject Failures", endpoint: "POST /api/chaos/partition", code: "202 Accepted", status: :complete, time: "1m ago" },
      { num: 3, label: "Evaluate Budget", endpoint: "POST /api/evaluations", code: "200 OK", status: :complete, time: "1m ago" },
      { num: 4, label: "Gate Locks", endpoint: "—", code: "423 Locked", status: :active, time: "1m ago" },
      { num: 5, label: "Incident Created", endpoint: "POST /api/incidents", code: "201 Created", status: :pending, time: "—" },
      { num: 6, label: "View Runbook", endpoint: "GET /runbooks/gameday", code: "200 OK", status: :pending, time: "—" }
    ].freeze
  end
end
