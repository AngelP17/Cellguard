Rails.application.routes.draw do
  # Mount ActionCable for WebSocket connections
  mount ActionCable.server => "/cable"

  namespace :api do
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
