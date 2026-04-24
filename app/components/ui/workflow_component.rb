module Ui
  class WorkflowComponent < ViewComponent::Base
    STEPS = [
      "Signal",
      "Evaluation",
      "Gate Decision",
      "Incident",
      "Runbook",
      "Audit"
    ].freeze
  end
end
