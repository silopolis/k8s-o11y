# Project Research Summary

**Project:** Kubernetes Monitoring with Prometheus, Traefik Gateway API, and Loki
**Domain:** Kubernetes observability infrastructure
**Researched:** 2026-03-11
**Confidence:** HIGH

## Executive Summary

This project implements a production-grade Kubernetes observability stack using the CNCF-standard kube-prometheus-stack, Traefik Gateway API, and Loki for a Talos Linux cluster. Research confirms this is the industry-standard approach adopted by 75% of organizations for Kubernetes monitoring, leveraging battle-tested Helm charts with active weekly releases.

The recommended approach is to use kube-prometheus-stack 82.10.3 as the foundation, providing Prometheus 3.2.x, Grafana 11.x, Alertmanager, node-exporter, and kube-state-metrics in a single deployment. This eliminates manual component integration and provides pre-configured dashboards and 50+ alert rules. Traefik 39.0.5 serves as the Gateway API controller with 100% v1.4.0 conformance, replacing deprecated Ingress NGINX. Loki 6.54.0 handles log aggregation, with Grafana Alloy replacing end-of-life Promtail. The prometheus-adapter enables Horizontal Pod Autoscaler (HPA) based on custom business metrics.

Key risks center on deployment order and configuration synchronization. The #1 support issue is ServiceMonitor label selector mismatches where Prometheus silently ignores targets without the correct `release` label. Storage misconfiguration causes data loss on single-node Docker environments. Gateway API CRD version mismatches prevent Traefik from starting. Helmfile deployment order violations create race conditions. These are all preventable with proper sequencing and validation.


## Key Findings

### Recommended Stack

The stack is built on well-maintained, actively developed components with verified version compatibility. Helmfile orchestrates the deployment sequence, ensuring dependencies are respected. All components use official Helm charts from verified repositories with recent (March 2026) releases.

**Core technologies:**
- **kube-prometheus-stack 82.10.3** — Complete observability foundation — Includes Prometheus Operator (CRD management), Prometheus Server, Alertmanager, Grafana, node-exporter, kube-state-metrics, 50+ pre-built alerts, and 10+ dashboards. This is the CNCF-graduated standard with weekly releases.
- **Traefik 39.0.5 (Helm)** — Gateway API ingress controller — 100% Gateway API v1.4.0 conformance, superior to deprecated Ingress NGINX, automatic CRD/RBAC management, maintained by Traefik Labs with same-day Gateway API releases.
- **Loki 6.54.0** — Log aggregation — Purpose-built for Kubernetes labels-based indexing (aligns with Prometheus), Grafana-native integration, efficient high-volume ingestion. Must use with Grafana Alloy (not Promtail, which is EOL March 2026).
- **prometheus-adapter 0.12.0** — Custom/External Metrics APIs — Enables HPA autoscaling on business metrics (queue depth, request rate), maintained by kubernetes-sigs, uses registry.k8s.io images.
- **Gateway API CRDs v1.4.0** — Standard routing resources — Vendor-neutral standard replacing Ingress, cross-namespace support, required foundation for Traefik Gateway provider.
- **Helmfile 1.1.x** — Declarative multi-chart deployment — GitOps-ready, handles dependencies and ordering, environment-specific templating, generates static manifests for ArgoCD/Flux compatibility.

**Deployment order (critical):**
1. Gateway API CRDs (foundation)
2. Traefik (ingress controller with Gateway provider)
3. kube-prometheus-stack (observability core with Operator)
4. prometheus-adapter (requires Prometheus available)
5. Loki (log aggregation, independent)
6. Application dashboards (consumer layer)


### Expected Features

The kube-prometheus-stack provides substantial functionality "free" — users expect these features to be available immediately after deployment.

