module Ui
  class CommandBarComponent < ViewComponent::Base
    def initialize(shard:, gate_open:, burn_rate:, budget_remaining:, last_eval_at: nil)
      @shard = shard
      @gate_open = gate_open
      @burn_rate = burn_rate
      @budget_remaining = budget_remaining
      @last_eval_at = last_eval_at
    end

    def gate_badge
      @gate_open ? "cg-state-badge cg-state-badge--open" : "cg-state-badge cg-state-badge--locked"
    end

    def gate_text
      @gate_open ? "OPEN" : "423 LOCKED"
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

    def eval_text
      return "n/a" unless @last_eval_at
      ago = Time.current - @last_eval_at
      return "#{ago.round}s ago" if ago < 60
      return "#{(ago / 60).round}m ago" if ago < 3600
      "#{(ago / 3600).round}h ago"
    end
  end
end
