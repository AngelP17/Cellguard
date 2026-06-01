Rails.application.routes.draw do
  # Mount ActionCable for WebSocket connections
  mount ActionCable.server => "/cable"

  namespace :api do
    # Health and readiness (public probes for Docker / load balancers)
    get "healthz", to: "health#healthz"
    get "readyz",  to: "health#readyz"
    get "status",  to: "health#status"
    get "metrics", to: "health#metrics"

    # Policy wedge
    get  "release-gate/check",    to: "release_gates#check"
    post "release-gate/override", to: "release_gates#override"

    # Data plane
    post "ingest/job-stat", to: "ingest#job_stat"

    # Control plane loop
    post "evaluate", to: "evaluations#create"

    # Demo helper (env-guarded)
    post "inject-failures", to: "simulations#inject_failures"

    # Chaos engineering
    post "chaos/partition", to: "chaos#partition"
    post "chaos/heal",      to: "chaos#heal"

    # Governance
    get  "audit-logs", to: "audit_logs#index"

    # Incident lifecycle
    post "incidents/:id/acknowledge", to: "incidents#acknowledge"
    post "incidents/:id/resolve",     to: "incidents#resolve"
    post "incidents/:id/escalate",    to: "incidents#escalate"
    post "incidents/:id/note",        to: "incidents#note"

    # Agent management (autonomous control plane)
    get  "agents/status",   to: "agents#status"
    get  "agents/activity", to: "agents#activity"
    post "agents/run-all",  to: "agents#run_all"
    post "agents/:name/run",    to: "agents#run"
    post "agents/:name/toggle", to: "agents#toggle"
  end

  root "marketing#home"
  get "/dashboard",  to: "dashboard#index"
  get "/incidents",  to: "incidents#index"

  # Docs viewer (single interface)
  get "/runbooks/:slug",     to: "docs#runbook"
  get "/postmortems/:slug",  to: "docs#postmortem"
end
