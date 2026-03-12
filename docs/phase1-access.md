# Phase 1 Access Guide

**Phase:** 1 - Core Observability Stack  
**Version:** 2026-03-12  
**Status:** Complete


## Overview

This document provides access information for the deployed monitoring stack in Phase 1. All services are running in the `monitoring` namespace.


## Quick Access

### Grafana (Primary Dashboard)

**URL:** `http://<node-ip>:30030`

**Steps to access:**

1. Get a node IP address:
   ```bash
   kubectl get nodes -o wide
   ```

2. Open browser to:
   ```
   http://<node-ip>:30030
   ```

**Default Credentials:**

* Username: `admin`
* Password: Retrieve with:
  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
  ```


## Service Access Methods

### Prometheus

**Port-forward method:**

```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
```

**URL:** http://localhost:9090

**Key Pages:**

| Page | Path | Description |
|------|------|-------------|
| Targets | `/targets` | Scrape targets status |
| Graph | `/graph` | Query metrics |
| Rules | `/rules` | Alert rules and recording rules |
| Status | `/status` | Runtime information |


### Alertmanager

**Port-forward method:**

```bash
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
```

**URL:** http://localhost:9093

**Features:**

* View active alerts
* Silenced alerts management
* Alert routing configuration (read-only via UI)


### Node Exporter (per node)

**Port-forward for specific node:**

```bash
# List node-exporter pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter

# Port-forward specific pod
kubectl port-forward pod/kube-prometheus-stack-prometheus-node-exporter-xxxxx 9100:9100 -n monitoring
```

**Metrics endpoint:** http://localhost:9100/metrics


## Useful Commands

### Check Pod Status

```bash
# All monitoring pods
kubectl get pods -n monitoring

# Specific component
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager
```

### View Logs

```bash
# Prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0

# Grafana logs
kubectl logs -n monitoring kube-prometheus-stack-grafana-xxxxx

# Alertmanager logs
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0

# Follow logs in real-time
kubectl logs -f -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

### List Dashboards

```bash
# Via ConfigMaps
kubectl get configmap -n monitoring -l grafana_dashboard=1

# Count dashboards
kubectl get configmap -n monitoring -l grafana_dashboard=1 | wc -l
```

### Check Services

```bash
# All monitoring services
kubectl get svc -n monitoring

# NodePort details
kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.spec.type}:{.spec.ports[0].nodePort}'
```

### Check PrometheusRules

```bash
# List all rules
kubectl get prometheusrules -n monitoring

# View specific rule
kubectl get prometheusrules -n monitoring kube-prometheus-stack-kubernetes-apps -o yaml
```


## Available Dashboards

Grafana comes pre-configured with 27 dashboards from kube-prometheus-stack:

### Cluster Overview

* **k8s-resources-cluster** - Cluster-wide resource usage
* **k8s-resources-multicluster** - Multi-cluster view
* **nodes** - Node-level metrics
* **node-cluster-rsrc-use** - Cluster resource usage

### Namespace & Workloads

* **k8s-resources-namespace** - Namespace resource usage
* **k8s-resources-workload** - Workload metrics
* **k8s-resources-workloads-namespace** - Workloads by namespace
* **namespace-by-pod** - Pod metrics by namespace
* **namespace-by-workload** - Workload metrics by namespace

### Pods & Containers

* **k8s-resources-pod** - Pod resource usage
* **pod-total** - Pod total metrics
* **persistentvolumesusage** - PV usage

### Core Components

* **apiserver** - Kubernetes API server metrics
* **controller-manager** - Controller manager metrics
* **scheduler** - Scheduler metrics
* **kubelet** - Kubelet metrics
* **kube-proxy** - Kube-proxy metrics
* **proxy** - General proxy metrics

### Node Metrics

* **nodes-aix** - AIX node metrics
* **nodes-darwin** - macOS node metrics
* **node-rsrc-use** - Node resource usage
* **node-exporter** - Node exporter full dashboard
* **node-network** - Network metrics

### Application & Services

* **k8s-coredns** - CoreDNS metrics
* **kubernetes-storage** - Storage metrics
* **workload-total** - Workload totals

### Stack Components

* **grafana-overview** - Grafana internal metrics
* **prometheus** - Prometheus self-monitoring
* **alertmanager-overview** - Alertmanager metrics


## Verification

Run the verification script to confirm all components are healthy:

```bash
bash scripts/verify-phase1.sh
```

Expected output: All checks should pass with no critical failures.


## Troubleshooting

### Cannot access Grafana

1. Verify NodePort is correctly set:
   ```bash
   kubectl get svc -n monitoring kube-prometheus-stack-grafana
   ```

2. Check pod status:
   ```bash
   kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana
   ```

3. View pod logs:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
   ```

### Prometheus targets are down

1. Check target status:
   ```bash
   kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
   # Then visit http://localhost:9090/targets
   ```

2. Common issues:
   * Network policies blocking access
   * Pods in CrashLoopBackOff
   * Service selector mismatch

### No metrics in Grafana

1. Verify Prometheus is collecting:
   ```bash
   kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
   # Query: up{}
   ```

2. Check datasource configuration in Grafana:
   * Configuration -> Data Sources -> Prometheus
   * URL should be: `http://kube-prometheus-stack-prometheus:9090`


## Next Steps

### Phase 2: Traefik Gateway API

Deploy Gateway API CRDs and Traefik controller with metrics:

```bash
# Plan Phase 2
/gsd-plan-phase 2

# Or execute if already planned
/gsd-execute-phase 2
```

**Phase 2 will provide:**

* Gateway API CRDs (v1.4.0)
* Traefik Gateway controller
* Traefik metrics on port 8080
* ServiceMonitor for automatic scraping
* HTTPRoute capabilities for Phase 4 app deployment


## Configuration Details

### Retention & Storage

* **Retention period:** 3 days
* **Storage size limit:** 2GB
* **Storage type:** emptyDir (single-node Talos)

### Disabled Components

* **etcd monitoring:** Disabled (Talos manages etcd with mTLS)
* **Components enabled:** kube-scheduler, kube-proxy, CoreDNS, node-exporter, kube-state-metrics

### NodePort Services

| Service | Type | Port | Purpose |
|---------|------|------|---------|
| kube-prometheus-stack-grafana | NodePort | 30030 | Grafana UI access |


## References

* [Prometheus Documentation](https://prometheus.io/docs/)
* [Grafana Documentation](https://grafana.com/docs/)
* [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
* [Phase 1 Context](.planning/phases/01-core-observability-stack/01-CONTEXT.md)
* [Phase 1 Roadmap](.planning/ROADMAP.md)


---

*Last updated: 2026-03-12*

*For issues or questions, refer to the troubleshooting section or check the verification script output.*
