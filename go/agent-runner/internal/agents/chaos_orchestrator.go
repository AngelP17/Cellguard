package agents

import (
	"context"
	"log"

	"cellguard/go/agent-runner/internal/railsclient"
)

type ChaosOrchestrator struct {
	Rails         *railsclient.Client
	Shard         string
	Duration      int
	EnabledByEnv  bool
}

func (c *ChaosOrchestrator) Name() string { return "chaos_orchestrator" }

func (c *ChaosOrchestrator) Run(_ context.Context) error {
	if !c.EnabledByEnv {
		log.Printf("[chaos_orchestrator] skipped (enable with AGENT_RUNNER_ENABLE_CHAOS=true)")
		return nil
	}

	log.Printf("[chaos_orchestrator] injecting redis partition for shard=%s", c.Shard)
	return c.Rails.PostJSON("/api/chaos/partition", map[string]any{
		"mode":             "docker",
		"duration_seconds": c.Duration,
	})
}
