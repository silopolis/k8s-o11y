# Project Roadmap: Kubernetes Monitoring Environment

**Project:** Enable infrastructure teams to monitor cluster health, service performance, and application traffic in real-time with automated alerting.
**Depth:** Quick (5 phases, 2-day deadline)
**Coverage:** 35/35 v1 requirements mapped ✓


## Phases

- [ ] **Phase 1: Core Observability Stack** — Deploy kube-prometheus-stack with Prometheus, Grafana, Alertmanager, and storage
- [ ] **Phase 2: Traefik Gateway API** — Deploy Gateway API CRDs, Traefik controller with metrics, and ServiceMonitor
- [ ] **Phase 3: Metrics API and Log Aggregation** — Deploy prometheus-adapter for HPA and Loki + Alloy for logs
- [ ] **Phase 4: Alerting and Application** — Configure PrometheusRules for cluster and application alerts, deploy training-app with monitoring
- [ ] **Phase 5: Visualization and Dashboards** — Import and create Grafana dashboards for cluster, Traefik, and application traffic


## Phase Details

### Phase 1: Core Observability Stack

**Goal:** Prometheus, Grafana, Alertmanager, and node-level metrics are operational with persistent storage and pre-configured dashboards.

**Depends on:** Nothing (foundation phase)

**Requirements:** MON-01, MON-02, MON-03, MON-04, MON-05, MON-06

**Success Criteria** (what must be TRUE):
  1. Prometheus is collecting metrics from node-exporter and kube-state-metrics
  2. Grafana is accessible and shows pre-configured dashboards (nodes, pods, workloads)
  3. Alertmanager is receiving alerts from default PrometheusRules
  4. Prometheus has 7-day retention configured with storage limits for Talos Docker
  5. etcd monitoring is disabled for Talos compatibility (no CrashLoopBackOff)

**Plans:** TBD


### Phase 01.1: Clear pending TODOs, extend/deepen mise features usage, refactor improve and extend libs and scripts (INSERTED)

**Goal:** [Urgent work - to be planned]
**Depends on:** Phase 1
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd:plan-phase 01.1 to break down)

### Phase 2: Traefik Gateway API

**Goal:** Traefik is operational as Gateway API controller with metrics exposed and scraped by Prometheus.

**Depends on:** Phase 1 (Prometheus Operator needed for ServiceMonitor CRD)

**Requirements:** GW-01, GW-02, GW-03, GW-04, GW-05, GW-06

**Success Criteria** (what must be TRUE):
  1. Gateway API CRDs v1.4.0 are installed and recognized by cluster
  2. Traefik Gateway controller is running and ready
  3. Traefik metrics are exposed on port 8080 and visible in Prometheus targets
  4. Traefik access logs are enabled in JSON format
  5. ServiceMonitor for Traefik has correct `release: kube-prometheus-stack` label and is discovered

**Plans:** TBD


### Phase 3: Metrics API and Log Aggregation

**Goal:** Custom metrics API is available for HPA, and container logs are aggregated to Loki and visible in Grafana.

**Depends on:** Phase 1 (Prometheus and Grafana must be running)

**Requirements:** HPA-01, HPA-02, HPA-03, HPA-04, HPA-05, LOG-01, LOG-02, LOG-03, LOG-04, LOG-05, LOG-06

**Success Criteria** (what must be TRUE):
  1. prometheus-adapter is deployed and Custom Metrics API is registered
  2. `kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"` returns available metrics
  3. Sample custom metric rule (container_cpu_usage_seconds_total) is configured and working
  4. Loki is deployed in single-binary mode with compactor and retention enabled
  5. Grafana Alloy DaemonSet is tailing container logs and shipping to Loki
  6. Loki appears as data source in Grafana and LogQL queries return container logs

**Plans:** TBD


### Phase 4: Alerting and Application

**Goal:** Alerts are configured for cluster health and application metrics; training-app is deployed with full observability.

**Depends on:** Phase 1 (Prometheus Operator), Phase 2 (Traefik for HTTPRoute), Phase 3 (optional: metrics API)

**Requirements:** ALERT-01, ALERT-02, ALERT-03, ALERT-04, ALERT-05, APP-01, APP-02, APP-03, APP-04, APP-05, APP-06

