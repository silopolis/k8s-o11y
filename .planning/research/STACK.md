# Technology Stack

**Project:** Kubernetes Monitoring with Prometheus, Traefik Gateway API, and Loki
**Researched:** 2026-03-11
**Overall Confidence:** HIGH

## Recommended Stack

### Core Infrastructure

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| kube-prometheus-stack | 82.10.3 | Complete monitoring stack (Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics) | Standard CNCF-graduated stack; actively maintained with weekly releases; includes battle-tested dashboards and alerting rules; Prometheus Operator enables declarative monitoring configuration via ServiceMonitor CRDs |
| Traefik | 39.0.5 (Helm chart) | Gateway API controller for ingress/routing | First-class Gateway API v1.4.0 support with 100% conformance; superior to Ingress NGINX for new deployments; automatic CRD and RBAC management; active development with same-day Gateway API releases |
| Loki | 6.54.0 | Log aggregation and querying | Purpose-built for Kubernetes; labels-based indexing aligns with Prometheus conventions; Grafana-native integration; handles high-volume log ingestion efficiently |
| prometheus-adapter | 0.12.0 | Kubernetes Custom/External Metrics APIs | Enables Horizontal Pod Autoscaler (HPA) based on Prometheus metrics; required for application autoscaling on custom metrics; maintained by kubernetes-sigs |
| Gateway API CRDs | v1.4.0 | Kubernetes Gateway API standard resources | Vendor-neutral standard replacing Ingress; cross-namespace routing support; role-based governance; required foundation for Traefik Gateway provider |

### Deployment Orchestration

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Helmfile | 1.1.x | Declarative multi-chart deployment | GitOps-ready; handles chart dependencies and ordering; environment-specific value templating; generates static manifests for ArgoCD/Flux compatibility |
| Helm | 3.x | Package manager for Kubernetes | Industry standard; required by Helmfile; supports OCI registries and post-render hooks |

### Talos Linux Considerations

| Component | Configuration | Purpose |
|-----------|---------------|---------|
| Flannel CNI | Default | Compatible with kube-prometheus-stack and service discovery |
| Etcd metrics | Requires mTLS certs | Talos secures etcd with client certificates; must export certs from control plane nodes for Prometheus scraping |
| Node-exporter | HostNetwork | Required to access host metrics on Talos immutable filesystem |

## Version Compatibility Matrix

| Component A | Version | Compatible With | Notes |
|-------------|---------|-----------------|-------|
| kube-prometheus-stack 82.x | Prometheus 3.2.x, Grafana 11.x | Kubernetes 1.28-1.32 | Uses latest Prometheus Operator v0.80+ |
| Traefik Helm 39.x | Traefik Proxy 3.6.10+ | Kubernetes 1.29-1.32 | Requires Gateway API v1.4.0 CRDs |
| Loki 6.x | Grafana 11.x | Helm 3.x | Compatible with boltdb-shipper and TSDB index |
| prometheus-adapter 0.12.0 | Kubernetes 1.30 APIs | kube-prometheus-stack 82.x | Uses registry.k8s.io images |
| Gateway API v1.4.0 | Traefik 3.6+, Cilium 1.16+ | Kubernetes 1.28+ | Standard channel for production |

## Deployment Order

Helmfile should deploy in this sequence:

1. **Gateway API CRDs** (foundation)
   - Required by Traefik Gateway provider

2. **Traefik** (ingress controller)
   - Enables `kubernetesGateway` provider
   - Creates GatewayClass

3. **kube-prometheus-stack** (observability core)
   - Prometheus Operator and CRDs
   - Prometheus, Grafana, Alertmanager
   - node-exporter, kube-state-metrics

4. **prometheus-adapter** (metrics APIs)
   - Depends on Prometheus being available
   - Registers Custom/External Metrics APIs

5. **Loki** (log aggregation)
   - Can be deployed after core monitoring
   - Requires Promtail DaemonSet configuration

6. **Application dashboards** (consumer)
   - Depends on prometheus-adapter for HPA
   - Depends on Loki for log correlation

## Installation

### Helmfile Structure

```yaml
# helmfile.yaml
releases:
  - name: gateway-api-crds
    namespace: gateway-system
    chart: oci://ghcr.io/kubernetes-sigs/gateway-api/charts/gateway-helm
    version: v1.4.0

  - name: traefik
    namespace: traefik
    chart: traefik/traefik
    version: 39.0.5
    values:
      - values/traefik.yaml

  - name: kube-prometheus-stack
    namespace: monitoring
    chart: prometheus-community/kube-prometheus-stack
    version: 82.10.3
    values:
      - values/kube-prometheus-stack.yaml

  - name: prometheus-adapter
    namespace: monitoring
    chart: prometheus-community/prometheus-adapter
    version: 4.12.0
    values:
      - values/prometheus-adapter.yaml

  - name: loki
    namespace: monitoring
    chart: grafana/loki
    version: 6.54.0
    values:
      - values/loki.yaml
```