**Must have (table stakes):**
- Cluster health metrics — Node/Pod status via node-exporter and kube-state-metrics (LOW complexity, included in stack)
- Resource utilization dashboards — CPU/memory/disk/network (LOW complexity, pre-built Grafana dashboards 315, 6417, 1860)
- Pod-level metrics — Container performance tracking (LOW complexity, cAdvisor built into kubelet)
- Alertmanager integration — Alert routing (MEDIUM complexity, core component)
- Pre-configured alerts — Kubernetes-specific warnings (LOW complexity, 50+ default rules for CrashLoopBackOff, OOMKilled, NodeNotReady)
- Service discovery — Auto-detect new pods/services (LOW complexity, Prometheus Operator via ServiceMonitors)
- Grafana data source — Single pane of glass (LOW complexity, auto-configured)
- Basic log aggregation — Container log access (MEDIUM complexity, Loki/Grafana integration)

**Should have (differentiators):**
- Custom metrics API (HPA) — Scale based on business metrics (MEDIUM complexity, prometheus-adapter enables queue depth, request rate scaling)
- Traefik Gateway monitoring — Ingress traffic visibility (LOW complexity, ServiceMonitor provides request rates, latency)
- Application-level ServiceMonitors — Beyond cluster to app metrics (LOW complexity, demonstrates ecosystem extensibility)
- Correlated logs + metrics — Troubleshooting workflow (MEDIUM complexity, Loki + Grafana log-to-metric correlation)
- Structured demo alerts — Practical learning examples (LOW complexity, focused CPU/memory/error rate alerts for training)

**Defer (v2+):**
- Distributed tracing (Jaeger/Tempo) — Adds 4-6 hours, requires app instrumentation; focus on metrics+logs correlation instead
- Thanos/long-term storage — Production scaling concern; use local Prometheus storage (15d default retention)
- Custom Grafana plugins — Visual polish over learning value; use standard panels
- Multi-cluster federation — Out of scope (Docker Compose federation removed); document concept only
- eBPF-based monitoring (Cilium, Pixie) — Tooling complexity; stick to ServiceMonitor patterns
- Advanced alert routing (PagerDuty/Slack) — Adds complexity; keep simple webhook/file output
- Persistent storage tuning — PVC configuration overhead; use default storage classes


### Architecture Approach

The architecture follows a layered observability pattern with three pillars: metrics, logs, and alerts. The Prometheus Operator pattern using ServiceMonitor and PrometheusRule CRDs is the modern standard — this eliminates manual Prometheus configuration files and enables GitOps workflows.

**Major components:**
1. **kube-prometheus-stack** — Core metrics collection, storage, alerting — Scrapes all exporters, provides TSDB for Grafana, sends alerts to Alertmanager. Includes Prometheus Operator for CRD management.
2. **Traefik Gateway API** — Ingress controller and API gateway — Exposes metrics on `:8080/metrics`, routes traffic to apps, scraped by Prometheus via ServiceMonitor. Uses HTTPRoute resources (not deprecated Ingress).
3. **prometheus-adapter** — Exposes custom metrics for HPA — Queries Prometheus, serves Custom Metrics API, enables pod autoscaling on business metrics.
4. **Loki + Grafana Alloy** — Log aggregation infrastructure — Alloy (Promtail replacement) runs as DaemonSet, tails container logs, ships to Loki. Loki receives logs, provides log visualization in Grafana.
5. **Alertmanager** — Alert routing and notification — Receives alerts from Prometheus, groups/deduplicates, routes to receivers (Slack, email).
6. **node-exporter** — Node hardware/OS metrics — DaemonSet providing CPU, memory, disk, network per node.
7. **kube-state-metrics** — Kubernetes object state — Deployment replicas, pod phases, node conditions as metrics.
8. **Grafana** — Visualization dashboards — Queries Prometheus and Loki, pre-configured with K8s dashboards.

**Namespace organization:**
- `monitoring` — Core observability (Prometheus, Alertmanager, Grafana, prometheus-adapter, Loki)
- `traefik` — Ingress/Gateway layer (Traefik controller, GatewayClass, Gateway, HTTPRoutes)
- `training-app` — Observable workload (Application pods, Service, ServiceMonitor)

**Key architectural patterns:**
- **Prometheus Operator Pattern** — Use ServiceMonitor/PrometheusRule CRDs instead of Prometheus config files. Enables native K8s integration, automatic discovery, no config reloads.
- **Gateway API Over Ingress** — Use HTTPRoute/Gateway resources instead of traditional Ingress. More expressive routing, traffic splitting, standard API (required by spec).
- **Alloy Over Promtail** — Grafana Alloy is the unified telemetry collector (Promtail is EOL March 2026). OpenTelemetry compatible, actively maintained.
- **Recording Rules for Performance** — Pre-compute expensive PromQL queries. Instant dashboard results, reduces Prometheus load.


