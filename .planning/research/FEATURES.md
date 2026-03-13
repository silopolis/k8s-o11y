# Feature Landscape: Kubernetes Monitoring

**Domain:** Kubernetes observability with Prometheus/Grafana/Loki stack
**Researched:** 2026-03-11
**Confidence:** HIGH (verified with official docs and 2025-2026 sources)


## Table Stakes (Must Have for Any K8s Monitoring)

Features users expect. Missing these = deployment feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Cluster health metrics** | Core visibility into node/Pod status | LOW | Included in kube-prometheus-stack via node-exporter, kube-state-metrics |
| **Resource utilization dashboards** | CPU/memory/disk/network monitoring | LOW | Pre-built Grafana dashboards (IDs: 315, 6417, 1860) |
| **Pod-level metrics** | Track individual container performance | LOW | cAdvisor built into kubelet, auto-scraped by Prometheus |
| **Alertmanager integration** | Route critical alerts | MEDIUM | Core component of kube-prometheus-stack |
| **Pre-configured alerts** | Kubernetes-specific warnings | LOW | Default rules for CrashLoopBackOff, OOMKilled, NodeNotReady |
| **Service discovery** | Auto-detect new pods/services | LOW | Prometheus Operator handles this via ServiceMonitors |
| **Grafana data source** | Single pane of glass | LOW | Auto-configured when using kube-prometheus-stack |
| **Basic log aggregation** | Access container logs | MEDIUM | Loki/Grafana integration expected |


## Differentiators (Set This Deployment Apart)

Features not expected but add significant value in this training context.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Custom metrics API (HPA)** | Scale based on business metrics | MEDIUM | prometheus-adapter enables HPA on queue depth, request rate |
| **Traefik Gateway monitoring** | Ingress traffic visibility | LOW | ServiceMonitor for Traefik provides request rates, latency |
| **Application-level ServiceMonitors** | Beyond cluster to app metrics | LOW | Demonstrates Prometheus ecosystem extensibility |
| **Correlated logs + metrics** | Troubleshooting workflow | MEDIUM | Loki + Grafana allows log-to-metric correlation |
| **Structured demo alerts** | Practical learning examples | LOW | Focused alerts (CPU, memory, error rates) for training |


## Anti-Features (Explicitly NOT Building)

Features commonly requested but deliberately excluded for 2-day timeline.

| Anti-Feature | Why Avoided | What to Do Instead |
|--------------|-------------|-------------------|
| **Distributed tracing (Jaeger/Tempo)** | Adds 4-6 hours setup, requires app instrumentation | Focus on metrics + logs correlation in Grafana |
| **Thanos/long-term storage** | Production scaling concern, not training focus | Use local Prometheus storage (15d default retention) |
| **Custom Grafana plugins** | Visual polish over learning value | Use standard visualization panels |
| **Multi-cluster federation** | Out of scope (Docker Compose federation removed from scope) | Document federation concept only |
| **eBPF-based monitoring** | Tooling complexity (Cilium, Pixie) | Stick to ServiceMonitor/Prometheus Operator patterns |
| **Advanced alert routing** | PagerDuty/Slack integration adds complexity | Keep Alertmanager with simple webhook/file output |
| **Persistent storage tuning** | PVC configuration overhead | Use default storage classes |


## Feature Dependencies

```
[P0: kube-prometheus-stack]
    ├──requires──> [Prometheus Operator CRDs]
    ├──includes──> [Grafana with dashboards]
    ├──includes──> [Alertmanager]
    ├──includes──> [node-exporter + kube-state-metrics]
    └──enables──> [Basic cluster monitoring]

[P0: Service Discovery]
    └──requires──> [Prometheus Operator running]

[P1: Traefik monitoring]
    ├──requires──> [Traefik deployed]
    └──requires──> [ServiceMonitor created]
        └──requires──> [Prometheus Operator running]

[P1: prometheus-adapter]
    ├──requires──> [Prometheus collecting metrics]
    └──enables──> [HPA with custom metrics]

[P2: Loki + Alloy]
    ├──requires──> [Grafana deployed]
    └──enhances──> [Troubleshooting with logs]

[P2: Application monitoring]
    ├──requires──> [Prometheus ServiceMonitor CRD available]
    └──depends on──> [App exposes /metrics endpoint]

[P2: Custom dashboards]
    ├──requires──> [Grafana deployed]
    └──depends on──> [Metrics flowing]
```


## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority | Phase |
|---------|------------|---------------------|----------|-------|
| Cluster health metrics | HIGH | LOW | P0 | 1 |
| Prometheus + Grafana base | HIGH | LOW | P0 | 1 |
| Pre-configured alerts | HIGH | LOW | P0 | 1 |
| Service discovery | HIGH | LOW | P0 | 1 |
| Traefik Gateway metrics | MEDIUM | LOW | P1 | 2 |
| prometheus-adapter + HPA | HIGH | MEDIUM | P1 | 2 |
| Loki log aggregation | MEDIUM | MEDIUM | P1 | 3 |
| Application ServiceMonitors | MEDIUM | LOW | P2 | 4 |
| Custom Grafana dashboards | LOW | MEDIUM | P2 | 4 |
| Advanced alert routing | LOW | HIGH | P2 | defer |
| Distributed tracing | LOW | HIGH | P2 | defer |
| Long-term storage | LOW | HIGH | P2 | defer |

**Priority key:**

- **P0:** Must have — deployment is incomplete without this
- **P1:** Should have — adds significant value, fits in 2-day window
- **P2:** Nice to have — add if time permits or defer


## MVP for 2-Day Implementation

### Day 1 Focus: Core Stack

**Launch with (Must Have):**

1. **kube-prometheus-stack** — Prometheus, Grafana, Alertmanager, exporters
2. **Default dashboards** — Cluster health, nodes, pods, workloads
3. **Basic alerts** — Node down, high resource usage, pod failures
4. **Service discovery** — Prometheus Operator discovering targets

**Rationale:** These provide immediate visibility and are all included in the Helm chart with minimal configuration.

### Day 2 Focus: Integration & Extension

**Add after core working:**

1. **Traefik ServiceMonitor** — Ingress visibility (1-2 hours)
2. **prometheus-adapter** — Enable custom metrics for HPA (2-3 hours)
3. **Loki + Alloy** — Log aggregation (2-3 hours)
4. **Application monitoring example** — One ServiceMonitor demo (1 hour)

**Defer explicitly:**

- Thanos/long-term storage (production concern)
- Jaeger/Tempo tracing (requires app changes)
- Advanced alert routing (PagerDuty/Slack)
- Multi-cluster federation (removed from scope)
- Custom dashboard building (use defaults)


## Feature Implementation Notes

### kube-prometheus-stack Defaults (What You Get Free)

From the official Helm chart (verified 2026-03-11):

| Component | Included | Value |
|-----------|----------|-------|
| Prometheus Operator | Yes | CRD management |
| Prometheus Server | Yes | Metrics collection |
| Alertmanager | Yes | Alert routing |
| Grafana | Yes | Visualization + 10+ dashboards |
| node-exporter | Yes | Node-level metrics |
| kube-state-metrics | Yes | K8s object state |
| Default rules | Yes | 50+ alert rules |
| Default dashboards | Yes | Node, pod, workload views |

**Missing from chart (must add separately):**

- prometheus-adapter (custom metrics API)
- Loki (logs)
- Traefik-specific monitoring


### Build Order Rationale

Based on dependency graph and official documentation:

1. **kube-prometheus-stack first** — Everything else depends on Prometheus being available
2. **Traefik next** — Gateway is critical infrastructure, should be monitored
3. **prometheus-adapter** — Requires Prometheus metrics to be flowing
4. **Loki** — Enhances troubleshooting but not strictly required
5. **Application monitoring** — Demonstrates extensibility


## Sources

### Official Documentation

- [kube-prometheus-stack Helm chart README](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md) — Verified included components
- [Prometheus Operator documentation](https://github.com/prometheus-operator/prometheus-operator) — CRD capabilities
- [Grafana Loki Kubernetes docs](https://grafana.com/docs/loki/latest/send-data/k8s-monitoring-helm) — Log collection patterns

### 2025-2026 Implementation Guides

- "Deploy Complete kube-prometheus-stack in Production Environment" — SFEIR Institute, March 2026 — Confirms 75% of orgs use this stack
- "How to Use Prometheus Adapter for Custom Metrics API with HPA" — OneUptime, Feb 2026 — HPA integration patterns
- "Building a Production-Grade Observability Stack on Kubernetes" — Technology Geek, Jan 2026 — Three pillars approach
- "How to Deploy kube-prometheus-stack with Grafana and Alertmanager" — OneUptime, Feb 2026 — Complete stack deployment

### Feature Analysis

- [Kubernetes Monitoring Tools in 2025: Top 10 Picks](https://www.kloudfuse.com/blog/kubernetes-monitoring-tools-in-2025-our-top-10-picks) — Market feature expectations
- [Choosing the right Kubernetes monitoring stack in 2026](https://www.spectrocloud.com/blog/choosing-the-right-kubernetes-monitoring-stack) — Current stack recommendations
- [10 Essential Metrics for Kubernetes Monitoring](https://www.metricfire.com/blog/10-essential-metrics-for-kubernetes-monitoring/) — Core monitoring requirements

---
*Feature research for: Kubernetes Monitoring Training Project*
*Researched: 2026-03-11*
*Confidence: HIGH — Verified against official kube-prometheus-stack documentation and current (2026) implementation guides*
