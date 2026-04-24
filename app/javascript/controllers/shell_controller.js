import { Controller } from "@hotwired/stimulus"

// GSAP-enhanced shell animations for operational causality
export default class extends Controller {
  connect() {
    this.initGsap()
  }

  async initGsap() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    try {
      const gsap = await import("gsap")
      this.gsap = gsap.default || gsap
      this.runAnimations()
    } catch (e) {
      console.log("[Shell] GSAP unavailable, using CSS fallbacks")
    }
  }

  runAnimations() {
    const g = this.gsap
    if (!g) return

    // 1. Page reveal — stagger panels
    const panels = this.element.querySelectorAll('[data-gsap]')
    if (panels.length) {
      g.fromTo(panels,
        { opacity: 0, y: 12 },
        { opacity: 1, y: 0, duration: 0.4, stagger: 0.06, ease: "power2.out", delay: 0.05 }
      )
    }

    // 2. Gate state transition — dramatic reveal
    const gatePanel = this.element.querySelector('[data-gsap="gate-panel"]')
    if (gatePanel) {
      const visual = gatePanel.querySelector('.cg-gate-hero__visual')
      const evidence = gatePanel.querySelectorAll('.cg-evidence')
      if (visual) {
        g.fromTo(visual,
          { opacity: 0, scale: 0.92 },
          { opacity: 1, scale: 1, duration: 0.6, ease: "back.out(1.2)", delay: 0.2 }
        )
      }
      if (evidence.length) {
        g.fromTo(evidence,
          { opacity: 0, y: 10 },
          { opacity: 1, y: 0, duration: 0.35, stagger: 0.05, ease: "power2.out", delay: 0.5 }
        )
      }
    }

    // 3. Demo flow step progression
    const demoFlow = this.element.querySelector('[data-gsap="demo-flow"]')
    if (demoFlow) {
      const steps = demoFlow.querySelectorAll('.cg-demo__step')
      g.fromTo(steps,
        { opacity: 0, x: -8 },
        { opacity: 1, x: 0, duration: 0.3, stagger: 0.06, ease: "power2.out", delay: 0.3 }
      )
    }

    // 4. Timeline node stagger
    const timeline = this.element.querySelector('[data-gsap="decision-timeline"]')
    if (timeline) {
      const nodes = timeline.querySelectorAll('.cg-timeline-h__node')
      g.fromTo(nodes,
        { opacity: 0, scale: 0.9 },
        { opacity: 1, scale: 1, duration: 0.3, stagger: 0.05, ease: "power2.out", delay: 0.35 }
      )
    }

    // 5. Scorecards count-up
    const scorecards = this.element.querySelector('[data-gsap="scorecards"]')
    if (scorecards) {
      const values = scorecards.querySelectorAll('.cg-scorecard__value')
      values.forEach(el => {
        const text = el.textContent || ""
        const num = parseFloat(text.replace(/[^0-9.]/g, ''))
        if (!isNaN(num) && num > 0) {
          g.fromTo({ v: 0 }, { v: num }, {
            duration: 0.7,
            ease: "power2.out",
            delay: 0.4,
            onUpdate: function() {
              el.textContent = Math.round(this.targets()[0].v).toString()
            }
          })
        }
      })
    }
  }

  // Called by demo flow buttons
  runDemo() {
    if (!this.gsap) return
    const demo = document.querySelector('[data-gsap="demo-flow"]')
    if (!demo) return

    const steps = demo.querySelectorAll('.cg-demo__step')
    steps.forEach((step, i) => {
      this.gsap.fromTo(step,
        { opacity: 0.3 },
        { opacity: 1, duration: 0.2, delay: i * 0.4 }
      )
      const status = step.querySelector('.cg-demo__status')
      if (status) {
        this.gsap.fromTo(status,
          { scale: 1 },
          { scale: 1.1, duration: 0.15, delay: i * 0.4 + 0.1, yoyo: true, repeat: 1 }
        )
      }
    })
  }
}
