module Ui
  class OperationsFabricComponent < ViewComponent::Base
    include HeroiconsHelper

    def initialize(connection:, workflows: [], alerts: [], recent_runs: [], latest_snapshot: nil, linked_incidents: [])
      @connection = connection
      @workflows = workflows || []
      @alerts = alerts || []
      @recent_runs = recent_runs || []
      @latest_snapshot = latest_snapshot
      @linked_incidents = linked_incidents || []
    end

    def connected?
      @connection&.connected?
    end

    def status_label
      connected? ? "CONNECTED" : "DEGRADED"
    end

    def status_class
      connected? ? "is-ok" : "is-warn"
    end

    def active_alert_count
      @alerts.count { |a| a.active? }
    end

    def recent_failure_count
      @recent_runs.count { |r| r.failed? }
    end

    def fabric_summary
      [
        "#{@workflows.size} workflows",
        "#{active_alert_count} active alerts",
        "#{@recent_runs.size} recent runs"
      ].join(" · ")
    end
  end
end