### Helm Repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

## Alternatives Considered

| Category | Recommended | Alternative | When to Use Alternative |
|----------|-------------|-------------|------------------------|
| Ingress Controller | Traefik Gateway API | Ingress NGINX | Legacy systems only; Ingress NGINX is deprecated and scheduled for archival March 2026 |
| Log Aggregation | Loki | Fluentd + Elasticsearch | When full-text search or complex log analytics required; higher resource overhead |
| Metrics Backend | Prometheus | VictoriaMetrics | When single-node Prometheus becomes bottleneck; drop-in replacement |
| Gateway API Controller | Traefik | Cilium Gateway API | When using Cilium CNI; eBPF-based data plane |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Ingress NGINX | Officially deprecated; security issues; architectural limitations | Traefik Gateway API |
| Traefik v2.x | End of life; no Gateway API support | Traefik v3.6+ |
| Loki < 6.x | Outdated index schemas; missing features | Loki 6.54.0 |
| prometheus-adapter < 0.12.0 | Older Kubernetes API support; security issues | prometheus-adapter 0.12.0 |
| kube-prometheus-stack < 70.x | Prometheus 2.x; outdated Operator | Latest 82.x |
| Manual Helm installs | No dependency management; drift-prone | Helmfile |

## Talos Linux Specific Recommendations

### Etcd Metrics Access

Talos secures etcd with mTLS. To scrape etcd metrics:

1. Export certificates from control plane:
   ```bash
   talosctl -n <control-plane-node> read /etc/kubernetes/pki/etcd/ca.crt > etcd-ca.crt
   talosctl -n <control-plane-node> read /etc/kubernetes/pki/etcd/client.crt > etcd-client.crt
   talosctl -n <control-plane-node> read /etc/kubernetes/pki/etcd/client.key > etcd-client.key
   ```

2. Create Kubernetes secret for Prometheus:
   ```bash
   kubectl create secret generic etcd-certs -n monitoring \
     --from-file=ca.crt=etcd-ca.crt \
     --from-file=client.crt=etcd-client.crt \
     --from-file=client.key=etcd-client.key
   ```

3. Configure kube-prometheus-stack values:
   ```yaml
   prometheus:
     prometheusSpec:
       secrets:
         - etcd-certs
   kubeEtcd:
     serviceMonitor:
       scheme: https
       insecureSkipVerify: false
       caFile: /etc/prometheus/secrets/etcd-certs/ca.crt
       certFile: /etc/prometheus/secrets/etcd-certs/client.crt
       keyFile: /etc/prometheus/secrets/etcd-certs/client.key
   ```

### Security Considerations

| Aspect | Recommendation | Rationale |
|--------|----------------|-----------|
| Pod Security | Use `restricted` Pod Security Standard | Talos defaults to secure posture |
| Host Access | node-exporter requires hostNetwork | Required for host-level metrics |
| RBAC | Enable `prometheusSpec.enforcedNamespaceLabel` | Prevents cross-namespace metric access |
| Network Policies | Enable Cilium/Flannel policies | Defense in depth on Talos |

## Confidence Levels

| Recommendation | Confidence | Evidence |
|----------------|------------|----------|
| kube-prometheus-stack 82.10.3 | HIGH | Official GitHub releases verified March 10, 2026 |
| Traefik 39.0.5 | HIGH | Official Helm chart releases verified March 9, 2026; Gateway API v1.4.0 conformance docs |
| Loki 6.54.0 | HIGH | Official Grafana Helm releases verified March 10, 2026 |
| prometheus-adapter 0.12.0 | HIGH | kubernetes-sigs releases page verified; stable since May 2024 |
| Helmfile 1.1 | HIGH | Official docs and helmfile/helmfile repository |
| Talos etcd configuration | MEDIUM | Community documentation; specific Talos version may vary |

## Sources

- https://github.com/prometheus-community/helm-charts/releases/tag/kube-prometheus-stack-82.10.3 (verified March 10, 2026)
- https://github.com/traefik/traefik-helm-chart/releases/tag/v39.0.5 (verified March 9, 2026)
- https://github.com/grafana/helm-charts/releases/tag/helm-loki-6.54.0 (verified March 10, 2026)
- https://github.com/kubernetes-sigs/prometheus-adapter/releases/tag/v0.12.0 (verified May 17, 2024)
- https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-gateway (Gateway API v1.4.0 support)
- https://oneuptime.com/blog/post/2026-03-03-deploy-kube-prometheus-stack-on-talos-linux/view (Talos Linux best practices)
- https://helmfile.readthedocs.io/en/stable/ (Helmfile documentation)

---
*Stack research for: Kubernetes Monitoring with Prometheus, Traefik Gateway API, and Loki*
*Researched: 2026-03-11*
