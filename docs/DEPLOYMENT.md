# Docker Deployment

CellGuard ships a production-ready Dockerfile that works with any Docker-compatible runtime (Docker, Podman, containerd, ECS, Fly.io, Render, Railway, etc.). The image bundles the Rails web app and Sidekiq worker entrypoints; the Go classifier and Go agent-runner are separate small images.

## Image roles

| Role | Image | Port | Entry point |
|------|-------|------|-------------|
| `web` | Dockerfile (Rails) | 3000 | `./bin/rails server` |
| `worker` | Dockerfile (Rails) | n/a | `bundle exec sidekiq -C config/sidekiq.yml` |
| `scheduler` | Dockerfile (Rails) | n/a | `bundle exec sidekiq -C config/sidekiq.yml` (same as worker) |
| `classifier` | `go/classifier/Dockerfile` | 8081 | `./classifier` |
| `agent-runner` | `go/agent-runner/Dockerfile` | n/a | `./runner` (cron-driven) |

`web` and `worker` share the same image; the `CMD` is overridden at runtime.

## Required environment variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | yes | Postgres connection string |
| `REDIS_URL` | yes | Redis connection string for Sidekiq + ActionCable |
| `SECRET_KEY_BASE` | yes | Rails secret key (generate with `bin/rails secret`) |
| `RAILS_MASTER_KEY` | yes (if using encrypted credentials) | Decrypts `config/credentials.yml.enc` |
| `CELLGUARD_TOKEN` | yes in production | Admin token for privileged API endpoints |
| `CLASSIFIER_URL` | yes | URL of the Go classifier service (e.g. `http://classifier:8081`) |
| `ALLOW_DEMO_ENDPOINTS` | no | Set to `true` only for demo environments to allow chaos + failure injection |
| `CLASSIFIER_STUB` | no | Set to `true` to use the in-process Ruby classifier stub (no Go service required) |
| `RAILS_LOG_TO_STDOUT` | recommended | Set to `true` for log aggregation |
| `RAILS_SERVE_STATIC_FILES` | recommended | Set to `true` behind a CDN/reverse proxy |
| `GIT_SHA` | recommended | Set to the deployed commit SHA for audit trail |
| `CELLGUARD_AGENTS_ENABLED` | optional | Master switch for autonomous agents (`true` / `false`) |
| `CELLGUARD_AGENT_EXECUTION_INTERVAL_SECONDS` | optional | Scheduler tick interval (default 60) |
| `CELLGUARD_BUDGET_GUARD_ENABLED` | optional | Enable `budget_guard` agent (default `true`) |
| `CELLGUARD_CHAOS_ORCHESTRATOR_ENABLED` | optional | Enable `chaos_orchestrator` agent (default `false`, safety) |
| `CELLGUARD_INCIDENT_RESPONSE_ENABLED` | optional | Enable `incident_response` agent (default `true`) |
| `CELLGUARD_HEALING_AGENT_ENABLED` | optional | Enable `healing` agent (default `true`) |

## Minimal `docker run` example

```bash
docker build -t cellguard-web .

docker run -d --name cellguard-web -p 3000:3000 \
  -e RAILS_ENV=production \
  -e DATABASE_URL=postgres://cellguard:secret@db:5432/cellguard_production \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e CELLGUARD_TOKEN=$(openssl rand -hex 32) \
  -e CLASSIFIER_URL=http://classifier:8081 \
  -e RAILS_LOG_TO_STDOUT=true \
  -e RAILS_SERVE_STATIC_FILES=true \
  cellguard-web
```

## Sidekiq worker

```bash
docker run -d --name cellguard-worker \
  -e RAILS_ENV=production \
  -e DATABASE_URL=postgres://cellguard:secret@db:5432/cellguard_production \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY_BASE=$SECRET_KEY_BASE \
  -e CELLGUARD_TOKEN=$CELLGUARD_TOKEN \
  -e CLASSIFIER_URL=http://classifier:8081 \
  cellguard-web \
  bundle exec sidekiq -C config/sidekiq.yml
```

## Go classifier

```bash
cd go/classifier
docker build -t cellguard-classifier .
docker run -d --name cellguard-classifier -p 8081:8081 cellguard-classifier
```

## Container smoke commands

Run these after a fresh deploy to verify the stack is healthy:

```bash
# 1. Migrations (one-shot, can be a Kubernetes Job or pre-deploy hook)
docker run --rm \
  -e DATABASE_URL=$DATABASE_URL \
  cellguard-web \
  bundle exec rails db:migrate

# 2. Liveness
curl -fsS http://localhost:3000/api/healthz

# 3. Readiness
curl -fsS http://localhost:3000/api/readyz

# 4. Detailed status (includes version and component state)
curl -fsS http://localhost:3000/api/status

# 5. Gate proof (should return 200)
curl -fsS http://localhost:3000/api/release-gate/check?shard=shard-default

# 6. Admin endpoint rejects without token
curl -i -X POST http://localhost:3000/api/release-gate/override \
  -H "Content-Type: application/json" \
  -d '{"shard":"shard-default","actor":"smoke","justification":"smoke"}'
# → HTTP/1.1 401 Unauthorized
```

## Reverse proxy / TLS

The `web` container speaks plain HTTP on port 3000. Put it behind nginx, Caddy, or a managed load balancer that handles TLS termination and HTTP/2.

## Data volume

The container writes to:

- `/rails/log` — application logs (mount a volume or ship to stdout)
- `/rails/tmp` — Sidekiq tmp files
- `/rails/storage` — Active Storage (only if you enable it)

## Health check

The image does not ship a Docker `HEALTHCHECK` directive by default. Configure your orchestrator to poll `GET /api/healthz` every 10s and `GET /api/readyz` every 30s for liveness and readiness respectively.
