package model

type ClassifyRequest struct {
	ShardID         string  `json:"shard_id"`
	QueueNamespace  string  `json:"queue_namespace"`
	WindowMinutes   int     `json:"window_minutes"`
	Total           int     `json:"total"`
	Errors          int     `json:"errors"`
	ErrorRate       float64 `json:"error_rate"`
	P95LatencyMS    int     `json:"p95_latency_ms"`
	BudgetRemaining float64 `json:"budget_remaining"`
	SLOTarget       float64 `json:"slo_target"`
}

type DecisionTrace struct {
	DecisionID string         `json:"decision_id"`
	Inputs     map[string]any `json:"inputs"`
	Thresholds map[string]any `json:"thresholds"`
}

type ClassifyResponse struct {
	IsViolation   bool          `json:"is_violation"`
	Action        string        `json:"action"` // alert | noop
	Reason        string        `json:"reason"`
	DecisionTrace DecisionTrace `json:"decision_trace"`
}
