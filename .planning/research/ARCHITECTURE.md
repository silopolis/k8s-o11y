# Architecture Research: Kubernetes Monitoring Stack

**Domain:** Kubernetes Observability Infrastructure
**Researched:** 2026-03-11
**Confidence:** HIGH

## System Overview

The Kubernetes monitoring environment follows a layered observability architecture built around the three pillars of observability: metrics, logs, and alerts. The stack is designed for production readiness while maintaining GitOps compatibility.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     VISUALIZATION LAYER                              │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐   │
│  │   Grafana   │◄───│  Pre-configured  │    │   Custom App    │   │
│  │ Dashboards  │    │  K8s Dashboards  │    │   Dashboards    │   │
│  └─────────────┘    └──────────────────┘    └─────────────────┘   │
├─────────────────────────────────────────────────────────────────────┤
│                      DATA CONSUMPTION LAYER                          │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌───────────────────────┐   │
│  │  Prometheus │◄───│ HPA Adapter │    │   Alertmanager        │   │
│  │  (Metrics)  │────►│(Custom API) │    │ (Routing/Silencing)   │   │
│  └──────┬──────┘    └─────────────┘    └───────────┬───────────┘   │
│         │                                            │               │
│  ┌──────▼──────┐                                    ▼               │
│  │    Loki     │◄──────────────────────────── Alerts to Slack       │
│  │  (Logs)     │                                                     │
│  └─────────────┘                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                     COLLECTION & INGESTION LAYER                     │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐ │
│  │Node Exporter│  │kube-state-  │  │  Grafana    │  │  Traefik  │ │
│  │(Node/OS)    │  │metrics      │  │   Alloy     │  │  Gateway  │ │
│  │             │  │(K8s State)  │  │ (Log Agent) │  │ (Metrics) │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬─────┘ │
│         │                │                  │                │       │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐│
│  │   Worker    │  │   Master    │  │   Worker    │  │  Training   ││
│  │   Nodes     │  │   Node      │  │   Nodes     │  │     App     ││
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────────┐
│                       CONTROL PLANE (Talos Linux)                      │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Kubernetes API Server + kubelet                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Flannel CNI                               │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | Key Interactions |
|-----------|----------------|------------------|
| **kube-prometheus-stack** | Core metrics collection, storage, alerting | Scrapes all exporters; provides TSDB for Grafana; sends alerts to Alertmanager |
| **Traefik Gateway API** | Ingress controller and API gateway | Exposes metrics on `:8080/metrics`; routes traffic to apps; scraped by Prometheus via ServiceMonitor |
| **prometheus-adapter** | Exposes custom metrics for HPA | Queries Prometheus; serves Custom Metrics API; enables pod autoscaling |
| **Loki** | Log aggregation and storage | Receives logs from Alloy; queried by Grafana for log visualization |
| **Grafana Alloy** | Log collection agent (Promtail replacement) | Runs as DaemonSet on all nodes; tails container logs; ships to Loki |
| **Alertmanager** | Alert routing and notification | Receives alerts from Prometheus; groups/deduplicates; routes to Slack/email |
| **node-exporter** | Node hardware/OS metrics | DaemonSet providing CPU, memory, disk, network metrics per node |
| **kube-state-metrics** | Kubernetes object state | Deployment replicas, pod phases, node conditions as metrics |
| **Grafana** | Visualization dashboards | Queries Prometheus and Loki; pre-configured with K8s dashboards |

## Data Flow Architecture

