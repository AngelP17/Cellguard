HOST ?= http://localhost:3000
SHARD ?= shard-default
CLASSIFIER_ADDR ?= :8081
RAILS_BASE_URL ?= http://localhost:3000

gameday:
	@echo "=== Game Day: Chaos -> Evaluate -> 423 Locked -> Heal ==="
	@echo "1) Baseline gate"
	@curl -s "$(HOST)/api/release-gate/check?shard=$(SHARD)" | jq .
	@echo ""
	@echo "2) Partition Redis (20s)"
	@curl -s -X POST "$(HOST)/api/chaos/partition" \
	  -H 'Content-Type: application/json' \
	  -d '{"mode":"docker","duration_seconds":20}' | jq .
	@echo ""
	@echo "3) Inject failures (deterministic signal)"
	@curl -s -X POST "$(HOST)/api/inject-failures" \
	  -H 'Content-Type: application/json' \
	  -d "{\"shard\":\"$(SHARD)\",\"queue\":\"default\",\"minutes\":5,\"error_rate\":0.15,\"total\":2000,\"p95_latency_ms\":650}" | jq .
	@echo ""
	@echo "4) Evaluate + classify"
	@curl -s -X POST "$(HOST)/api/evaluate" \
	  -H 'Content-Type: application/json' \
	  -d "{\"shard\":\"$(SHARD)\",\"window_minutes\":60}" | jq .
	@echo ""
	@echo "5) Gate should block (expect 423)"
	@curl -si "$(HOST)/api/release-gate/check?shard=$(SHARD)" | head -n 12
	@echo ""
	@echo "6) Heal"
	@curl -s -X POST "$(HOST)/api/chaos/heal" | jq .

go-classifier-run:
	cd go/classifier && ADDR=$(CLASSIFIER_ADDR) go run ./cmd/classifier

go-classifier-test:
	cd go/classifier && go test ./...

go-agent-runner-run:
	cd go/agent-runner && RAILS_BASE_URL=$(RAILS_BASE_URL) SHARD=$(SHARD) go run ./cmd/runner

go-agent-runner-test:
	cd go/agent-runner && go test ./...

go-ui-smoke:
	cd go/ui-smoke && go run ./cmd/ui-smoke --url "$(HOST)/dashboard" --out ../../tmp/ui-dashboard.png

reset-demo:
	bundle exec rails runner 'shard = Shard.find_or_create_by!(name: ENV.fetch("SHARD", "shard-default")); JobStat.where(shard: shard).delete_all; Incident.where(shard: shard).delete_all; AuditLog.where(shard: shard).delete_all; AgentExecution.where(shard: shard).delete_all; budget = shard.error_budget || shard.build_error_budget; budget.update!(slo_target: 0.999, window_days: 30, window_start: Time.current, budget_consumed: 0.0, budget_remaining: 1.0, current_burn_rate: 0.0, release_gate_open: true, violation_started_at: nil, evaluated_at: Time.current); puts "Reset complete for #{shard.name}"; puts "Gate: OPEN, budget_remaining: #{budget.budget_remaining}"'

enable-chaos-orchestrator:
	bundle exec rails runner 'AgentConfig.toggle!("chaos_orchestrator", true); puts "chaos_orchestrator enabled"'

disable-chaos-orchestrator:
	bundle exec rails runner 'AgentConfig.toggle!("chaos_orchestrator", false); puts "chaos_orchestrator disabled"'
