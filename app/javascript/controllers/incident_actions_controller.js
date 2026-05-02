import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { incidentId: Number }

  async acknowledge(event) {
    await this.updateIncident(event, "acknowledge", "acknowledged")
  }

  async resolve(event) {
    await this.updateIncident(event, "resolve", "resolved")
  }

  async escalate(event) {
    await this.updateIncident(event, "escalate", "escalated")
  }

  async addNote(event) {
    const note = prompt("Enter note:")
    if (!note || !note.trim()) return
    await this.updateIncident(event, "note", null, { note: note.trim() })
  }

  async updateIncident(event, action, successStatus, extraBody = {}) {
    const button = event.currentTarget
    const incidentId = button.dataset.incidentId
    if (!incidentId) {
      this.showToast("No incident selected", "error")
      return
    }

    const originalText = button.textContent
    button.disabled = true
    button.textContent = "..."

    try {
      const res = await fetch(`/api/incidents/${incidentId}/${action}`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify(extraBody),
        credentials: "same-origin"
      })

      const json = await res.json()
      if (!res.ok) {
        this.showToast(`${action} failed: ${json.error || res.status}`, "error")
      } else {
        this.showToast(`Incident ${successStatus || action + "d"}`, "success")
        setTimeout(() => window.location.reload(), 500)
      }
    } catch (e) {
      this.showToast(`${action} error: ${e.message}`, "error")
    } finally {
      button.disabled = false
      button.textContent = originalText
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }

  showToast(message, type = "info") {
    window.dispatchEvent(new CustomEvent("cellguard:toast", {
      detail: { message, type }
    }))
  }
}
