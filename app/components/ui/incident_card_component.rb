module Ui
  class IncidentCardComponent < ViewComponent::Base
    def initialize(incident:, featured: false)
      @incident = incident
      @featured = featured
      @context = incident.context || {}
      @classifier = @context["classifier"] || {}
      @suggested_runbooks = Array(@context["suggested_runbooks"])
      @severity = @context.dig("severity_assessment", "level").presence || incident.severity_label
      @response_sla = @context.dig("severity_assessment", "response_time_sla")
      @likely_cause = Array(@context["likely_causes"]).first&.dig("description")
      @affected_scope = @context.dig("affected_scope")
    end

    def card_classes
      base = "cg-incident"
      if @featured
        "#{base} is-selected"
      else
        case severity_key
        when "critical" then "#{base} cg-incident--critical"
        when "high" then "#{base} cg-incident--high"
        when "medium" then "#{base} cg-incident--medium"
        when "low" then "#{base} cg-incident--low"
        when "resolved" then "#{base} cg-incident--resolved"
        else base
        end
      end
    end

    def severity_badge
      "cg-severity cg-severity--#{severity_key}"
    end

    def severity_key
      return "resolved" if @incident.status.to_s.downcase == "resolved"
      @severity.to_s.downcase
    end

    def recommended_action
      return "Mark as resolved" if @incident.status.to_s.downcase == "resolved"
      return "Escalate immediately" if severity_key == "critical"
      return "Review runbook and assign owner" if severity_key == "high"
      return "Monitor and document" if severity_key == "medium"
      "Track in backlog"
    end
  end
end
