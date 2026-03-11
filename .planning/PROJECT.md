# Kubernetes Monitoring Environment

## What This Is

A production-ready Kubernetes monitoring stack deployment for infrastructure teams. Deploys kube-prometheus-stack (Prometheus, Alertmanager, Grafana) via Helmfile, with Traefik as Gateway API controller for ingress management. Includes advanced observability components (prometheus-adapter for HPA metrics, Loki for log aggregation) to enable cluster monitoring, service-level alerts, and traffic observability. Built on Talos Linux with Flannel CNI.

## Core Value

Enable infrastructure teams to monitor cluster health, service performance, and application traffic in real-time with automated alerting—providing visibility into both infrastructure and application layers before issues impact users.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Deploy kube-prometheus-stack (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics) via Helmfile
- [ ] Configure Traefik as Gateway API controller with Prometheus metrics enabled
- [ ] Deploy prometheus-adapter for custom metrics API (HPA support)
- [ ] Deploy Loki for log aggregation (access logs, application logs)
- [ ] Configure Alloy/Promtail for log collection
- [ ] Create ServiceMonitor for Traefik metrics collection
- [ ] Define PrometheusRules for cluster and service-level alerting
- [ ] Provision pre-configured Grafana dashboards for cluster monitoring
- [ ] Deploy observable training application (training-app) with Gateway API routes
- [ ] Create ServiceMonitor for training-app
- [ ] Define PrometheusRules for application health and traffic alerts
- [ ] Create custom Grafana dashboards for traffic analysis
- [ ] Implement GeoIP middleware for access log enrichment (optional)

### Out of Scope

- Federation with Prometheus instances (Part 1 — Docker Compose architecture is separate)
- Thanos/Cortex/Mimir for long-term storage (future milestone)
- Multi-cluster monitoring (single cluster focus for this iteration)
- Advanced authentication/SSO for Grafana (basic auth only)
- Custom exporter development (use standard exporters only)

## Context

**Infrastructure Environment:**
- Cluster: Talos Linux local cluster on Docker
- CNI: Flannel (default)
- Ingress/Gateway: Traefik with Gateway API support (not Ingress API)
- Deployment Tool: Helmfile for declarative Helm chart management

**Project Timeline:**
- Deadline: 2 days
- Mode: Quick implementation with GitOps-ready structure

**Build Order (Priority):**
1. Core monitoring stack (kube-prometheus-stack)
2. Traefik Gateway API controller
3. Prometheus-adapter (HPA metrics)
4. Loki + Alloy/Promtail (log aggregation)
5. Cluster and service monitoring/alerts
6. Training application + ServiceMonitor
7. Application-level alerts and dashboards
8. GeoIP enrichment (optional)

**GitOps Considerations:**
- Directory structure designed for future GitOps implementation (likely ArgoCD or Flux)
- All manifests stored as code
- Helmfile for declarative deployments
- Separate environments directory ready for staging/production

**Organization Context:**
- Organization name is configurable (not hardcoded)
- Documentation should be generic for any infrastructure team
- Use `{{ .Values.organization }}` pattern for Helm values where applicable

## Constraints

- **Timeline**: 2-day deadline — prioritize core functionality over polish
- **Tech Stack**: Talos Linux + Flannel + Helmfile + kube-prometheus-stack
- **Architecture**: Gateway API (not Ingress API) for all routing
- **Scope**: Cluster/services monitoring first, application traffic second
- **Order**: prometheus-adapter and Loki must precede dashboards and GeoIP
- **Local Environment**: Talos on Docker limitations (single node, resource constraints)
- **GitOps Ready**: Structure must support future ArgoCD/Flux adoption

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Gateway API over Ingress | Modern standard, better traffic management, required by specs | — Pending |
| Helmfile over raw Helm | Declarative, reproducible, GitOps-friendly deployments | — Pending |
| Talos + Flannel | Specified environment, lightweight CNI suitable for local clusters | — Pending |
| prometheus-adapter before dashboards | Required for HPA metrics, foundational for scaling | — Pending |
| Loki before GeoIP | Log aggregation infrastructure needed before log analysis features | — Pending |
| Organization as parameter | Makes project reusable across different teams/contexts | — Pending |

---
*Last updated: 2025-03-11 after initial project definition*
