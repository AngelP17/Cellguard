import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// Stimulus controller for the Agent Activity panel
// Manages WebSocket connection and real-time updates
export default class extends Controller {
  static targets = ["feed"]

  connect() {
    this.subscribeToChannel()
    this.refresh()
  }

  disconnect() {
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  subscribeToChannel() {
    this.channel = consumer.subscriptions.create("AgentActivityChannel", {
      received: (data) => {
        this.handleMessage(data)
      },

      connected: () => {
        console.log("[AgentActivity] Connected to WebSocket")
      },

      disconnected: () => {
        console.log("[AgentActivity] Disconnected from WebSocket")
      }
    })
  }

  handleMessage(data) {
    switch (data.type) {
      case "initial_state":
        this.updateAgents(data.agents)
        this.updateActivity(data.recent_activity)
        break
      case "agent_triggered":
        this.showNotification(`${data.agent} triggered on ${data.shard}`)
        break
      case "agent_error":
        this.showNotification(`Error: ${data.error}`, "error")
        break
      case "status_update":
        if (data.status && Array.isArray(data.status.agents)) {
          this.updateAgents(data.status.agents)
        }
        this.updateActivity(data.recent_activity)
        break
      default:
        // New activity broadcast
        if (data.agent) {
          this.prependActivity(data)
        }
    }
  }

  triggerAgent(event) {
    const button = event.currentTarget
    if (!button) {
      return
    }

    const agentName = button.dataset.agentName
    
    if (this.channel) {
      this.channel.perform("trigger_agent", {
        agent: agentName,
        shard: "shard-default"
      })
    }

    // Optimistic UI update
    const previousLabel = button.textContent
    button.disabled = true
    button.textContent = "Running..."
    
    setTimeout(() => {
      if (!button.isConnected) {
        return
      }

      // Respect server-driven enabled/disabled state if available
      const enabledByServer = button.dataset.enabled !== "false"
      button.disabled = !enabledByServer
      button.textContent = previousLabel || "Run"
    }, 2000)
  }

  refresh() {
    if (this.channel) {
      this.channel.perform("request_status")
    }
  }

  updateAgents(agents) {
    if (!Array.isArray(agents)) {
      return
    }

    agents.forEach((agent) => {
      const card = this.element.querySelector(`[data-agent-key=\"${agent.name}\"]`)
      if (!card) {
        return
      }

      const badge = card.querySelector("[data-agent-role='badge']")
      const runs = card.querySelector("[data-agent-role='runs']")
      const runButton = card.querySelector("[data-agent-role='run']")

      if (badge) {
        badge.textContent = agent.enabled ? "Enabled" : "Disabled"
        badge.className = `text-[10px] px-2 py-0.5 rounded-full border ${
          agent.enabled
            ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
            : "bg-neutral-800 text-neutral-400 border-neutral-700"
        }`
      }

      if (runs) {
        runs.textContent = `${agent.recent_executions} runs today`
      }

      if (runButton) {
        runButton.dataset.enabled = agent.enabled ? "true" : "false"
        runButton.disabled = !agent.enabled
      }
    })
  }

  updateActivity(activity) {
    if (!this.hasFeedTarget || !Array.isArray(activity)) {
      return
    }

    if (activity.length === 0) {
      this.feedTarget.innerHTML = `
        <div class=\"px-4 py-8 text-center\">
          <div class=\"text-sm text-neutral-500\">No agent activity yet</div>
          <div class=\"text-xs text-neutral-600 mt-1\">Agents will appear here when they run</div>
        </div>
      `
      return
    }

    const html = activity
      .map((entry) => {
        const icon = this.statusIcon(entry.status)
        const color = this.statusColor(entry.status)
        const time = this.formatTime(entry.created_at)
        const action = entry.action ? this.humanize(entry.action) : ""
        const shard = entry.shard ? `<span class=\"text-xs text-neutral-500\">${entry.shard}</span>` : ""

        return `
          <div class=\"px-4 py-3 flex items-start gap-3 hover:bg-neutral-900/50 transition-colors\">
            <span class=\"text-lg ${color}\">${icon}</span>
            <div class=\"flex-1 min-w-0\">
              <div class=\"flex items-center gap-2\">
                <span class=\"text-sm font-medium text-neutral-200\">${this.titleize(entry.agent)}</span>
                ${shard}
              </div>
              ${action ? `<div class=\"text-xs text-neutral-400 mt-0.5\">${action}</div>` : ""}
            </div>
            <div class=\"text-xs text-neutral-600 whitespace-nowrap\">${time}</div>
          </div>
        `
      })
      .join("")

    this.feedTarget.innerHTML = `<div class=\"divide-y divide-neutral-800\">${html}</div>`
  }

  prependActivity(data) {
    // Add new activity item to top of feed
    const item = this.createActivityElement(data)
    this.feedTarget.insertBefore(item, this.feedTarget.firstChild)
    
    // Keep only last 50 items
    while (this.feedTarget.children.length > 50) {
      this.feedTarget.removeChild(this.feedTarget.lastChild)
    }
  }

  createActivityElement(data) {
    const div = document.createElement("div")
    div.className = "px-4 py-3 flex items-start gap-3 hover:bg-neutral-900/50 transition-colors animate-in fade-in"
    
    const icon = this.statusIcon(data.status)
    const color = this.statusColor(data.status)
    const time = this.formatTime(data.created_at)
    
    div.innerHTML = `
      <span class="text-lg ${color}">${icon}</span>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span class="text-sm font-medium text-neutral-200">${this.titleize(data.agent)}</span>
          ${data.shard ? `<span class="text-xs text-neutral-500">${data.shard}</span>` : ''}
        </div>
        ${data.action ? `<div class="text-xs text-neutral-400 mt-0.5">${this.humanize(data.action)}</div>` : ''}
      </div>
      <div class="text-xs text-neutral-600 whitespace-nowrap">${time}</div>
    `
    
    return div
  }

  statusIcon(status) {
    switch (status) {
      case "completed": return "✓"
      case "failed": return "✗"
      case "running": return "⟳"
      default: return "○"
    }
  }

  statusColor(status) {
    switch (status) {
      case "completed": return "text-emerald-400"
      case "failed": return "text-red-400"
      case "running": return "text-amber-400"
      default: return "text-neutral-400"
    }
  }

  formatTime(isoString) {
    const date = new Date(isoString)
    const now = new Date()
    const diff = (now - date) / 1000
    
    if (diff < 60) return `${Math.round(diff)}s ago`
    if (diff < 3600) return `${Math.round(diff / 60)}m ago`
    if (diff < 86400) return `${Math.round(diff / 3600)}h ago`
    return date.toLocaleDateString()
  }

  titleize(str) {
    return str.replace(/_/g, " ").replace(/\b\w/g, l => l.toUpperCase())
  }

  humanize(str) {
    return str.replace(/_/g, " ").replace(/^\w/, c => c.toUpperCase())
  }

  showNotification(message, type = "info") {
    // Simple notification - could be enhanced with a toast system
    console.log(`[AgentActivity] ${type}: ${message}`)
  }
}
