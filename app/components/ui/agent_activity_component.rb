# frozen_string_literal: true

module Ui
  # Displays real-time agent activity and status
  # Shows which agents are running, what actions they've taken,
  # and provides manual trigger controls
  class AgentActivityComponent < ViewComponent::Base
    include HeroiconsHelper

    def initialize(agents:, recent_activity:)
      @agents = agents
      @recent_activity = recent_activity
    end

    def agent_status_badge(enabled)
      if enabled
        { text: "Enabled", classes: "bg-emerald-500/10 text-emerald-400 border-emerald-500/20" }
      else
        { text: "Disabled", classes: "bg-neutral-800 text-neutral-400 border-neutral-700" }
      end
    end

    def execution_status_icon(status)
      case status
      when "completed"
        heroicon("check-circle", classes: "w-4 h-4")
      when "failed"
        heroicon("x-circle", classes: "w-4 h-4")
      when "running"
        heroicon("arrow-path", classes: "w-4 h-4")
      else
        heroicon("clock", classes: "w-4 h-4")
      end
    end

    def execution_status_color(status)
      case status
      when "completed"
        "text-emerald-400"
      when "failed"
        "text-red-400"
      when "running"
        "text-amber-400"
      else
        "text-neutral-400"
      end
    end

    def toggle_button_label(enabled)
      enabled ? "Disable" : "Enable"
    end

    def toggle_button_classes(enabled)
      base = "cg-btn cg-btn--toggle"
      enabled ? "#{base} is-enabled" : base
    end

    def run_button_label(enabled)
      enabled ? "Run" : "Enable first"
    end

    def run_button_classes(enabled)
      base = "cg-btn cg-btn--run"
      enabled ? base : "#{base} is-disabled"
    end

    def refresh_button_classes
      "cg-btn cg-btn--secondary"
    end

    def format_time_ago(time)
      return "Never" unless time

      diff = Time.current - time
      
      if diff < 60
        "#{diff.round}s ago"
      elsif diff < 3600
        "#{(diff / 60).round}m ago"
      elsif diff < 86400
        "#{(diff / 3600).round}h ago"
      else
        time.strftime("%b %d")
      end
    end
  end
end
