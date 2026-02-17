package agents

import (
	"context"
	"log"

	"cellguard/go/agent-runner/internal/railsclient"
)

type Healer struct {
	Rails *railsclient.Client
}

func (h *Healer) Name() string { return "healing" }

func (h *Healer) Run(_ context.Context) error {
	log.Printf("[healing] attempting recovery")
	return h.Rails.PostJSON("/api/chaos/heal", map[string]any{})
}