### Critical Pitfalls

These are the most common and impactful issues encountered in production deployments. All are preventable with proper configuration.

1. **ServiceMonitor Label Selector Mismatch** — ServiceMonitors created but Prometheus never discovers targets; metrics don't appear, dashboards show "No Data", alerts never fire. **How to avoid:** ServiceMonitor MUST include `release: kube-prometheus-stack` label matching Helm release name. Verify with `kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector`. Address in Phase 2 (Traefik Gateway API setup).

2. **Prometheus Storage Misconfiguration on Single Node** — Prometheus runs out of disk, crashes, enters CrashLoopBackOff; data lost on pod restart. **How to avoid:** On Talos Docker (no CSI), use `emptyDir` with explicit retention limits: `retention: "2d"`, `retentionSize: "2GB"`. For PVC environments, specify `storageClassName`. Verify PVCs are `Bound` not `Pending`. Address in Phase 1 (Core monitoring stack).

3. **Traefik Gateway API CRD Version Mismatch** — Traefik fails to start or Gateway API resources aren't recognized; Helm install fails with version errors. **How to avoid:** Gateway API CRDs MUST be installed BEFORE Traefik. Install `gateway-api-crds` chart first; verify with `kubectl get crd gateways.gateway.networking.k8s.io`. Traefik 39.x requires Gateway API v1.4.0. Use Helmfile `needs` to enforce order. Address in Phase 2 (Traefik Gateway API controller).

4. **Prometheus-Adapter Custom Metrics API Registration Failure** — HPA shows `<unknown>` for custom metrics; autoscaling never triggers. **How to avoid:** `seriesQuery` must match EXACTLY how metrics are stored in Prometheus, including label names. Use `resources.overrides` to map metric labels to K8s resources (e.g., `namespace: {resource: "namespace"}`). Verify with `kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"`. Address in Phase 3 (prometheus-adapter HPA metrics).

5. **Loki Retention Policy Not Enforced Leading to Disk Exhaustion** — Loki consumes all disk space; logs never deleted; crashes with `no space left on device`. **How to avoid:** `retention_period` alone does nothing. MUST enable compactor with `retention_enabled: true`. Verify config shows both settings; check disk usage stability over 24h. Address in Phase 4 (Loki log aggregation).

6. **Helmfile Deployment Order Violations** — Helmfile sync fails with dependency errors; charts install in wrong order causing crash loops. **How to avoid:** Use explicit `needs` declarations in Helmfile. Traefik needs CRDs first; prometheus-adapter needs Prometheus; apps need both. Use `helmfile template --debug` to verify order. Address in all phases — deployment orchestration.

7. **Alertmanager Routing Configuration Mismatch** — Alerts fire in Prometheus but notifications never sent; all alerts route to default receiver. **How to avoid:** First matching route wins (unless `continue: true`). Use correct matcher syntax (`=~` for regex, not `=`). Test with `amtool config routes test`. Enable `alertmanagerConfigSelector` for CRD-based configs. Address in Phase 5 (Alerting rules and routing).


## Implications for Roadmap

Based on research, the following phase structure is recommended to respect dependencies, avoid pitfalls, and deliver incremental value.

### Phase 1: Foundation — Core Observability Stack
**Rationale:** Everything depends on Prometheus being available. The kube-prometheus-stack provides 80% of required functionality in a single deployment.
**Delivers:** Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics, 50+ pre-configured alerts, 10+ dashboards, Prometheus Operator CRDs.
**Addresses (FEATURES.md):** Cluster health metrics, resource utilization dashboards, pod-level metrics, pre-configured alerts, service discovery, Grafana data source.
**Uses (STACK.md):** kube-prometheus-stack 82.10.3 Helm chart.
**Avoids (PITFALLS.md):** Prometheus storage misconfiguration (configure emptyDir with retention for Talos Docker), control plane taints (tolerate or ensure worker nodes).
**Research flag:** LOW — Well-documented standard pattern, no additional research needed.

