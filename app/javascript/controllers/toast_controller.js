import { Controller } from "@hotwired/stimulus"

// Toast notification system
// Listens for cellguard:toast events and renders bottom-right notifications
export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.boundHandleToast = this.handleToast.bind(this)
    window.addEventListener("cellguard:toast", this.boundHandleToast)
  }

  disconnect() {
    window.removeEventListener("cellguard:toast", this.boundHandleToast)
  }

  handleToast(event) {
    const { message, type = "info", duration = 4000 } = event.detail || {}
    if (!message) return
    this.show(message, type, duration)
  }

  show(message, type = "info", duration = 4000) {
    const toast = document.createElement("div")
    toast.className = `cg-toast cg-toast--${type}`
    toast.setAttribute("role", "status")
    toast.setAttribute("aria-live", "polite")

    const icon = this.iconFor(type)
    toast.innerHTML = `
      <span style="flex-shrink: 0; font-size: 1rem;">${icon}</span>
      <span style="line-height: 1.4;">${this.escapeHtml(message)}</span>
    `

    this.containerTarget.appendChild(toast)

    // Auto-remove after duration
    setTimeout(() => {
      toast.classList.add("is-exiting")
      toast.addEventListener("animationend", () => {
        if (toast.parentNode) {
          toast.parentNode.removeChild(toast)
        }
      })
    }, duration)
  }

  iconFor(type) {
    switch (type) {
      case "success": return "✓"
      case "error": return "✕"
      case "warning": return "▲"
      default: return "ℹ"
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
