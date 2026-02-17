package decision

import (
	"crypto/rand"
	"encoding/hex"

	"cellguard/go/classifier/internal/model"
)

type Engine struct {
	MaxErrorRate    float64
	MaxLatencyMS    int
	MinBudgetRemain float64
}

func NewDefaultEngine() *Engine {
	return &Engine{
		MaxErrorRate:    0.12,
		MaxLatencyMS:    800,
		MinBudgetRemain: 0.0,
	}
}

func (e *Engine) Classify(req model.ClassifyRequest) model.ClassifyResponse {
	violation :=
		req.ErrorRate >= e.MaxErrorRate ||
			req.P95LatencyMS >= e.MaxLatencyMS ||
			req.BudgetRemaining <= e.MinBudgetRemain

	action := "noop"
	reason := "healthy"
	if violation {
		action = "alert"
		reason = "burning_error_budget"
	}

	return model.ClassifyResponse{
		IsViolation: violation,
		Action:      action,
		Reason:      reason,
		DecisionTrace: model.DecisionTrace{
			DecisionID: randomID(),
			Inputs: map[string]any{
				"error_rate":       req.ErrorRate,
				"p95_latency_ms":   req.P95LatencyMS,
				"budget_remaining": req.BudgetRemaining,
			},
			Thresholds: map[string]any{
				"max_error_rate":    e.MaxErrorRate,
				"max_latency_ms":    e.MaxLatencyMS,
				"min_budget_remain": e.MinBudgetRemain,
			},
		},
	}
}

func randomID() string {
	var b [8]byte
	_, _ = rand.Read(b[:])
	return hex.EncodeToString(b[:])
}