### Phase 2: Gateway — Traefik Gateway API
**Rationale:** Gateway is critical infrastructure; should be monitored. Must install Gateway API CRDs BEFORE Traefik to avoid version mismatch pitfalls.
**Delivers:** Traefik Gateway controller, GatewayClass, Gateway resource, HTTPRoute capability, Traefik ServiceMonitor for metrics.
**Addresses (FEATURES.md):** Traefik Gateway monitoring (ingress visibility).
**Uses (STACK.md):** Gateway API CRDs v1.4.0 (first!), Traefik 39.0.5 Helm chart.
**Implements (ARCHITECTURE.md):** Gateway API pattern (HTTPRoute resources), ServiceMonitor for Traefik metrics.
**Avoids (PITFALLS.md):** Gateway API CRD version mismatch (install CRDs first with Helmfile `needs`), ServiceMonitor label mismatch (include `release: kube-prometheus-stack` label).
**Research flag:** LOW — Standard pattern, but verify Traefik chart version compatibility if upgrading.

### Phase 3: Metrics API — Prometheus Adapter for HPA
**Rationale:** Enables autoscaling based on custom metrics. Requires Prometheus from Phase 1 to be collecting metrics.
**Delivers:** Custom Metrics API registration, External Metrics API, HPA capability on business metrics (request rate, queue depth).
**Addresses (FEATURES.md):** Custom metrics API (HPA) — key differentiator.
**Uses (STACK.md):** prometheus-adapter 0.12.0 Helm chart.
**Implements (ARCHITECTURE.md):** Prometheus-adapter queries Prometheus, serves metrics APIs.
**Avoids (PITFALLS.md):** Prometheus-adapter registration failure (verify `seriesQuery` matches Prometheus labels exactly, use `resources.overrides`, test with `kubectl get --raw`).
**Research flag:** MEDIUM — Custom metrics queries may need tuning for specific app metrics; have test queries ready.

### Phase 4: Logs — Loki and Alloy Log Aggregation
**Rationale:** Enhances troubleshooting with log-to-metric correlation. Independent of metrics pipeline but requires Grafana from Phase 1.
**Delivers:** Loki log store, Grafana Alloy DaemonSet (log collection), log visualization in Grafana, log-based alerting capability.
**Addresses (FEATURES.md):** Basic log aggregation, correlated logs + metrics troubleshooting workflow.
**Uses (STACK.md):** Loki 6.54.0, Grafana Alloy (not Promtail — EOL March 2026).
**Implements (ARCHITECTURE.md):** Alloy Over Promtail pattern (unified telemetry collector), logs data flow (Alloy → Loki → Grafana).
**Avoids (PITFALLS.md):** Loki retention not enforced (enable compactor with `retention_enabled: true` — `retention_period` alone does nothing), using Promtail instead of Alloy.
**Research flag:** LOW — Standard configuration, but verify Alloy config syntax differs from Promtail (HCL vs YAML).

### Phase 5: Application — Training Workload and Monitoring
**Rationale:** Demonstrates ecosystem extensibility; requires all prior phases for complete monitoring.
**Delivers:** Training application deployment, ServiceMonitor for app metrics, PrometheusRules for app alerts, HTTPRoute for ingress.
**Addresses (FEATURES.md):** Application-level ServiceMonitors, structured demo alerts, application monitoring example.
**Implements (ARCHITECTURE.md):** Application ServiceMonitor pattern, PrometheusRule CRDs, HTTPRoute resources.
**Avoids (PITFALLS.md):** ServiceMonitor label mismatch (verify `release` label matches Helm release), Helmfile order violations (app needs traefik and kube-prometheus-stack first).
**Research flag:** LOW — Standard patterns; focus on app instrumentation (/metrics endpoint).

### Phase 6: Visualization — Custom Dashboards and Refinement
**Rationale:** Polish and advanced use cases after core stack is stable. Lowest priority but adds learning value.
**Delivers:** Custom Grafana dashboards (traffic analysis), alert routing refinement, documentation/runbooks.
**Addresses (FEATURES.md):** Custom Grafana dashboards (if time permits).
**Implements (ARCHITECTURE.md):** Recording rules for dashboard performance, alert routing refinement.
**Avoids (PITFALLS.md):** Alertmanager routing mismatch (test with `amtool` before assuming alerts work).
**Research flag:** MEDIUM — Dashboard design may benefit from user workflow research; alert routing requires testing.


