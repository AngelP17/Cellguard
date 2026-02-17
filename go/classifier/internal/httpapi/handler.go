package httpapi

import (
	"encoding/json"
	"net/http"

	"cellguard/go/classifier/internal/decision"
	"cellguard/go/classifier/internal/metrics"
	"cellguard/go/classifier/internal/model"
)

type Handler struct {
	Engine *decision.Engine
}

func (h *Handler) Classify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req model.ClassifyRequest
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	resp := h.Engine.Classify(req)
	metrics.RecordDecision(resp.IsViolation)

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func Healthz(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}
