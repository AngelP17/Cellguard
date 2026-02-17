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

  async post(path, body) {
    const res = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      credentials: "same-origin",
    })

    const text = await res.text()
    if (!res.ok) {
      alert(`Request failed: ${res.status}\n${text}`)
      return
    }

    try {
      const json = JSON.parse(text)
      alert(json.status || "ok")
    } catch {
      alert("ok")
    }
  }
}