### Metrics Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              METRICS PIPELINE                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                     │
│  │ Node         │    │ kube-state-  │    │ Traefik      │    ┌──────────────┐ │
│  │ Exporter     │    │ metrics      │    │ Metrics      │    │ Training App │ │
│  │ (9100)       │    │ (8080)       │    │ (8080)       │    │ (/metrics)    │ │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘    └──────┬───────┘ │
│         │                   │                   │                   │       │
│         └───────────────────┴───────────────────┴───────────────────┘       │
│                                     │                                       │
│                          ┌──────────▼──────────┐                           │
│                          │ Prometheus          │                           │
│                          │ (Scrape/Store)      │                           │
│                          └──────────┬──────────┘                           │
│                                     │                                       │
│              ┌──────────────────────┼──────────────────────┐                 │
│              │                      │                      │                 │
│     ┌────────▼───────┐   ┌──────────▼──────────┐   ┌──────▼──────┐        │
│     │ Grafana        │   │ Alertmanager        │   │ prometheus- │        │
│     │ (Visualize)    │   │ (Route Alerts)      │   │ adapter     │        │
│     └────────────────┘   └─────────────────────┘   └──────┬──────┘        │
│                                                           │                │
│                                                  ┌────────▼──────┐        │
│                                                  │ HPA Controller│        │
│                                                  │ (Scale Pods)  │        │
│                                                  └───────────────┘        │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Logs Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                               LOGS PIPELINE                                    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────┐  │
│  │ Container       │───►│ Grafana Alloy   │───►│ Loki                    │  │
│  │ stdout/stderr   │    │ (DaemonSet)     │    │ (Log Store)             │  │
│  └─────────────────┘    │                 │    └───────────┬─────────────┘  │
│                         │ - Discovers     │                │               │
│                         │   pods via      │                │               │
│                         │   K8s API       │                │               │
│                         │ - Tails logs    │                │               │
│                         │ - Adds labels   │                │               │
│                         └─────────────────┘                │               │
│                                                            │               │
│                                          ┌─────────────────▼─────────────┐  │
│                                          │ Grafana (Log Visualization) │  │
│                                          └───────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Alert Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                             ALERT PIPELINE                                     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                                │
│  ┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────────┐   │
│  │ PrometheusRule  │───►│ Prometheus       │───►│ Alertmanager            │   │
│  │ (Alert Rules)   │    │ (Evaluate)       │    │                         │   │
│  └─────────────────┘    └────────┬─────────┘    │ - Deduplicate           │   │
│                                    │             │ - Group by labels       │   │
│                           ┌────────▼────────┐    │ - Route to receivers    │   │
│                           │ Alert Triggered│   │                         │   │
│                           │ (firing)       │   └───────────┬─────────────┘   │
│                           └────────┬────────┘               │                 │
│                                    │                       │                 │
│         ┌──────────────────────────┼───────────────────────┼─────────────────┤
│         │                          │                       │                 │
│  ┌──────▼──────┐         ┌─────────▼─────────┐    ┌──────▼──────┐         │
│  │ Slack       │         │ PagerDuty         │    │ Email       │         │
│  │ (Critical)  │         │ (Page On-Call)    │    │ (Info)      │         │
│  └─────────────┘         └───────────────────┘    └─────────────┘         │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Build Order Dependencies

The components have sequential dependencies that determine the build order:

```
Phase 1: Foundation ───────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ kube-prometheus │──► Creates Prometheus Operator + CRDs
    │ -stack          │    (Required by all monitoring resources)
    └─────────────────┘

Phase 2: Gateway ────────────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ Traefik Gateway │──► Creates GatewayClass + provides ingress
    │ API             │    (Required for exposing applications)
    └─────────────────┘

Phase 3: Metrics API ────────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ prometheus-     │──► Creates Custom Metrics API
    │ adapter         │    (Requires Prometheus from Phase 1)
    └─────────────────┘

Phase 4: Logs ───────────────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ Loki + Alloy    │──► Log aggregation infrastructure
    │                 │    (Independent, can parallelize)
    └─────────────────┘

Phase 5: Monitoring ───────────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ Cluster Alerts  │──► PrometheusRules for infrastructure
    │ + ServiceMonitors│   (Requires Phase 1)
    └─────────────────┘

Phase 6: Application ────────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ Training App    │──► Observable workload for testing
    │ + Gateway Routes │   (Requires Phase 2)
    └─────────────────┘

Phase 7: App Monitoring ─────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ App ServiceMonitor│──► PrometheusRules for app metrics
    │ + App Alerts    │    (Requires Phases 1, 5, 6)
    └─────────────────┘

Phase 8: Visualization ──────────────────────────────────────────────────────►
    ┌─────────────────┐
    │ Custom Dashboards │──► Grafana dashboards for traffic analysis
    │ + GeoIP         │    (Requires Phases 4, 7)
    └─────────────────┘
```

### Critical Dependencies

| Component | Depends On | Why |
|-----------|------------|-----|
| ServiceMonitor | Prometheus Operator | CRD defined by operator |
| PrometheusRule | Prometheus Operator | CRD defined by operator |
| prometheus-adapter | Prometheus | Queries metrics from Prometheus |
| App ServiceMonitor | Training App + Prometheus | Needs app to exist first |
| Custom Dashboards | Loki + App metrics | Needs log and app data sources |

## Namespace Organization

Recommended namespace structure for the monitoring stack:

```
monitoring/                    # Core observability
├── kube-prometheus-stack      # Prometheus, Alertmanager, Grafana
├── prometheus-adapter         # Custom metrics API
└── loki-stack                 # Loki + Alloy (or separate)

traefik/                       # Ingress layer
traefik-hub/                   # If using Traefik Hub

apps/                          # Workload applications
└── training-app               # Observable workload
```

### Namespace Rationale

