package agents

import (
	"context"
	"log"

	"cellguard/go/agent-runner/internal/railsclient"
)

type BudgetGuard struct {
	Rails *railsclient.Client
	Shard string
}

func (b *BudgetGuard) Name() string { return "budget_guard" }

func (b *BudgetGuard) Run(_ context.Context) error {
	code, body, err := b.Rails.GetReleaseGate(b.Shard)
	if err != nil {
		return err
	}

	if code == 423 {
		log.Printf("[budget_guard] gate locked for shard=%s: %s", b.Shard, string(body))
		return b.Rails.PostJSON("/api/agents/incident_response/run", map[string]any{"shard": b.Shard})
	}

	log.Printf("[budget_guard] gate open for shard=%s", b.Shard)
	return nil
}
