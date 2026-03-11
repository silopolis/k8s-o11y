# Requirements: Kubernetes Monitoring Environment

**Defined:** 2025-03-11  
**Core Value:** Enable infrastructure teams to monitor cluster health, service performance, and application traffic in real-time with automated alerting  
**Organization:** `{{ .Values.organization }}` (configurable parameter)

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases. Deadline: 2 days.

### Core Monitoring Stack (MON)

- [ ] **MON-01**: Deploy kube-prometheus-stack via Helmfile with Prometheus Operator, Prometheus, Alertmanager, Grafana
- [ ] **MON-02**: Configure Prometheus retention to 7 days with persistent storage (PVC or emptyDir with limits)
- [ ] **MON-03**: Verify Grafana is accessible and pre-configured dashboards are present (node, pod, workload views)
- [ ] **MON-04**: Verify Alertmanager is receiving alerts from Prometheus default rules
- [ ] **MON-05**: Configure Prometheus to scrape node-exporter and kube-state-metrics (included in stack)
- [ ] **MON-06**: Disable etcd monitoring for Talos compatibility (`etcd.enabled: false`)

### Gateway and Ingress (GW)

- [ ] **GW-01**: Deploy Gateway API CRDs (v1.4.0) before Traefik
- [ ] **GW-02**: Deploy Traefik as Gateway API controller via Helmfile
- [ ] **GW-03**: Configure Traefik to expose Prometheus metrics on port 8080
- [ ] **GW-04**: Enable Traefik access logs in JSON format
- [ ] **GW-05**: Create ServiceMonitor for Traefik metrics collection
- [ ] **GW-06**: Verify Traefik metrics appear in Prometheus targets

### Custom Metrics API (HPA)

- [ ] **HPA-01**: Deploy prometheus-adapter via Helmfile
- [ ] **HPA-02**: Configure prometheus-adapter to query Prometheus for custom metrics
- [ ] **HPA-03**: Register Custom Metrics API with APIService
- [ ] **HPA-04**: Verify custom metrics endpoint responds (`kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"`)
- [ ] **HPA-05**: Configure sample custom metric rule (e.g., `container_cpu_usage_seconds_total`)

### Log Aggregation (LOG)

- [ ] **LOG-01**: Deploy Loki via Helmfile in single-binary mode
- [ ] **LOG-02**: Configure Loki retention with compactor enabled (`retention_enabled: true`)
- [ ] **LOG-03**: Deploy Grafana Alloy as DaemonSet for log collection (NOT Promtail)
- [ ] **LOG-04**: Configure Alloy to tail container logs and ship to Loki
- [ ] **LOG-05**: Verify Loki data source in Grafana
- [ ] **LOG-06**: Test log query in Grafana (LogQL)

### Cluster and Service Monitoring (ALERT)

- [ ] **ALERT-01**: Review and validate default PrometheusRules from kube-prometheus-stack
- [ ] **ALERT-02**: Create custom PrometheusRule for high cluster resource usage (CPU/memory)
- [ ] **ALERT-03**: Create PrometheusRule for Traefik gateway health (gateway down, high error rate)
- [ ] **ALERT-04**: Configure Alertmanager with basic receiver (webhook or null)
- [ ] **ALERT-05**: Test alert firing and routing

### Application Observability (APP)

- [ ] **APP-01**: Deploy training-app (whoami) with 3 replicas via Kubernetes manifests
- [ ] **APP-02**: Create Gateway API HTTPRoute for training-app (host: `app.k8s.localhost`)
- [ ] **APP-03**: Create ServiceMonitor for training-app metrics
- [ ] **APP-04**: Create PrometheusRule for application health (service down, high error rate, high latency)
- [ ] **APP-05**: Generate traffic to training-app using load testing tool
- [ ] **APP-06**: Verify application metrics appear in Prometheus

### Dashboards and Visualization (VIEW)

