# Kubernetes Monitoring Stack

Documentation covering the kube-prometheus-stack ecosystem, configuration approaches, and deployment structure for the Dawan infrastructure team.

Based on specifications from the Prometheus and Kubernetes training.


## Table of Contents

- [Section 2.1 — Découverte de la stack kube-prometheus-stack](#section-21--découverte-de-la-stack-kube-prometheus-stack)
- [Section 2.2 — Écosystème Prometheus sur Kubernetes](#section-22--écosystème-prometheus-sur-kubernetes)
- [Section 2.3 — Approches de configuration: Jsonnet vs CRDs](#section-23--approches-de-configuration-jsonnet-vs-crds)
- [Section 2.5 — Déploiement avec Helmfile](#section-25--déploiement-avec-helmfile)


## Section 2.1 — Découverte de la stack kube-prometheus-stack

The **kube-prometheus-stack** Helm chart is a comprehensive solution for deploying a complete monitoring stack on Kubernetes. It bundles multiple components together in a single release.

:::note
Chart source: <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
:::


### Components Included

The chart deploys the following components:

| Component | Type | Purpose |
| --------- | ---- | ------- |
| **Prometheus** | StatefulSet (via operator) | Core metrics collection and storage |
| **Alertmanager** | StatefulSet | Alert routing and notification management |
| **Grafana** | Deployment | Visualization and dashboards |
| **node_exporter** | DaemonSet | Node-level hardware and OS metrics |
| **kube-state-metrics** | Deployment | Kubernetes resource state metrics |

Additionally, the chart includes:

- Pre-configured dashboards for Kubernetes monitoring
- Pre-defined alerting rules for common Kubernetes scenarios
- Service discovery integration with Kubernetes API


### Key Configuration Values

The following values are critical for customizing the stack:

**Retention and Storage:**

```yaml
prometheus:
  prometheusSpec:
    retention: "7d"
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 10Gi
```

**Resource Allocation:**

```yaml
prometheus:
  prometheusSpec:
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 1000m
        memory: 4Gi
```

**Alertmanager Configuration:**

```yaml
alertmanager:
  config:
    global:
      smtp_smarthost: "smtp.example.com:587"
      smtp_from: "alertmanager@example.com"
    route:
      receiver: "default"
      routes:
        - match:
            severity: critical
          receiver: "pagerduty"
    receivers:
      - name: "default"
        email_configs:
          - to: "ops@example.com"
```


### Dashboard Provisioning

Grafana dashboards are automatically provisioned through **ConfigMaps** with a specific label:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-dashboard
  labels:
    grafana_dashboard: "1"
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "Custom Dashboard",
        ...
      }
    }
```

The Grafana sidecar container watches for ConfigMaps with the `grafana_dashboard` label and automatically imports them. This allows version-controlled dashboards to be deployed alongside the application code.


## Section 2.2 — Écosystème Prometheus sur Kubernetes

Two key components extend Prometheus functionality in Kubernetes environments: the Prometheus Operator and the Prometheus Adapter.


### Prometheus Operator

The **Prometheus Operator** automates the management of Prometheus instances and related resources in Kubernetes clusters.

**Role:**

The operator manages the complete lifecycle of Prometheus, Alertmanager, and ThanosRuler instances through Kubernetes Custom Resource Definitions (CRDs). It continuously watches ServiceMonitor, PodMonitor, and PrometheusRule resources to automatically configure scraping targets and alerting rules without requiring manual configuration reloads.

**Concrete Use Case:**

When deploying a new microservice with a ServiceMonitor, the operator automatically detects the resource and updates Prometheus configuration to begin scraping metrics within seconds, eliminating manual configuration management and reducing operational overhead.


### Prometheus Adapter

The **Prometheus Adapter** bridges the gap between Prometheus metrics and the Kubernetes metrics APIs.

**Role:**

The adapter exposes Prometheus metrics through the Kubernetes **custom metrics API**, enabling the Horizontal Pod Autoscaler (HPA) to scale deployments based on application-specific metrics collected by Prometheus, such as request rates, queue depths, or business KPIs.

**Concrete Use Case:**

A web application can automatically scale from 3 to 20 replicas when the request rate per pod exceeds 1000 requests per minute, as measured by Prometheus through Traefik metrics, rather than relying solely on basic CPU/memory metrics.


## Section 2.3 — Approches de configuration: Jsonnet vs CRDs

Two primary approaches exist for configuring Prometheus monitoring on Kubernetes: **Jsonnet** (used by kube-prometheus) and **CRDs** (used by the Prometheus Operator).


### Comparison Table

| Critère | Jsonnet (kube-prometheus) | CRDs (Opérateur Prometheus) |
| ------- | ------------------------- | --------------------------- |
| **Principe** | Configuration as code using Jsonnet templating language to generate Kubernetes manifests | Declarative resource definitions that the operator watches and reconciles |
| **Avantages** | Highly flexible and composable; can generate complex configurations with logic and abstractions; excellent for multi-environment setups | Native Kubernetes experience; automatic reconciliation; no build step required; integrated with kubectl and GitOps workflows |
| **Inconvénients** | Requires learning Jsonnet; additional build step to generate manifests; steeper learning curve for team members | Less flexible for complex templating; tied to operator capabilities; may require additional tooling for bulk operations |
| **Exemple d'utilisation** | Generating different monitoring configurations for dev/staging/prod from a single source with environment-specific overrides | Creating a ServiceMonitor resource to automatically discover and scrape metrics from a new application deployment |
| **Outillage nécessaire** | Jsonnet compiler (jsonnet/go-jsonnet), tanka for deployment, IDE support for Jsonnet syntax | kubectl, helm, or any Kubernetes management tool; Prometheus Operator deployed in cluster |

:::warning
Jsonnet is powerful but adds complexity. For teams already familiar with Kubernetes, CRDs provide a more straightforward path with better tooling integration.
:::


### CRD Descriptions

The Prometheus Operator introduces several Custom Resource Definitions for managing monitoring resources:

| CRD | Rôle |
| --- | ---- |
| **ServiceMonitor** | Defines how to scrape metrics from services by selecting Kubernetes Services and specifying endpoints to monitor. |
| **PodMonitor** | Similar to ServiceMonitor but directly selects Pods rather than Services, useful for applications not exposed via Services. |
| **PrometheusRule** | Contains recording rules and alerting rules that define how metrics should be aggregated and when alerts should fire. |
| **Alertmanager** | Configures Alertmanager instances, including clustering settings and persistent storage configuration. |
| **AlertmanagerConfig** | Defines routing trees and receiver configurations for alert notifications at namespace or global level. |
| **Probe** | Specifies targets for blackbox monitoring, allowing Prometheus to probe endpoints for availability and performance. |
| **ScrapeConfig** | Provides a way to define additional scrape configurations that are merged into the Prometheus configuration. |


## Section 2.5 — Déploiement avec Helmfile

Helmfile provides a declarative way to manage multiple Helm releases, making it ideal for deploying the complete monitoring stack.


### Expected Directory Structure

```text
k8s/
├── helmfile.yaml
└── values/
    ├── traefik.yaml
    └── kube-prometheus-stack.yaml
```


### helmfile.yaml

The main Helmfile orchestrates the deployment of both Traefik and the monitoring stack:

```yaml
repositories:
  - name: prometheus-community
    url: https://prometheus-community.github.io/helm-charts
  - name: traefik
    url: https://traefik.github.io/charts

releases:
  - name: traefik
    namespace: traefik
    createNamespace: true
    chart: traefik/traefik
    version: 34.x.x
    values:
      - values/traefik.yaml

  - name: kube-prometheus-stack
    namespace: monitoring
    createNamespace: true
    chart: prometheus-community/kube-prometheus-stack
    version: 72.x.x
    values:
      - values/kube-prometheus-stack.yaml
```

Deploy with:

```bash
helmfile sync
```


### values/traefik.yaml

Configuration for Traefik with Prometheus metrics and access logging:

```yaml
# Enable Prometheus metrics endpoint
metrics:
  prometheus:
    enabled: true
    service:
      enabled: true

# Access logs in JSON format for easier parsing
accessLog:
  enabled: true
  format: json
  fields:
    general:
      defaultMode: keep
    headers:
      defaultMode: drop

# Enable dashboard (optional, for debugging)
ingressRoute:
  dashboard:
    enabled: true
    annotations:
      traefik.ingress.kubernetes.io/router.middlewares: traefik-basic-auth@kubernetescrd
```


### values/kube-prometheus-stack.yaml

Configuration for the monitoring stack with lab-appropriate settings:

```yaml
# Prometheus retention and storage
prometheus:
  prometheusSpec:
    retention: "7d"
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
    resources:
      requests:
        cpu: 500m
        memory: 2Gi

# Alertmanager configuration
alertmanager:
  enabled: true
  config:
    global:
      smtp_smarthost: "localhost:25"
      smtp_from: "alertmanager@localhost"
    route:
      receiver: "default"
      group_by: ["alertname", "severity"]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
    receivers:
      - name: "default"
        email_configs:
          - to: "admin@example.com"
            send_resolved: true

# Disable components not accessible in lab environment
kubeEtcd:
  enabled: false

kubeScheduler:
  enabled: false

kubeProxy:
  enabled: false

# Enable Grafana with persistence
grafana:
  enabled: true
  persistence:
    enabled: true
    size: 5Gi

# Node exporter (enabled by default, ensures node-level metrics)
prometheus-node-exporter:
  enabled: true
```

:::note
The disabled components (etcd, scheduler, proxy) are typically not accessible in local Kubernetes environments like minikube, kind, or k3d. Enable them only in production clusters with proper RBAC access.
:::


## References

- kube-prometheus-stack Helm Chart: <https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack>
- Prometheus Operator: <https://github.com/prometheus-operator/prometheus-operator>
- Prometheus Adapter: <https://github.com/kubernetes-sigs/prometheus-adapter>
- Helmfile Documentation: <https://helmfile.readthedocs.io/>
- Traefik Helm Chart: <https://github.com/traefik/traefik-helm-chart>
