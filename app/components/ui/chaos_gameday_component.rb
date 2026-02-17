module Ui
  class ChaosGamedayComponent < ViewComponent::Base
    def initialize(shard:, default_duration: 20, chaos_insight: nil)
      @shard = shard
      @default_duration = default_duration
      @chaos_insight = chaos_insight || {}
    end

    def decision_badge_classes
      case @chaos_insight[:decision].to_s
      when "executed"
        "cg-decision-badge is-success"
      when "recommended"
        "cg-decision-badge is-recommended"
      when "skip", "skipped", "noop"
        "cg-decision-badge is-skipped"
      when "disabled"
        "cg-decision-badge is-disabled"
      else
        "cg-decision-badge"
      end
    end

    def has_reasons?
      Array(@chaos_insight[:reasons]).any?
    end
  end
end
