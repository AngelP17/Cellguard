package main

import (
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"cellguard/go/classifier/internal/decision"
	"cellguard/go/classifier/internal/httpapi"
	"cellguard/go/classifier/internal/metrics"
)

func main() {
	addr := env("ADDR", ":8081")

	engine := decision.NewDefaultEngine()
	handler := &httpapi.Handler{Engine: engine}

	metrics.Init()

	mux := http.NewServeMux()
	mux.HandleFunc("/classify", handler.Classify)
	mux.HandleFunc("/healthz", httpapi.Healthz)
	mux.Handle("/metrics", promhttp.Handler())

	root := httpapi.RequestLogMiddleware(mux)
	log.Printf("classifier listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, root))
}

func env(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
