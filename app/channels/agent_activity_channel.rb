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

    broadcast_status_update!

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
    enabled = ActiveModel::Type::Boolean.new.cast(data["enabled"])

    AgentConfig.toggle!(agent_name, enabled)

    ActionCable.server.broadcast("agent_activity", {
      type: "agent_toggled",
      agent: agent_name,
      enabled: enabled
    })

    broadcast_status_update!
  end

  # Request current status
  def request_status
    transmit({
      type: "status_update",
      status: AgentScheduler.status,
      recent_activity: AgentScheduler.recent_activity(limit: 10)
    })
  end

  private

  def broadcast_status_update!
    ActionCable.server.broadcast("agent_activity", {
      type: "status_update",
      status: AgentScheduler.status,
      recent_activity: AgentScheduler.recent_activity(limit: 10)
    })
  end
end
