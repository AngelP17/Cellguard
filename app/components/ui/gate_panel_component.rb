module Ui
  class GatePanelComponent < ViewComponent::Base
    def initialize(gate_open:, reason: nil, violation_started_at: nil, burn_rate:, budget_remaining:)
      @gate_open = gate_open
      @reason = reason
      @violation_started_at = violation_started_at
      @burn_rate = burn_rate
      @budget_remaining = budget_remaining
    end

    def status_label
      @gate_open ? "OPEN" : "LOCKED (423)"
    end

    def status_classes
      @gate_open ? "border-emerald-500/30 bg-emerald-500/10" : "border-amber-500/30 bg-amber-500/10"
    end
  end
end