### Phase Ordering Rationale

The order is determined by strict technical dependencies discovered in architecture research:

1. **kube-prometheus-stack first** — Prometheus Operator CRDs are required by ALL monitoring resources (ServiceMonitors, PrometheusRules). Without the Operator, these CRDs don't exist.
2. **Traefik second** — Gateway API is critical infrastructure. Must install Gateway API CRDs before Traefik to avoid version mismatch. ServiceMonitor for Traefik requires Prometheus Operator from Phase 1.
3. **prometheus-adapter third** — Requires Prometheus metrics to be flowing. Queries Prometheus for custom metrics; needs it healthy first.
4. **Loki fourth** — Independent of metrics pipeline (can parallelize with Phase 3), but needs Grafana from Phase 1 for visualization. Log aggregation isn't strictly required for core monitoring.
5. **Application fifth** — Needs both Traefik (for HTTPRoute) and Prometheus Operator (for ServiceMonitor). Can't monitor what doesn't exist.
6. **Visualization sixth** — Needs Loki (for log correlation) and application metrics (from Phase 5). Polish after foundation is solid.

This order avoids the race conditions and dependency violations identified in PITFALLS.md. Helmfile `needs` declarations must enforce this sequence.


### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (prometheus-adapter):** Custom metrics API registration is notoriously finicky. The `seriesQuery` must match Prometheus storage exactly. Recommend researching exact PromQL queries for training app metrics before implementation. Test queries in Prometheus UI first, then map to adapter config.
- **Phase 6 (visualization):** Dashboard design benefits from understanding user troubleshooting workflows. While standard K8s dashboards are pre-built, custom traffic analysis dashboards may need research into Traefik metric structure and effective visualization patterns.

Phases with standard patterns (skip research-phase):
- **Phase 1 (kube-prometheus-stack):** Extremely well-documented, 75% of orgs use this stack. Official Helm chart README is comprehensive. Follow storage recommendations for Talos Docker.
- **Phase 2 (Traefik Gateway API):** Traefik has 100% Gateway API conformance; docs are excellent. Standard HTTPRoute patterns. Just verify CRD installation order.
- **Phase 4 (Loki):** Standard single-binary mode for small clusters. Main consideration is using Alloy (not Promtail) and enabling compactor retention.
- **Phase 5 (application):** Standard ServiceMonitor and Deployment patterns. Well-documented in Prometheus Operator docs.


## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All components verified with official releases from March 9-10, 2026. kube-prometheus-stack 82.10.3, Traefik 39.0.5, Loki 6.54.0, prometheus-adapter 0.12.0 all current. Weekly release cadence confirms active maintenance. Talos-specific configurations from community documentation (medium confidence for etcd). |
| Features | HIGH | Feature expectations verified against official kube-prometheus-stack README (confirmed included components) and 2025-2026 implementation guides. 75% market adoption confirms table stakes understanding. Anti-features list validated against 2-day timeline constraints. |
| Architecture | HIGH | Component responsibilities and data flow based on official Prometheus Operator, Traefik Gateway API, and Grafana Alloy documentation. Namespace structure follows community best practices. GitOps patterns established. Build order dependencies explicitly documented in component requirements. |
| Pitfalls | HIGH | All 7 critical pitfalls sourced from official GitHub issues, verified with documentation. ServiceMonitor label mismatch is #1 prometheus-operator support issue. Storage, CRD version, adapter registration, and retention pitfalls all have documented solutions. Recovery strategies from community reports. |

**Overall confidence:** HIGH

All four research areas draw from authoritative sources: official Helm chart releases verified March 2026, GitHub issue databases for common problems, and current (2025-2026) implementation guides. The stack is mature with extensive production usage. Main uncertainty is Talos Linux etcd metrics access (community docs only), but this is a monitoring enhancement, not a blocker.


### Gaps to Address

These areas need validation during implementation planning:

