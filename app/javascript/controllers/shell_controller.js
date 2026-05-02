import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.initGsap()
  }

  async initGsap() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    try {
      const gsapModule = await import("gsap")
      this.gsap = gsapModule.default || gsapModule

      try {
        const stModule = await import("gsap/ScrollTrigger")
        const ScrollTrigger = stModule.ScrollTrigger || stModule.default
        if (ScrollTrigger) {
          this.gsap.registerPlugin(ScrollTrigger)
          this.ScrollTrigger = ScrollTrigger
        }
      } catch (e) {
        // ScrollTrigger unavailable; continue with basic animations
      }

      if (this.element.classList.contains("cg-shell--landing")) {
        this.runLandingAnimations()
      } else {
        this.runDashboardAnimations()
      }
    } catch (e) {
      console.log("[Shell] GSAP unavailable, using CSS fallbacks")
    }
  }

  runLandingAnimations() {
    const g = this.gsap

    const tl = g.timeline({ defaults: { ease: "power3.out" } })

    const nav = this.element.querySelector('[data-gsap="float-nav"]')
    if (nav) {
      tl.fromTo(nav, { opacity: 0, y: -20 }, { opacity: 1, y: 0, duration: 0.6 }, 0)
    }

    const heroTitle = this.element.querySelector('[data-gsap="hero-title"]')
    if (heroTitle) {
      tl.fromTo(heroTitle, { opacity: 0, y: 30, scale: 0.96 }, { opacity: 1, y: 0, scale: 1, duration: 0.8 }, 0.15)
    }

    const heroSub = this.element.querySelector('[data-gsap="hero-subtitle"]')
    if (heroSub) {
      tl.fromTo(heroSub, { opacity: 0, y: 20 }, { opacity: 1, y: 0, duration: 0.6 }, 0.35)
    }

    const heroDesc = this.element.querySelector('[data-gsap="hero-desc"]')
    if (heroDesc) {
      tl.fromTo(heroDesc, { opacity: 0, y: 15 }, { opacity: 1, y: 0, duration: 0.5 }, 0.5)
    }

    const heroCta = this.element.querySelector('[data-gsap="hero-cta"]')
    if (heroCta) {
      tl.fromTo(heroCta, { opacity: 0, y: 15 }, { opacity: 1, y: 0, duration: 0.5 }, 0.6)
    }

    const heroInd = this.element.querySelector('[data-gsap="hero-indicator"]')
    if (heroInd) {
      tl.fromTo(heroInd, { opacity: 0, scale: 0.9 }, { opacity: 1, scale: 1, duration: 0.5 }, 0.75)
    }

    if (this.ScrollTrigger) {
      this.initScrollReveals(g)
    } else {
      this.initBasicReveals(g)
    }
  }

  initScrollReveals(g) {
    const sections = this.element.querySelectorAll('[data-gsap$="-section"]')
    sections.forEach(section => {
      const children = section.querySelectorAll('[data-gsap]')
      if (children.length) {
        g.fromTo(children,
          { opacity: 0, y: 30 },
          {
            opacity: 1, y: 0,
            duration: 0.6,
            stagger: 0.1,
            ease: "power2.out",
            scrollTrigger: {
              trigger: section,
              start: "top 85%",
              toggleActions: "play none none none"
            }
          }
        )
      } else {
        g.fromTo(section,
          { opacity: 0, y: 30 },
          {
            opacity: 1, y: 0,
            duration: 0.7,
            ease: "power2.out",
            scrollTrigger: {
              trigger: section,
              start: "top 85%",
              toggleActions: "play none none none"
            }
          }
        )
      }
    })

    const bentoGate = this.element.querySelector('[data-gsap="bento-gate"]')
    if (bentoGate) {
      const httpCode = bentoGate.querySelector('.cg-bento__gate-http')
      if (httpCode) {
        g.fromTo(httpCode,
          { scale: 0.7, opacity: 0 },
          {
            scale: 1, opacity: 1,
            duration: 0.8,
            ease: "back.out(1.4)",
            scrollTrigger: {
              trigger: bentoGate,
              start: "top 80%",
              toggleActions: "play none none none"
            }
          }
        )
      }
    }

    const capabilities = this.element.querySelectorAll('[data-gsap^="cap-"]')
    capabilities.forEach((cap, i) => {
      g.fromTo(cap,
        { opacity: 0, y: 40, scale: 0.95 },
        {
          opacity: 1, y: 0, scale: 1,
          duration: 0.6,
          delay: i * 0.12,
          ease: "power2.out",
          scrollTrigger: {
            trigger: cap,
            start: "top 88%",
            toggleActions: "play none none none"
          }
        }
      )
    })

    const pipeline = this.element.querySelector('[data-gsap="pipeline"]')
    if (pipeline) {
      const steps = pipeline.querySelectorAll('.cg-pipeline__step')
      g.fromTo(steps,
        { opacity: 0, x: -15 },
        {
          opacity: 1, x: 0,
          duration: 0.4,
          stagger: 0.08,
          ease: "power2.out",
          scrollTrigger: {
            trigger: pipeline,
            start: "top 85%",
            toggleActions: "play none none none"
          }
        }
      )
    }

    const stackStrip = this.element.querySelector('[data-gsap="stack-strip"]')
    if (stackStrip) {
      const badges = stackStrip.querySelectorAll('.cg-stack-strip__badge')
      g.fromTo(badges,
        { opacity: 0, y: 10 },
        {
          opacity: 1, y: 0,
          duration: 0.3,
          stagger: 0.05,
          ease: "power2.out",
          scrollTrigger: {
            trigger: stackStrip,
            start: "top 90%",
            toggleActions: "play none none none"
          }
        }
      )
    }
  }

  initBasicReveals(g) {
    const allGsap = this.element.querySelectorAll('[data-gsap]')
    if (allGsap.length) {
      g.fromTo(allGsap,
        { opacity: 0, y: 16 },
        { opacity: 1, y: 0, duration: 0.5, stagger: 0.06, ease: "power2.out", delay: 0.8 }
      )
    }
  }

  runDashboardAnimations() {
    const g = this.gsap

    const panels = this.element.querySelectorAll('[data-gsap]')
    if (panels.length) {
      g.fromTo(panels,
        { opacity: 0, y: 12 },
        { opacity: 1, y: 0, duration: 0.4, stagger: 0.06, ease: "power2.out", delay: 0.05 }
      )
    }

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

    const demoFlow = this.element.querySelector('[data-gsap="demo-flow"]')
    if (demoFlow) {
      const steps = demoFlow.querySelectorAll('.cg-demo__step')
      g.fromTo(steps,
        { opacity: 0, x: -8 },
        { opacity: 1, x: 0, duration: 0.3, stagger: 0.06, ease: "power2.out", delay: 0.3 }
      )
    }

    const timeline = this.element.querySelector('[data-gsap="decision-timeline"]')
    if (timeline) {
      const nodes = timeline.querySelectorAll('.cg-timeline-h__node')
      g.fromTo(nodes,
        { opacity: 0, scale: 0.9 },
        { opacity: 1, scale: 1, duration: 0.3, stagger: 0.05, ease: "power2.out", delay: 0.35 }
      )
    }

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
