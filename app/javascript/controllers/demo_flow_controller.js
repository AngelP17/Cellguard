import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { shard: String }

  async runFullDemo() {
    const button = this.element.querySelector("[data-demo-action='run']")
    this.setBusy(button, true, "Running...")

    const steps = [
      { label: "Check Gate", fn: () => this.checkGate() },
      { label: "Inject Failures", fn: () => this.injectFailures() },
      { label: "Evaluate Budget", fn: () => this.evaluate() },
      { label: "Verify Lock", fn: () => this.verifyLock() },
    ]

    try {
      for (const step of steps) {
        this.showToast(`Step: ${step.label}...`, "info")
        await step.fn()
        await new Promise(r => setTimeout(r, 400))
      }
      this.showToast("Demo complete. Reloading...", "success")
      setTimeout(() => window.location.reload(), 1000)
    } catch (e) {
      this.showToast(`Demo failed: ${e.message}`, "error")
    } finally {
      this.setBusy(button, false)
    }
  }

  resetDemo() {
    window.location.reload()
  }

  async stepDemo() {
    // Step through: inject failures then evaluate
    const button = this.element.querySelector("[data-demo-action='step']")
    this.setBusy(button, true, "Stepping...")

    try {
      await this.injectFailures()
      await new Promise(r => setTimeout(r, 300))
      await this.evaluate()
      this.showToast("Step complete. Reloading...", "success")
      setTimeout(() => window.location.reload(), 800)
    } catch (e) {
      this.showToast(`Step failed: ${e.message}`, "error")
    } finally {
      this.setBusy(button, false)
    }
  }

  async checkGate() {
    const res = await fetch(`/api/release-gate/check?shard=${this.shardValue || "shard-default"}`, {
      credentials: "same-origin"
    })
    if (!res.ok) throw new Error("Gate check failed")
    return res.json()
  }

  async injectFailures() {
    return this.post("/api/inject-failures", {
      shard: this.shardValue || "shard-default",
      error_rate: 0.15,
      total: 1000
    })
  }

  async evaluate() {
    return this.post("/api/evaluate", {
      shard: this.shardValue || "shard-default",
      window_minutes: 60
    })
  }

  async verifyLock() {
    const data = await this.checkGate()
    if (data.allowed) throw new Error("Gate still open — expected locked")
    return data
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
    if (!res.ok) throw new Error(`${res.status}: ${text}`)
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
