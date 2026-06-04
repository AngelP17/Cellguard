module Ui
  class GatePanelComponent < ViewComponent::Base
    include HeroiconsHelper

    def initialize(
      gate_open:,
      reason: nil,
      violation_started_at: nil,
      burn_rate:,
      budget_remaining:,
      active_incident: nil,
      last_eval_at: nil,
      recommended_action: nil,
      xyops: nil
    )
      @gate_open = gate_open
      @reason = reason
      @violation_started_at = violation_started_at
      @burn_rate = burn_rate
      @budget_remaining = budget_remaining
      @active_incident = active_incident
      @last_eval_at = last_eval_at
      @recommended_action = recommended_action
      @xyops = xyops || {}
    end


    def visual_classes
      base = "cg-gate-hero__visual"
      @gate_open ? "#{base} is-open" : "#{base} is-locked"
    end

    def state_classes
      base = "cg-gate-hero__state"
      @gate_open ? "#{base} is-open" : "#{base} is-locked"
    end

    def panel_classes
      base = "cg-panel cg-glow-#{@gate_open ? 'ok' : 'danger'}"
      state = @gate_open ? "cg-gate-panel--open" : "cg-gate-panel--locked"
      "#{base} #{state}"
    end

    def lock_icon
      @gate_open ? heroicon("lock-open", classes: "w-12 h-12", stroke_width: 1.5) : heroicon("lock-closed", classes: "w-12 h-12", stroke_width: 1.5)
    end

    def burn_color
      return "is-ok" if @burn_rate < 1.0
      return "is-warn" if @burn_rate < 2.0
      "is-danger"
    end

    def budget_color
      return "is-ok" if @budget_remaining > 0.1
      return "is-warn" if @budget_remaining > 0.0
      "is-danger"
    end

    def incident_color
      @active_incident ? "is-danger" : "is-ok"
    end

    def incident_text
      @active_incident ? "ACTIVE" : "NONE"
    end

    def eval_text
      return "n/a" unless @last_eval_at
      ago = Time.current - @last_eval_at
      return "#{ago.round}s ago" if ago < 60
      return "#{(ago / 60).round}m ago" if ago < 3600
      "#{(ago / 3600).round}h ago"
    end

    def recommended_text
      return @recommended_action if @recommended_action.present?
      return "Review runbook before override" unless @gate_open
      "Monitor burn rate. Gate is open."
    end
  end
end
