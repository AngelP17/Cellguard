module Ui
  class DecisionTimelineComponent < ViewComponent::Base
    STEPS = [
      { label: "Job stats ingested", status: :complete, code: "200", time: "2m ago" },
      { label: "Budget evaluated", status: :complete, code: "200", time: "2m ago" },
      { label: "Burn rate exceeded", status: :danger, code: "ALERT", time: "2m ago" },
      { label: "Gate locked", status: :danger, code: "423", time: "2m ago" },
      { label: "Incident created", status: :complete, code: "201", time: "1m ago" },
      { label: "Runbook suggested", status: :active, code: "—", time: "now" },
      { label: "Audit recorded", status: :pending, code: "—", time: "—" }
    ].freeze
  end
end
