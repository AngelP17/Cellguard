# frozen_string_literal: true

module Ui
  # Error / empty / degraded state block.
  # Use for: dependency down, action failed, no data with a reason.
  class StateAlertComponent < ViewComponent::Base
    LEVELS = %i[error warning info].freeze

    def initialize(level: :info, title:, message: nil, action_label: nil, action_href: nil)
      @level = LEVELS.include?(level.to_sym) ? level.to_sym : :info
      @title = title
      @message = message
      @action_label = action_label
      @action_href = action_href
    end

    def classes
      case @level
      when :error then "cg-state-alert cg-state-alert--error"
      when :warning then "cg-state-alert cg-state-alert--warn"
      else "cg-state-alert cg-state-alert--info"
      end
    end

    def icon
      case @level
      when :error then "exclamation-triangle"
      when :warning then "exclamation-circle"
      else "information-circle"
      end
    end
  end
end
