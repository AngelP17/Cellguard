package scheduler

import (
	"context"
	"log"
	"sync"
	"time"

	"cellguard/go/agent-runner/internal/agent"
)

type Loop struct {
	Agents      []agent.Agent
	Every       time.Duration
	Concurrency int
}

func (l *Loop) Run(ctx context.Context) {
	if l.Concurrency <= 0 {
		l.Concurrency = 1
	}

	ticker := time.NewTicker(l.Every)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			l.runTick(ctx)
		}
	}
}

func (l *Loop) runTick(ctx context.Context) {
	if len(l.Agents) == 0 {
		return
	}

	sem := make(chan struct{}, l.Concurrency)
	var wg sync.WaitGroup

	for _, a := range l.Agents {
		a := a
		wg.Add(1)

		go func() {
			defer wg.Done()
			select {
			case sem <- struct{}{}:
			case <-ctx.Done():
				return
			}
			defer func() { <-sem }()

			start := time.Now()
			log.Printf("[scheduler] running agent=%s", a.Name())
			if err := a.Run(ctx); err != nil {
				log.Printf("[scheduler] agent=%s error=%v", a.Name(), err)
				return
			}
			log.Printf("[scheduler] agent=%s ok duration_ms=%d", a.Name(), time.Since(start).Milliseconds())
		}()
	}

	wg.Wait()
}