**Success Criteria** (what must be TRUE):
  1. Default PrometheusRules from kube-prometheus-stack are reviewed and active
  2. Custom PrometheusRule exists for high cluster resource usage (CPU/memory thresholds)
  3. PrometheusRule exists for Traefik gateway health (gateway down, high error rate)
  4. Alertmanager has basic receiver configured and test alert fires and routes successfully
  5. training-app is deployed with 3 replicas and accessible via `app.k8s.localhost`
  6. training-app has ServiceMonitor and metrics appear in Prometheus
  7. PrometheusRule exists for application health (service down, high error rate, high latency)
  8. Load testing generates traffic and metrics are visible in real-time

**Plans:** TBD


### Phase 5: Visualization and Dashboards

**Goal:** Custom Grafana dashboards are available and showing real-time data for cluster, Traefik, and application metrics.

**Depends on:** Phase 1 (Grafana), Phase 2 (Traefik metrics), Phase 4 (application metrics)

**Requirements:** VIEW-01, VIEW-02, VIEW-03, VIEW-04, VIEW-05

**Success Criteria** (what must be TRUE):
  1. Grafana dashboard for cluster overview is imported/created and functional
  2. Grafana dashboard for Traefik traffic analysis shows request rates, error rates, latency
  3. Grafana dashboard for application traffic shows requests/s, error rate, latency per service
  4. Dashboard includes variable for service selection (`$service` dropdown)
  5. All dashboards show real-time data when training-app is under load

**Plans:** TBD


## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Observability Stack | 0/3 | Not started | — |
| 2. Traefik Gateway API | 0/2 | Not started | — |
| 3. Metrics API and Log Aggregation | 0/4 | Not started | — |
| 4. Alerting and Application | 0/4 | Not started | — |
| 5. Visualization and Dashboards | 0/2 | Not started | — |

**Last updated:** 2025-03-11 (roadmap created)


## Dependencies

```
Phase 1 ───────────────────────────────────────────────────────┐
  │                                                              │
  ├─→ Phase 2 ──────────────────────────────────────────────┐  │
  │    │                                                       │  │
  │    └─→ Phase 4 (needs Traefik HTTPRoute)                   │  │
  │                                                            │  │
  ├─→ Phase 3 ─────────────────────────────────────────────┐   │  │
  │    │                                                    │   │  │
  │    └─→ (can parallel with Phase 2)                      │   │  │
  │                                                         │   │  │
  └─→ Phase 5 (needs Grafana from P1, metrics from P2/P4) ←─┴───┴──┘
```

**Key dependency notes:**
- Phase 1 must complete first — provides Prometheus Operator CRDs used by ALL ServiceMonitors and PrometheusRules
- Phase 2 and Phase 3 can parallelize after Phase 1 (both need core stack)
- Phase 4 needs both Phase 1 (Prometheus Operator) and Phase 2 (Traefik for HTTPRoute)
- Phase 5 is last — needs Grafana from P1, Traefik metrics from P2, application metrics from P4


## Coverage Validation

| Phase | Requirements | Count |
|-------|--------------|-------|
| 1. Core Observability Stack | MON-01, MON-02, MON-03, MON-04, MON-05, MON-06 | 6 |
| 2. Traefik Gateway API | GW-01, GW-02, GW-03, GW-04, GW-05, GW-06 | 6 |
| 3. Metrics API and Log Aggregation | HPA-01, HPA-02, HPA-03, HPA-04, HPA-05, LOG-01, LOG-02, LOG-03, LOG-04, LOG-05, LOG-06 | 11 |
| 4. Alerting and Application | ALERT-01, ALERT-02, ALERT-03, ALERT-04, ALERT-05, APP-01, APP-02, APP-03, APP-04, APP-05, APP-06 | 11 |
| 5. Visualization and Dashboards | VIEW-01, VIEW-02, VIEW-03, VIEW-04, VIEW-05 | 5 |
| **Total** | | **35/35** ✓ |

**v2 Requirements (deferred):** ENH-01 through ENH-05, PRD-01 through PRD-05


## Risk Areas

Based on research, these phases have known pitfalls:

**Phase 1:** Prometheus storage misconfiguration on single-node Docker — use emptyDir with retention limits
**Phase 2:** ServiceMonitor label selector mismatch — MUST include `release: kube-prometheus-stack` label
**Phase 3:** prometheus-adapter custom metrics API registration — verify `seriesQuery` matches Prometheus exactly
**Phase 3:** Loki retention requires compactor enabled — `retention_enabled: true` not just `retention_period`
**Phase 4:** Alertmanager routing test strategy — plan tests when training app can generate load/errors


---
*Roadmap created: 2025-03-11*
*Ready for planning: yes*
