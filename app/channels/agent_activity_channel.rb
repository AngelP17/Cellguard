# frozen_string_literal: true

# WebSocket channel for real-time agent activity updates
# Dashboard clients subscribe to this to see live agent actions
class AgentActivityChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_activity"
    
    # Send initial state
    transmit({
      type: "initial_state",
      agents: AgentConfig.agents,
      recent_activity: AgentScheduler.recent_activity(limit: 10)
    })
  end

  def unsubscribed
    # Cleanup handled by ActionCable
  end

  # Receive commands from dashboard (manual agent trigger)
  def trigger_agent(data)
    agent_name = data["agent"]
    shard_name = data["shard"] || "shard-default"

    result = AgentScheduler.run_agent_on_shard(agent_name, shard_name)

    transmit({
      type: "agent_triggered",
      agent: agent_name,
      shard: shard_name,
      result: result.present?
    })
  rescue StandardError => e
    transmit({
      type: "agent_error",
      agent: agent_name,
      error: e.message
    })
  end

  # Toggle agent enable/disable
  def toggle_agent(data)
    agent_name = data["agent"]
    enabled = data["enabled"]

    AgentConfig.toggle!(agent_name, enabled)

    transmit({
      type: "agent_toggled",
      agent: agent_name,
      enabled: enabled
    })
  end

  # Request current status
  def request_status
    transmit({
      type: "status_update",
      status: AgentScheduler.status,
      recent_activity: AgentScheduler.recent_activity(limit: 10)
    })
  end
end
