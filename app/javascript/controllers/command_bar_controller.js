import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { shard: String }

  async runEvaluation() {
    const button = this.element.querySelector("[data-action='click->command-bar#runEvaluation']")
    this.setBusy(button, true, "Evaluating...")

    try {
      const res = await fetch("/api/evaluate", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ shard: this.shardValue || "shard-default", window_minutes: 60 }),
        credentials: "same-origin"
      })

      const json = await res.json()
      if (!res.ok) {
        this.showToast(`Evaluation failed: ${json.error || res.status}`, "error")
      } else {
        const gateStatus = json.budget?.gate_open ? "OPEN" : "LOCKED"
        this.showToast(`Evaluation complete. Gate is ${gateStatus}.`, "success")
        setTimeout(() => window.location.reload(), 800)
      }
    } catch (e) {
      this.showToast(`Evaluation error: ${e.message}`, "error")
    } finally {
      this.setBusy(button, false)
    }
  }

  async runGameDay() {
    const button = this.element.querySelector("[data-action='click->command-bar#runGameDay']")
    this.setBusy(button, true, "Injecting...")

    try {
      // Step 1: Inject failures
      await this.post("/api/inject-failures", {
        shard: this.shardValue || "shard-default",
        error_rate: 0.15,
        total: 1000
      })
      this.showToast("Failures injected. Evaluating...", "info")

      // Step 2: Evaluate
      await new Promise(r => setTimeout(r, 500))
      const evalRes = await this.post("/api/evaluate", {
        shard: this.shardValue || "shard-default",
        window_minutes: 60
      })

      this.showToast("Game day complete. Gate evaluated.", "success")
      setTimeout(() => window.location.reload(), 800)
    } catch (e) {
      this.showToast(`Game day error: ${e.message}`, "error")
    } finally {
      this.setBusy(button, false)
    }
  }

  showOverrideModal() {
    window.dispatchEvent(new CustomEvent("cellguard:show-override-modal", {
      detail: { shard: this.shardValue || "shard-default" }
    }))
  }

  async post(path, body) {
    const res = await fetch(path, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body),
      credentials: "same-origin"
    })

    const text = await res.text()
    if (!res.ok) {
      throw new Error(`${res.status}: ${text}`)
    }
    try { return JSON.parse(text) } catch { return { status: "ok" } }
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

  setBusy(button, isBusy, busyLabel) {
    if (!button) return
    if (isBusy) {
      button.disabled = true
      button.dataset.previousLabel = button.textContent || ""
      button.textContent = busyLabel
    } else {
      button.disabled = false
      button.textContent = button.dataset.previousLabel || button.textContent
    }
  }
}
