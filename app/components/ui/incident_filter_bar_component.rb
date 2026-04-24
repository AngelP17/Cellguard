module Ui
  class IncidentFilterBarComponent < ViewComponent::Base
    FILTERS = [
      { key: "all", label: "All" },
      { key: "open", label: "Open" },
      { key: "locked_gate", label: "Locked Gate" },
      { key: "critical", label: "Critical" },
      { key: "needs_runbook", label: "Needs Runbook" },
      { key: "resolved", label: "Resolved" }
    ].freeze

    def initialize(active_filter: "all")
      @active_filter = active_filter
    end
  end
end