| Namespace | Purpose | Resources |
|-----------|---------|-----------|
| `monitoring` | Core observability infrastructure | Prometheus, Alertmanager, Grafana, prometheus-adapter |
| `loki` | Log aggregation (optional separate) | Loki, Alloy (if separate from monitoring) |
| `traefik` | Ingress/Gateway layer | Traefik controller, GatewayClass, Gateway resources |
| `training-app` | Observable workload | Application pods, Service, ServiceMonitor, HTTPRoute |

### RBAC Considerations

- Prometheus requires cluster-wide permissions for service discovery
- Alloy requires read access to pods/logs across namespaces
- Grafana typically runs with minimal permissions (read-only data sources)

## GitOps Directory Structure

Recommended structure for GitOps-ready deployment:

```
.
├── helmfile.yaml              # Root helmfile (or helmfile.d/)
├── environments/              # Environment-specific config
│   ├── local/
│   │   └── values.yaml        # Local cluster overrides
│   └── production/
│       └── values.yaml        # Production overrides
├── charts/                    # Helm values files
│   ├── kube-prometheus-stack/
│   │   ├── values.yaml        # Base configuration
│   │   └── grafana-dashboards/ # Custom dashboards
│   ├── traefik/
│   │   └── values.yaml        # Traefik Gateway config
│   ├── prometheus-adapter/
│   │   └── values.yaml        # Custom metrics config
│   └── loki/
│       └── values.yaml        # Log aggregation config
├── manifests/                 # Raw Kubernetes manifests
│   ├── monitoring/
│   │   ├── servicemonitor-traefik.yaml
│   │   ├── prometheusrules-cluster.yaml
│   │   └── prometheusrules-app.yaml
│   ├── traefik/
│   │   ├── gatewayclass.yaml
│   │   ├── gateway.yaml
│   │   └── middleware-*.yaml
│   └── training-app/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── servicemonitor.yaml
│       └── httproute.yaml
└── docs/                      # Documentation
    ├── architecture.md
    └── runbooks/
```

### Structure Rationale

| Directory | Purpose | GitOps Pattern |
|-----------|---------|----------------|
| `helmfile.yaml` | Declarative Helm deployments | Helmfile orchestrates releases |
| `environments/` | Environment-specific overrides | Supports multi-env GitOps |
| `charts/` | Helm values for each component | Separate config from charts |
| `manifests/` | Kubernetes native resources | ServiceMonitors, PrometheusRules, Routes |
| `docs/` | Operational documentation | Runbooks for alerts |

### ArgoCD/Flux Compatibility

For future GitOps adoption:

```yaml
# Example ArgoCD Application structure
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: helmfile.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
```