- [ ] **VIEW-01**: Import or create Grafana dashboard for cluster overview
- [ ] **VIEW-02**: Import or create Grafana dashboard for Traefik traffic analysis
- [ ] **VIEW-03**: Import or create Grafana dashboard for application traffic (requests/s, error rate, latency)
- [ ] **VIEW-04**: Create dashboard variable for service selection (`$service`)
- [ ] **VIEW-05**: Verify dashboards show real-time data under load

## v2 Requirements

Deferred to future release. Tracked but not in current 2-day roadmap.

### Enhanced Observability

- **ENH-01**: Implement GeoIP middleware for access log enrichment
- **ENH-02**: Create geomap panel in Grafana showing geographic request distribution
- **ENH-03**: Configure HPA on training-app using custom metrics (requests/s)
- **ENH-04**: Add Loki log-based alerting
- **ENH-05**: Implement advanced Alertmanager routing (multiple receivers, inhibition)

### Production Hardening

- **PRD-01**: Configure Thanos or Mimir for long-term metrics storage
- **PRD-02**: Implement distributed tracing with Jaeger or Tempo
- **PRD-03**: Add Grafana authentication and role-based access control
- **PRD-04**: Configure backup for Prometheus and Loki data
- **PRD-05**: Set up multi-cluster monitoring federation

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Multi-cluster federation | Single cluster focus for training; Docker Compose federation removed from scope |
| Thanos/Cortex/Mimir | Production scaling concern; local Prometheus storage sufficient for training |
| Distributed tracing (Jaeger/Tempo) | Requires application instrumentation; adds 4-6 hours; defer to v2 |
| Custom Grafana plugins | Visual polish over learning value; use standard panels |
| Advanced alert routing (PagerDuty/Slack) | Adds complexity; keep simple webhook/file output for training |
| eBPF-based monitoring (Cilium, Pixie) | Tooling complexity; stick to ServiceMonitor patterns |
| Persistent storage tuning | PVC configuration overhead; use default storage or emptyDir |
| Part 1 — Docker Compose federation | Separate scope; this project focuses strictly on Part 2 (Kubernetes) |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MON-01 | Phase 1 | Pending |
| MON-02 | Phase 1 | Pending |
| MON-03 | Phase 1 | Pending |
| MON-04 | Phase 1 | Pending |
| MON-05 | Phase 1 | Pending |
| MON-06 | Phase 1 | Pending |
| GW-01 | Phase 2 | Pending |
| GW-02 | Phase 2 | Pending |
| GW-03 | Phase 2 | Pending |
| GW-04 | Phase 2 | Pending |
| GW-05 | Phase 2 | Pending |
| GW-06 | Phase 2 | Pending |
| HPA-01 | Phase 3 | Pending |
| HPA-02 | Phase 3 | Pending |
| HPA-03 | Phase 3 | Pending |
| HPA-04 | Phase 3 | Pending |
| HPA-05 | Phase 3 | Pending |
| LOG-01 | Phase 4 | Pending |
| LOG-02 | Phase 4 | Pending |
| LOG-03 | Phase 4 | Pending |
| LOG-04 | Phase 4 | Pending |
| LOG-05 | Phase 4 | Pending |
| LOG-06 | Phase 4 | Pending |
| ALERT-01 | Phase 5 | Pending |
| ALERT-02 | Phase 5 | Pending |
| ALERT-03 | Phase 5 | Pending |
| ALERT-04 | Phase 5 | Pending |
| ALERT-05 | Phase 5 | Pending |
| APP-01 | Phase 6 | Pending |
| APP-02 | Phase 6 | Pending |
| APP-03 | Phase 6 | Pending |
| APP-04 | Phase 6 | Pending |
| APP-05 | Phase 6 | Pending |
| APP-06 | Phase 6 | Pending |
| VIEW-01 | Phase 7 | Pending |
| VIEW-02 | Phase 7 | Pending |
| VIEW-03 | Phase 7 | Pending |
| VIEW-04 | Phase 7 | Pending |
| VIEW-05 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0 ✓

---
*Requirements defined: 2025-03-11*  
*Last updated: 2025-03-11 after initial definition*
