HOST ?= http://localhost:3000
SHARD ?= shard-default

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
