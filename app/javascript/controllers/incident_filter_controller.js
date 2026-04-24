import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  filter(event) {
    const button = event.currentTarget
    const filterValue = button.dataset.filter

    this.element.querySelectorAll('.cg-filter-btn').forEach(btn => {
      btn.classList.toggle('is-active', btn.dataset.filter === filterValue)
    })

    const cards = document.querySelectorAll('[data-incident-severity], [data-incident-status]')
    cards.forEach(card => {
      const severity = card.dataset.incidentSeverity
      const status = card.dataset.incidentStatus?.toLowerCase()
      let visible = true

      switch (filterValue) {
        case "open": visible = status !== "resolved"; break
        case "locked_gate": visible = status === "locked"; break
        case "critical": visible = severity === "critical" && status !== "resolved"; break
        case "needs_runbook": visible = !card.querySelector('.cg-chip, .cg-chip--runbook'); break
        case "resolved": visible = status === "resolved"; break
        default: visible = true
      }

      card.style.display = visible ? "" : "none"
    })

    window.dispatchEvent(new CustomEvent("cellguard:toast", {
      detail: { message: `Filter: ${filterValue}`, type: "info" }
    }))
  }

  search(event) {
    const query = event.target.value.toLowerCase()
    const cards = document.querySelectorAll('[data-incident-severity]')
    cards.forEach(card => {
      card.style.display = card.textContent.toLowerCase().includes(query) ? "" : "none"
    })
  }

  refresh() {
    window.location.reload()
  }
}
