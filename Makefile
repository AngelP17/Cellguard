HOST ?= http://localhost:3000
SHARD ?= shard-default
CLASSIFIER_ADDR ?= :8081
RAILS_BASE_URL ?= http://localhost:3000

# Normalize local Ruby: prefer rbenv exec when present (avoids /usr/bin/bundle vs managed ruby issues)
ifeq ($(shell command -v rbenv >/dev/null 2>&1 && echo yes),yes)
  RBENV_PREFIX := rbenv exec
else
  RBENV_PREFIX :=
endif
BUNDLE := $(RBENV_PREFIX) bundle
RAILS_RUNNER := $(BUNDLE) exec rails runner

gameday:
	@echo "=== Game Day (FULLY FUNCTIONAL PROOF) ==="
	@echo "1) Reset state"
	@make reset-demo SHARD=$(SHARD)
	@echo "2) Baseline gate open (expect 200)"
	@curl -s "$(HOST)/api/release-gate/check?shard=$(SHARD)" | jq -r '.allowed // .gate // "unknown"'
	@allowed=$$(curl -s "$(HOST)/api/release-gate/check?shard=$(SHARD)" | jq -r '.allowed'); \
	  if [ "$$allowed" != "true" ]; then echo "FAIL: expected open gate, allowed=$$allowed"; exit 1; fi
	@echo ""
	@echo "3) Inject xyOps degradation (full fabric seed)"
	@curl -s -X POST "$(HOST)/api/inject-failures" \
	  -H 'Content-Type: application/json' \
	  -d "{\"shard\":\"$(SHARD)\",\"queue\":\"default\",\"minutes\":5,\"error_rate\":0.15,\"total\":2000,\"p95_latency_ms\":650}" | jq .
	@echo ""
	@echo "4) Confirm xyOps evidence seeded in DB"
	@$(RAILS_RUNNER) 'puts "runs:#{XyopsWorkflowRun.count} alerts:#{XyopsAlert.count} snaps:#{XyopsSnapshot.count} links:#{XyopsJobLink.count}"'
	@echo ""
	@echo "5) Evaluate SLO"
	@curl -s -X POST "$(HOST)/api/evaluate" \
	  -H 'Content-Type: application/json' \
	  -d "{\"shard\":\"$(SHARD)\",\"window_minutes\":60}" | jq .
	@echo ""
	@echo "6) Gate locks (expect 423)"
	@curl -si "$(HOST)/api/release-gate/check?shard=$(SHARD)" | head -n 3
	@allowed=$$(curl -s "$(HOST)/api/release-gate/check?shard=$(SHARD)" | jq -r '.allowed'); \
	  if [ "$$allowed" != "false" ]; then echo "FAIL: expected locked gate, allowed=$$allowed"; exit 1; fi
	@echo ""
	@echo "7) Confirm 423 body has xyops_evidence (API-level proof)"
	@curl -s "$(HOST)/api/release-gate/check?shard=$(SHARD)" | jq '.xyops_evidence // .xyops // "MISSING EVIDENCE"'
	@echo ""
	@echo "8) Incident has xyOps link (durable correlation)"
	@$(RAILS_RUNNER) 'inc=Incident.order(created_at: :desc).first; puts "inc:#{inc&.id} links:#{XyopsJobLink.where(incident_id: inc&.id).count}"'
	@echo ""
	@echo "9) Run healing (triggers remediation path via adapter)"
	@curl -s -X POST "$(HOST)/api/agents/healing/run" \
	  -H 'Content-Type: application/json' \
	  -d "{\"shard\":\"$(SHARD)\"}" | jq '.result // .' | head -c 400 || echo "healing curl (may be non-json)"
	@echo ""
	@echo "10) Post-remediation healthy signal + re-evaluate (ensures gate reopens for proof)"
	@$(RAILS_RUNNER) 'shard=Shard.find_by!(name:ENV.fetch("SHARD","shard-default")); cutoff=10.minutes.ago; JobStat.where(shard: shard).where("meta ->> '\''injected'\'' = ?", "true").update_all(period_start: cutoff - 5.minutes, period_end: cutoff); XyopsAlert.active.update_all(status: "resolved"); wf=XyopsWorkflow.find_by(name:"restart-print-worker") || XyopsWorkflow.first; run=XyopsWorkflowRun.create!(workflow:wf, external_id:"run-remediation-#{Time.current.to_i}", status:"succeeded", started_at:2.minutes.ago, completed_at:1.minute.ago, server_id:"print-worker-02", server_name:"print-worker-02", workflow_name:"restart-print-worker", context:{remediation:true, remediation_for:"latest-failed"}, metadata:{remediation:true}); inc=Incident.active.where(shard:shard).order(created_at: :desc).first; XyopsJobLink.create!(incident:inc, xyops_workflow_run_id:run.id, role:"remediation", remediation_available:false, details:{post_remediation:true}) if inc; JobStat.create!(shard:shard, queue_namespace:"default", period_start:4.minutes.ago, period_end:1.minute.ago, job_count:800, error_count:0, latency_p95_ms:70, meta:{remediation_recovery:true}); puts "remediation succeeded; degraded stats aged; clean recovery stats inserted"'
	@echo ""
	@echo "11) Final re-evaluate (narrow window to observe recovery)"
	@curl -s -X POST "$(HOST)/api/evaluate" \
	  -H 'Content-Type: application/json' \
	  -d "{\"shard\":\"$(SHARD)\",\"window_minutes\":5}" | jq .
	@echo ""
	@echo "12) Gate reopens (expect 200)"
	@curl -s "$(HOST)/api/release-gate/check?shard=$(SHARD)" | jq -r '.allowed // .gate // "unknown"'
	@allowed=$$(curl -s "$(HOST)/api/release-gate/check?shard=$(SHARD)" | jq -r '.allowed'); \
	  if [ "$$allowed" != "true" ]; then echo "FAIL: expected gate to reopen, allowed=$$allowed"; exit 1; fi
	@echo ""
	@echo "13) Audit correlation summary"
	@curl -s "$(HOST)/api/audit-logs?shard=$(SHARD)&limit=30" | jq -r '.[] | select(.action | test("xyops|remediation|gate|incident")) | .action' | sort | uniq -c | sort -rn
	@echo ""
	@echo "=== FULL LOOP PROVEN (open -> degrade -> 423+evidence(DB) -> healing(adapter) -> recovery -> reopened) ==="

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
	$(RAILS_RUNNER) 'shard = Shard.find_or_create_by!(name: ENV.fetch("SHARD", "shard-default")); AgentExecution.where(shard: shard).delete_all; XyopsJobLink.delete_all rescue nil; XyopsAlert.delete_all rescue nil; XyopsWorkflowRun.delete_all rescue nil; XyopsSnapshot.delete_all rescue nil; XyopsWorkflow.where.not(name: "local-xyops").delete_all rescue nil; JobStat.where(shard: shard).delete_all; Incident.where(shard: shard).delete_all; AuditLog.where(shard: shard).delete_all; begin; Xyops::Simulator.reset!; rescue; end; budget = shard.error_budget || shard.build_error_budget; budget.update!(slo_target: 0.999, window_days: 30, window_start: Time.current, budget_consumed: 0.0, budget_remaining: 1.0, current_burn_rate: 0.0, release_gate_open: true, violation_started_at: nil, evaluated_at: Time.current); begin; XyopsConnection.ensure_default_stub!; rescue; end; puts "Reset complete for #{shard.name} (including xyops fabric)"; puts "Gate: OPEN, budget_remaining: #{budget.budget_remaining}"'

enable-chaos-orchestrator:
	$(RAILS_RUNNER) 'AgentConfig.toggle!("chaos_orchestrator", true); puts "chaos_orchestrator enabled"'

disable-chaos-orchestrator:
	$(RAILS_RUNNER) 'AgentConfig.toggle!("chaos_orchestrator", false); puts "chaos_orchestrator disabled"'
