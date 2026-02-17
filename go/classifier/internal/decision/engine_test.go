package decision

import (
	"testing"

	"cellguard/go/classifier/internal/model"
)

func TestViolationByErrorRate(t *testing.T) {
	engine := NewDefaultEngine()

	resp := engine.Classify(testReq(0.20, 200, 0.5))
	if !resp.IsViolation {
		t.Fatalf("expected violation")
	}
}

func TestViolationByLatency(t *testing.T) {
	engine := NewDefaultEngine()

	resp := engine.Classify(testReq(0.01, 900, 0.8))
	if !resp.IsViolation {
		t.Fatalf("expected violation by latency")
	}
}

func TestHealthy(t *testing.T) {
	engine := NewDefaultEngine()

	resp := engine.Classify(testReq(0.01, 200, 0.9))
	if resp.IsViolation {
		t.Fatalf("unexpected violation")
	}
}

func testReq(errRate float64, latency int, budget float64) model.ClassifyRequest {
	return model.ClassifyRequest{
		ErrorRate:       errRate,
		P95LatencyMS:    latency,
		BudgetRemaining: budget,
	}
}
