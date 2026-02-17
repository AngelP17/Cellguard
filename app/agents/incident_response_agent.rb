# frozen_string_literal: true

module Agents
  # IncidentResponseAgent automatically responds to incidents by:
  # - Analyzing incident patterns
  # - Suggesting relevant runbooks
  # - Auto-creating postmortem drafts
  # - Identifying related past incidents
  # - Recommending team assignments
  class IncidentResponseAgent < BaseAgent
    class << self
      def description
        "Auto-generates runbook suggestions for incidents"
      end

      # Process a specific incident
      def process_incident(incident)
        return nil unless enabled?

        shard = incident.shard
        execution = AgentExecution.start!("incident_response", shard, incident: incident)

        begin
          agent = new(shard: shard, execution: execution)
          result = agent.process(incident)
          execution.complete!(result)
          result
        rescue StandardError => e
          execution.fail!(e.message)
          raise e
        end
      end
    end

    def execute
      # General sweep - check for unprocessed incidents
      results = {
        processed: [],
        suggestions: []
      }

      # Find recent active incidents without recommendations
      unprocessed = shard.incidents
        .where(status: ["active", "investigating"])
        .where("incidents.created_at > ?", 1.hour.ago)
        .left_joins(:agent_executions)
        .group("incidents.id")
        .having("COUNT(agent_executions.id) = 0 OR MAX(agent_executions.created_at) < incidents.created_at")
        .limit(5)

      unprocessed.each do |incident|
        result = process(incident)
        results[:processed] << result if result
      end

      results
    end

    def process(incident)
      return nil if incident.nil?

      result = {
        incident_id: incident.id,
        analysis: analyze_incident(incident),
        runbook_suggestions: suggest_runbooks(incident),
        similar_incidents: find_similar_incidents(incident),
        postmortem_draft: generate_postmortem_draft(incident)
      }

      # Record primary action
      if result[:runbook_suggestions].any?
        record_action!(:runbook_suggested, {
          incident_id: incident.id,
          runbooks: result[:runbook_suggestions],
          auditable: true,
          justification: "Auto-suggested runbooks based on incident classification"
        })
      end

      # Update incident with metadata
      incident.update!(
        context: incident.context.merge(
          agent_analysis: result[:analysis],
          suggested_runbooks: result[:runbook_suggestions],
          similar_incidents: result[:similar_incidents].map(&:id)
        )
      )

      result
    end

    private

    def analyze_incident(incident)
      context = incident.context || {}
      classifier_result = context["classifier"] || {}

      analysis = {
        severity_assessment: assess_severity(incident),
        likely_causes: infer_causes(incident, classifier_result),
        impact_scope: infer_impact(incident),
        confidence: 0.0
      }

      # Confidence based on available data
      analysis[:confidence] = calculate_confidence(analysis)
      analysis
    end

    def assess_severity(incident)
      case incident.severity_label
      when /severity::1/
        { level: :critical, response_time_sla: "15 minutes" }
      when /severity::2/
        { level: :high, response_time_sla: "30 minutes" }
      when /severity::3/
        { level: :medium, response_time_sla: "2 hours" }
      else
        { level: :low, response_time_sla: "4 hours" }
      end
    end

    def infer_causes(incident, classifier_result)
      causes = []

      if classifier_result["reason"]
        causes << { type: :classified, description: classifier_result["reason"] }
      end

      if incident.title.include?("budget")
        causes << { type: :inferred, description: "SLO budget exhaustion" }
      end

      if incident.title.include?("latency")
        causes << { type: :inferred, description: "Performance degradation" }
      end

      causes
    end

    def infer_impact(incident)
      context = incident.context || {}
      budget_context = context.dig("budget")

      {
        service: incident.service_label,
        team: incident.team_label,
        budget_impact: budget_context&.slice("remaining", "burn_rate")
      }
    end

    def calculate_confidence(analysis)
      score = 0.5
      score += 0.2 if analysis[:likely_causes].any?
      score += 0.2 if analysis[:impact_scope][:budget_impact].present?
      score += 0.1 if analysis[:severity_assessment].present?
      [score, 1.0].min
    end

    def suggest_runbooks(incident)
      suggestions = []
      title = incident.title.downcase
      context = incident.context || {}

      # Budget-related incidents
      if title.include?("budget") || context.dig("budget", "remaining").to_f < 0.1
        suggestions << {
          slug: "budget-exhaustion",
          title: "Error Budget Exhaustion Response",
          relevance: 0.95,
          actions: ["Verify error rate calculation", "Check for misconfiguration", "Consider gate override"]
        }
      end

      # Latency-related incidents
      if title.include?("latency") || context.dig("classifier", "reason")&.include?("latency")
        suggestions << {
          slug: "high-latency",
          title: "High Latency Investigation",
          relevance: 0.9,
          actions: ["Check database query performance", "Review recent deployments", "Analyze queue depth"]
        }
      end

      # Chaos-related incidents
      if context.dig("classifier", "reason")&.include?("chaos")
        suggestions << {
          slug: "gameday",
          title: "Game Day Response",
          relevance: 0.85,
          actions: ["Verify chaos is intentional", "Check auto-heal status", "Monitor recovery"]
        }
      end

      # Default incident response
      suggestions << {
        slug: "incident-response",
        title: "General Incident Response",
        relevance: 0.5,
        actions: ["Assess impact", "Notify stakeholders", "Begin timeline documentation"]
      }

      suggestions.sort_by { |s| -s[:relevance] }
    end

    def find_similar_incidents(incident)
      # Find incidents with similar characteristics
      similar = shard.incidents
        .where("id != ?", incident.id)
        .where("created_at > ?", 30.days.ago)
        .where(severity_label: incident.severity_label)
        .or(shard.incidents.where("title ILIKE ?", "%#{incident.title.split.first(3).join(" ")}%"))
        .limit(3)

      similar
    end

    def generate_postmortem_draft(incident)
      return nil unless incident.status == "resolved"

      # Generate a postmortem template pre-filled with incident data
      {
        title: "Postmortem: #{incident.title}",
        summary: "Incident detected at #{incident.created_at}",
        impact: incident.context&.dig("budget") || {},
        timeline: [
          { time: incident.created_at, event: "Incident detected" },
          { time: incident.updated_at, event: "Last status update" }
        ],
        root_cause: incident.context&.dig("classifier", "reason"),
        corrective_actions: suggest_corrective_actions(incident)
      }
    end

    def suggest_corrective_actions(incident)
      actions = []
      context = incident.context || {}

      if context.dig("budget", "burn_rate").to_f > 1.0
        actions << { priority: :high, action: "Review and optimize error rate" }
      end

      if context.dig("classifier", "reason")&.include?("latency")
        actions << { priority: :medium, action: "Performance optimization review" }
      end

      actions << { priority: :low, action: "Update monitoring thresholds" }
      actions
    end
  end
end
