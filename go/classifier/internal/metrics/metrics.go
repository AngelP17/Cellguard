package metrics

import "github.com/prometheus/client_golang/prometheus"

var (
	decisionsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cellguard_decisions_total",
			Help: "Total classification decisions",
		},
		[]string{"violation"},
	)
)

func Init() {
	prometheus.MustRegister(decisionsTotal)
}

func RecordDecision(violation bool) {
	label := "false"
	if violation {
		label = "true"
	}
	decisionsTotal.WithLabelValues(label).Inc()
}
