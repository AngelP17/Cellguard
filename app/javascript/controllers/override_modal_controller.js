import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "shard", "actor", "justification"]
  static values = { open: Boolean }

  connect() {
    this.boundKeyHandler = this.handleKeydown.bind(this)
    document.addEventListener("cellguard:show-override-modal", this.showModal.bind(this))
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeyHandler)
    document.removeEventListener("cellguard:show-override-modal", this.showModal.bind(this))
  }

  showModal(event) {
    this.openValue = true
    this.modalTarget.classList.remove("hidden")
    if (event?.detail?.shard) {
      this.shardTarget.value = event.detail.shard
    }
    this.actorTarget.focus()
    document.addEventListener("keydown", this.boundKeyHandler)
  }

  hideModal() {
    this.openValue = false
    this.modalTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.boundKeyHandler)
    this.clearForm()
  }

  handleKeydown(e) {
    if (e.key === "Escape") this.hideModal()
  }

  clearForm() {
    this.actorTarget.value = ""
    this.justificationTarget.value = ""
  }

  async submit(event) {
    event.preventDefault()
    const actor = this.actorTarget.value.trim()
    const justification = this.justificationTarget.value.trim()
    const shard = this.shardTarget.value || "shard-default"

    if (!actor) {
      this.showToast("Actor name is required", "error")
      return
    }
    if (!justification) {
      this.showToast("Justification is required", "error")
      return
    }

    const submitBtn = event.submitter || this.element.querySelector("[type='submit']")
    const originalText = submitBtn.textContent
    submitBtn.disabled = true
    submitBtn.textContent = "Recording..."

    try {
      const res = await fetch("/api/release-gate/override", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ shard, actor, justification }),
        credentials: "same-origin"
      })

      const json = await res.json()
      if (!res.ok) {
        this.showToast(`Override failed: ${json.error || json.message || res.status}`, "error")
      } else {
        this.showToast("Override recorded successfully", "success")
        this.hideModal()
        setTimeout(() => window.location.reload(), 600)
      }
    } catch (e) {
      this.showToast(`Override error: ${e.message}`, "error")
    } finally {
      submitBtn.disabled = false
      submitBtn.textContent = originalText
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
