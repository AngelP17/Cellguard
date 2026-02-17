package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"strconv"
	"time"

	"cellguard/go/agent-runner/internal/agent"
	"cellguard/go/agent-runner/internal/agents"
	"cellguard/go/agent-runner/internal/railsclient"
	"cellguard/go/agent-runner/internal/scheduler"
)

func main() {
	railsURL := env("RAILS_BASE_URL", "http://localhost:3000")
	shard := env("SHARD", "shard-default")

	interval := durationSeconds("AGENT_RUNNER_INTERVAL_SECONDS", 30)
	concurrency := intEnv("AGENT_RUNNER_CONCURRENCY", 2)
	chaosDuration := intEnv("CHAOS_DURATION_SECONDS", 20)
	enableChaos := boolEnv("AGENT_RUNNER_ENABLE_CHAOS", false)
	enableHealing := boolEnv("AGENT_RUNNER_ENABLE_HEALING", true)

	rails := railsclient.New(railsURL)

	agentsList := []agent.Agent{
		&agents.BudgetGuard{Rails: rails, Shard: shard},
	}
	if enableChaos {
		agentsList = append(agentsList, &agents.ChaosOrchestrator{
			Rails:        rails,
			Shard:        shard,
			Duration:     chaosDuration,
			EnabledByEnv: true,
		})
	}
	if enableHealing {
		agentsList = append(agentsList, &agents.Healer{Rails: rails})
	}

	loop := scheduler.Loop{
		Agents:      agentsList,
		Every:       interval,
		Concurrency: concurrency,
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	log.Printf("agent-runner started rails=%s shard=%s every=%s concurrency=%d", railsURL, shard, interval, concurrency)
	loop.Run(ctx)
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}

func intEnv(k string, d int) int {
	if v := os.Getenv(k); v != "" {
		n, err := strconv.Atoi(v)
		if err == nil {
			return n
		}
	}
	return d
}

func boolEnv(k string, d bool) bool {
	if v := os.Getenv(k); v != "" {
		parsed, err := strconv.ParseBool(v)
		if err == nil {
			return parsed
		}
	}
	return d
}

func durationSeconds(k string, d int) time.Duration {
	return time.Duration(intEnv(k, d)) * time.Second
}