- **Talos Linux etcd metrics:** etcd runs as system service with mTLS. Community docs suggest disabling etcd monitoring for Talos (`etcd.enabled: false`) and using Talos API instead. Validate during Phase 1 if etcd metrics are required or if Talos metrics API provides equivalent visibility. **Mitigation:** Configure `etcd.enabled: false` initially; investigate Talos API metrics if needed.

- **Storage class for single-node Docker:** Talos on Docker has no dynamic provisioner. PVCs will stay `Pending` without explicit configuration. **Mitigation:** Use `emptyDir` with aggressive retention limits for local dev; document PVC requirements for production with CSI.

- **Custom metrics queries for training app:** prometheus-adapter requires exact PromQL queries matching metric labels. Without knowing the training app's exposed metrics, queries can't be pre-configured. **Mitigation:** During Phase 3 planning, inventory training app /metrics endpoint; test queries in Prometheus before configuring adapter.

- **Alertmanager routing test strategy:** While routing configuration is documented, testing requires actual alerts to fire. **Mitigation:** Plan alert firing tests during Phase 5 when training app can generate load/errors.

- **Alloy configuration syntax:** Alloy uses HCL (HashiCorp Configuration Language), not YAML like Promtail. Configuration structure differs. **Mitigation:** Reference official Alloy docs for `loki.source.kubernetes` and `loki.write` components; test config before deploying.


## Sources

### Primary (HIGH confidence)
- https://github.com/prometheus-community/helm-charts/releases/tag/kube-prometheus-stack-82.10.3 — Verified March 10, 2026 — Core monitoring stack components and versions
- https://github.com/traefik/traefik-helm-chart/releases/tag/v39.0.5 — Verified March 9, 2026 — Traefik Gateway API controller
- https://github.com/grafana/helm-charts/releases/tag/helm-loki-6.54.0 — Verified March 10, 2026 — Log aggregation stack
- https://github.com/kubernetes-sigs/prometheus-adapter/releases/tag/v0.12.0 — Verified May 17, 2024 — Custom metrics API implementation
- https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md — Official chart documentation, verified included components
- https://prometheus-operator.dev/docs/user-guides/ — Prometheus Operator CRD capabilities
- https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway — Gateway API v1.4.0 support
- https://grafana.com/docs/alloy/ — Alloy configuration (replaces Promtail)
- https://grafana.com/docs/loki/latest/send-data/promtail/ — Promtail EOL notice (March 2026)

### Secondary (MEDIUM confidence)
- "Deploy Complete kube-prometheus-stack in Production Environment" — SFEIR Institute, March 2026 — Confirms 75% of orgs use this stack
- "How to Use Prometheus Adapter for Custom Metrics API with HPA" — OneUptime, Feb 2026 — HPA integration patterns
- "Building a Production-Grade Observability Stack on Kubernetes" — Technology Geek, Jan 2026 — Three pillars approach
- https://oneuptime.com/blog/post/2026-03-03-deploy-kube-prometheus-stack-on-talos-linux/view — Talos Linux best practices
- https://helmfile.readthedocs.io/en/stable/ — Helmfile documentation
- https://www.spectrocloud.com/blog/choosing-the-right-kubernetes-monitoring-stack — Current stack recommendations
- https://www.metricfire.com/blog/10-essential-metrics-for-kubernetes-monitoring/ — Core monitoring requirements

### Tertiary (Contextual/Supporting)
- prometheus-community/helm-charts GitHub Issues: #4869, #5862, #4463, #6419 — Storage, restart loops, missing metrics
- prometheus-operator/prometheus-operator GitHub Issues: #6816, #7214, #7228 — Label selectors, alertmanager config
- traefik/traefik GitHub Issues: #10440, #10939, #11510, #11426 — CRD versions, HTTPRoute updates
- grafana/alloy GitHub Issues: #2348, #1728, #3292 — Log collection edge cases
- siderolabs/talos GitHub Issues: #9770, #10204, #9980 — Talos-specific monitoring considerations
- https://www.kloudfuse.com/blog/kubernetes-monitoring-tools-in-2025-our-top-10-picks — Market feature expectations

---
*Research completed: 2026-03-11*
*Ready for roadmap: yes*