For Helmfile with ArgoCD, use the [helmfile plugin](https://github.com/travisgroth/argocd-helmfile).

## Architectural Patterns

### Pattern 1: Prometheus Operator Pattern

**What:** Use Prometheus Operator CRDs (ServiceMonitor, PrometheusRule) for declarative monitoring configuration instead of Prometheus config files.

**When to use:** All Kubernetes monitoring deployments. This is the modern standard.

**Trade-offs:**
- **Pros:** Native K8s integration, automatic discovery, no config reload needed
- **Cons:** Requires understanding of CRDs, operator dependency

**Example:**
```yaml
# ServiceMonitor for Traefik metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  labels:
    release: kube-prometheus-stack  # Must match Prometheus selector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
  endpoints:
    - port: metrics
      interval: 30s
```

### Pattern 2: Gateway API Over Ingress

**What:** Use Kubernetes Gateway API (HTTPRoute, Gateway) instead of traditional Ingress resources.

**When to use:** Modern deployments, multi-tenant routing, traffic splitting needs.

**Trade-offs:**
- **Pros:** More expressive routing, better traffic management, standard API
- **Cons:** Newer, fewer examples, controller-specific implementations

**Example:**
```yaml
# HTTPRoute for training-app
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: training-app
spec:
  parentRefs:
    - name: traefik-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: training-app
          port: 80
```

### Pattern 3: Alloy Over Promtail (2026+)

**What:** Use Grafana Alloy as the unified telemetry collector instead of separate Promtail.

**When to use:** All new deployments (Promtail is EOL March 2026).

**Trade-offs:**
- **Pros:** Unified agent (logs/metrics/traces), OpenTelemetry compatible, actively maintained
- **Cons:** Configuration syntax different from Promtail (HCL vs YAML)

**Example:**
```yaml
# Alloy config snippet for log collection
loki.source.kubernetes "pods" {
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki.monitoring.svc:3100/loki/api/v1/push"
  }
}
```

### Pattern 4: Recording Rules for Performance

**What:** Pre-compute expensive PromQL queries using recording rules.

**When to use:** Dashboard queries that aggregate histograms or complex joins.

**Trade-offs:**
- **Pros:** Instant query results, reduces Prometheus load
- **Cons:** Slight delay in data (evaluation interval), rule maintenance

**Example:**
```yaml
# Recording rule for app latency percentiles
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-recording-rules
spec:
  groups:
    - name: app-recording
      rules:
        - record: app:latency_p99:by_service
          expr: |
            histogram_quantile(0.99,
              sum by (service, le) (
                rate(traefik_service_request_duration_seconds_bucket[5m])
              )
            )
```

## Scalability Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| **Single node (local)** | Current setup; all components on one node; no HA |
| **Small cluster (3-5 nodes)** | Prometheus with persistence; Loki in SingleBinary mode; Alloy DaemonSet |
| **Medium cluster (10-50 nodes)** | Prometheus with Thanos sidecar for long-term storage; Loki distributed mode |
| **Large cluster (100+ nodes)** | Thanos/Cortex for metrics; Loki with object storage; multiple Prometheus shards |

### Scaling Priorities

1. **First bottleneck:** Prometheus memory (TSDB cardinality)
   - Solution: Increase retention, recording rules, or shard by namespace

2. **Second bottleneck:** Loki storage
   - Solution: Move from filesystem to object storage (S3/MinIO)

3. **Third bottleneck:** Grafana query performance
   - Solution: Recording rules, caching, query splitting

## Anti-Patterns

### Anti-Pattern 1: Missing ServiceMonitor Labels

**What people do:** Create ServiceMonitors without matching Prometheus `serviceMonitorSelector` labels.

**Why it's wrong:** Prometheus ignores them completely — no metrics collected.

**Do this instead:**
```yaml
# In values.yaml for kube-prometheus-stack
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false  # Pick up all
    serviceMonitorNamespaceSelector: {}           # All namespaces
    serviceMonitorSelector: {}                    # All labels
```

### Anti-Pattern 2: Direct Prometheus Scrape Configuration

**What people do:** Edit Prometheus ConfigMap directly with scrape_configs.

**Why it's wrong:** Changes lost on operator reconciliation; harder to manage.

**Do this instead:** Use ServiceMonitor/PodMonitor CRDs for all scrape targets.

### Anti-Pattern 3: Using Ingress Instead of Gateway API

**What people do:** Use traditional Ingress resources with Traefik.

**Why it's wrong:** Misses Gateway API features (traffic splitting, filters, extensibility); spec requirement specifies Gateway API.

**Do this instead:** Use HTTPRoute resources with Gateway API.

### Anti-Pattern 4: Promtail in 2026+

**What people do:** Continue using Promtail (end-of-life March 2026).

**Why it's wrong:** No security patches, no bug fixes, technical debt.

**Do this instead:** Migrate to Grafana Alloy immediately.

### Anti-Pattern 5: Alertmanager Without HA for Critical Alerts

**What people do:** Single replica Alertmanager in production.

**Why it's wrong:** Single point of failure for alerting pipeline.

**Do this instead:**
```yaml
# In values.yaml
alertmanager:
  alertmanagerSpec:
    replicas: 3  # Minimum for HA
```

## Integration Points

### External Services

| Service | Integration Pattern | Configuration |
|---------|---------------------|---------------|
| **Slack** | Incoming webhook URL | In Alertmanager config secret |
| **Prometheus Community Charts** | Helm repository | `https://prometheus-community.github.io/helm-charts` |
| **Traefik Labs Charts** | Helm repository | `https://traefik.github.io/charts` |
| **Grafana Charts** | Helm repository | `https://grafana.github.io/helm-charts` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Prometheus ↔ Exporters | HTTP scrape (pull) | Every 15-30s, requires network policies allow |
| Prometheus ↔ Alertmanager | HTTP POST (push) | Alertmanager receives alerts via internal service |
| Alloy ↔ Loki | HTTP POST (push) | gRPC or HTTP for log shipping |
| Grafana ↔ Prometheus | HTTP query | Configured as data source |
| Grafana ↔ Loki | HTTP query | Configured as data source |
| prometheus-adapter ↔ Prometheus | HTTP query | Internal cluster traffic |

## Sources

- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) — Official chart documentation
- [Prometheus Operator CRDs](https://prometheus-operator.dev/docs/user-guides/) — CRD reference
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/) — Alloy configuration (replaces Promtail)
- [Traefik Gateway API Provider](https://doc.traefik.io/traefik-hub/api-gateway/reference/routing/kubernetes/ref-routing-provider-gatewayapi) — Gateway API support
- [prometheus-adapter GitHub](https://github.com/kubernetes-sigs/prometheus-adapter) — Custom Metrics API implementation
- [Promtail EOL Notice](https://grafana.com/docs/loki/latest/send-data/promtail/) — Migration to Alloy required

---
*Architecture research for: Kubernetes Monitoring Environment*
*Researched: 2026-03-11*
