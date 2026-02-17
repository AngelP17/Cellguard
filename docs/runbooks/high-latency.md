# Runbook: High Latency Investigation

Use this when classifier or telemetry indicates sustained high P95/P99 latency.

## Latency Triage Flow

```mermaid
flowchart LR
    A["Latency SLO breach"] --> B["Validate metrics + sampling window"]
    B --> C{"Bottleneck?"}
    C -->|DB| D["Inspect slow queries + pool saturation"]
    C -->|Queue| E["Check backlog + worker concurrency"]
    C -->|Dependency| F["Review downstream API latency"]
    D --> G["Mitigate + re-evaluate"]
    E --> G
    F --> G
```

## Steps
1. Confirm latency breach window and shard scope.
2. Check queue depth and worker throughput.
3. Validate database latency and connection pressure.
4. Inspect dependency health and timeout behavior.
5. Apply mitigation and re-check:
   - `POST /api/evaluate`
   - `GET /api/release-gate/check?shard=shard-default`

## Success Criteria
- latency returns below SLO threshold
- error budget burn returns to sustainable range
- no uncontrolled incident expansion
