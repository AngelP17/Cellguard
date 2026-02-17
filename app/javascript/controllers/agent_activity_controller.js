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
      case "agent_toggled":
        this.showNotification(`${data.agent} ${data.enabled ? "enabled" : "disabled"}`)
        this.refresh()
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

  async triggerAgent(event) {
    const button = event.currentTarget
    if (!button) {
      return
    }

    const agentName = button.dataset.agentName
    const enabledByServer = button.dataset.enabled !== "false"
    if (!enabledByServer) {
      this.showNotification(`${agentName} is disabled`, "error")
      return
    }
    
    try {
      await this.runViaHttp(agentName)
    } catch (error) {
      this.showNotification(`Run failed: ${error.message}`, "error")
      this.setButtonBusy(button, false)
      button.className = this.runButtonClasses(enabledByServer)
      button.textContent = enabledByServer ? "Run" : "Enable first"
      return
    }

    // Optimistic UI update
    const previousLabel = button.textContent || "Run"
    this.setButtonBusy(button, true, "Running...")
    this.refresh()
    
    setTimeout(() => {
      if (!button.isConnected) {
        return
      }

      // Respect server-driven enabled/disabled state if available
      const stillEnabled = button.dataset.enabled !== "false"
      button.disabled = !stillEnabled
      button.textContent = stillEnabled ? previousLabel : "Enable first"
      button.className = this.runButtonClasses(stillEnabled)
    }, 2000)
  }

  async toggleAgent(event) {
    const button = event.currentTarget
    if (!button) {
      return
    }

    const agentName = button.dataset.agentName
    const currentlyEnabled = button.dataset.enabled === "true"
    const nextEnabled = !currentlyEnabled

    this.setButtonBusy(button, true, nextEnabled ? "Enabling..." : "Disabling...")

    try {
      const payload = await this.toggleViaHttp(agentName, nextEnabled)
      const effectiveEnabled = payload && payload.enabled === true
      this.applyAgentEnabledState(agentName, effectiveEnabled)
      this.showNotification(`${agentName} ${effectiveEnabled ? "enabled" : "disabled"}`)
    } catch (error) {
      this.showNotification(`Toggle failed: ${error.message}`, "error")
      this.applyAgentEnabledState(agentName, currentlyEnabled)
    } finally {
      this.refresh()
    }
  }

  refresh() {
    if (this.channel) {
      this.channel.perform("request_status")
      return
    }

    this.refreshViaHttp()
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

      card.dataset.agentEnabled = agent.enabled ? "true" : "false"

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
        const enabled = agent.enabled === true
        runButton.dataset.enabled = enabled ? "true" : "false"
        runButton.disabled = !enabled
        runButton.textContent = enabled ? "Run" : "Enable first"
        runButton.className = this.runButtonClasses(enabled)
      }

      const toggleButton = card.querySelector("[data-agent-role='toggle']")
      if (toggleButton) {
        const enabled = agent.enabled === true
        toggleButton.dataset.enabled = enabled ? "true" : "false"
        toggleButton.disabled = false
        toggleButton.textContent = enabled ? "Disable" : "Enable"
        toggleButton.className = this.toggleButtonClasses(enabled)
      }

      const chaosHint = card.querySelector("[data-agent-role='chaos-hint']")
      if (chaosHint) {
        chaosHint.style.display = agent.enabled ? "none" : ""
      }
    })
  }

  applyAgentEnabledState(agentName, enabled) {
    const card = this.element.querySelector(`[data-agent-key=\"${agentName}\"]`)
    if (!card) {
      return
    }

    card.dataset.agentEnabled = enabled ? "true" : "false"

    const badge = card.querySelector("[data-agent-role='badge']")
    if (badge) {
      badge.textContent = enabled ? "Enabled" : "Disabled"
      badge.className = `text-[10px] px-2 py-0.5 rounded-full border ${
        enabled
          ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
          : "bg-neutral-800 text-neutral-400 border-neutral-700"
      }`
    }

    const runButton = card.querySelector("[data-agent-role='run']")
    if (runButton) {
      runButton.dataset.enabled = enabled ? "true" : "false"
      runButton.disabled = !enabled
      runButton.textContent = enabled ? "Run" : "Enable first"
      runButton.className = this.runButtonClasses(enabled)
    }

    const toggleButton = card.querySelector("[data-agent-role='toggle']")
    if (toggleButton) {
      toggleButton.dataset.enabled = enabled ? "true" : "false"
      toggleButton.disabled = false
      toggleButton.textContent = enabled ? "Disable" : "Enable"
      toggleButton.className = this.toggleButtonClasses(enabled)
    }

    const chaosHint = card.querySelector("[data-agent-role='chaos-hint']")
    if (chaosHint) {
      chaosHint.style.display = enabled ? "none" : ""
    }
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

    this.feedTarget.innerHTML = `<div class=\"divide-y divide-neutral-800\" data-agent-activity-list=\"true\">${html}</div>`
  }

  prependActivity(data) {
    // Add new activity item to top of feed
    const item = this.createActivityElement(data)
    const list = this.feedTarget.querySelector("[data-agent-activity-list='true']")
    if (list) {
      list.insertBefore(item, list.firstChild)
    } else {
      this.feedTarget.insertBefore(item, this.feedTarget.firstChild)
    }
    
    // Keep only last 50 items
    const container = list || this.feedTarget
    while (container.children.length > 50) {
      container.removeChild(container.lastChild)
    }
  }

  createActivityElement(data) {
    const div = document.createElement("div")
    div.className = "px-4 py-3 flex items-start gap-3 hover:bg-neutral-900/50 transition-colors"
    
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

  async runViaHttp(agentName) {
    const res = await fetch(`/api/agents/${agentName}/run`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify({ shard: "shard-default" })
    })

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`)
    }
  }

  async toggleViaHttp(agentName, enabled) {
    const res = await fetch(`/api/agents/${agentName}/toggle`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify({ enabled })
    })

    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`)
    }

    return res.json()
  }

  async refreshViaHttp() {
    try {
      const [statusRes, activityRes] = await Promise.all([
        fetch("/api/agents/status", { credentials: "same-origin" }),
        fetch("/api/agents/activity?limit=10", { credentials: "same-origin" })
      ])

      if (statusRes.ok) {
        const status = await statusRes.json()
        if (status && Array.isArray(status.agents)) {
          this.updateAgents(status.agents)
        }
      }

      if (activityRes.ok) {
        const activity = await activityRes.json()
        if (Array.isArray(activity)) {
          this.updateActivity(activity)
        }
      }
    } catch (error) {
      this.showNotification(`Refresh failed: ${error.message}`, "error")
    }
  }

  runButtonClasses(enabled) {
    return enabled ? "cg-btn cg-btn--run" : "cg-btn cg-btn--run is-disabled"
  }

  toggleButtonClasses(enabled) {
    return enabled ? "cg-btn cg-btn--toggle is-enabled" : "cg-btn cg-btn--toggle"
  }

  setButtonBusy(button, isBusy, busyLabel) {
    if (!button) {
      return
    }

    if (isBusy) {
      button.disabled = true
      button.dataset.previousLabel = button.textContent || ""
      button.textContent = busyLabel
      return
    }

    button.disabled = false
    button.textContent = button.dataset.previousLabel || button.textContent
  }
}
