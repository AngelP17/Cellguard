import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: Number }

  async partitionDocker() {
    await this.post("/api/chaos/partition", {
      mode: "docker",
      duration_seconds: this.durationValue || 20,
    })
  }

  async partitionTc() {
    await this.post("/api/chaos/partition", {
      mode: "tc",
      duration_seconds: this.durationValue || 20,
      delay_ms: 250,
      loss_percent: 5,
    })
  }

  async heal() {
    await this.post("/api/chaos/heal", {})
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }

  async post(path, body) {
    const res = await fetch(path, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken(),
      },
      body: JSON.stringify(body),
      credentials: "same-origin",
    })

    const text = await res.text()
    if (!res.ok) {
      this.showToast(`Request failed: ${res.status}\n${text}`, "error")
      return
    }

    try {
      const json = JSON.parse(text)
      this.showToast(json.status || "ok", "success")
    } catch {
      this.showToast("ok", "success")
    }
  }

  showToast(message, type = "info") {
    window.dispatchEvent(new CustomEvent("cellguard:toast", {
      detail: { message, type }
    }))
  }
}
