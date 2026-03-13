---
created: 2026-03-12T10:30:00Z
title: Update monitoring stack to scrape Talos control plane metrics
area: tooling
files:
  - values/prometheus.yaml
  - values/kube-prometheus-stack.yaml
---

## Problem

Once Talos is configured to expose control plane metrics (see related todo: "Configure Talos to expose control plane metrics"), the kube-prometheus-stack needs to be updated to scrape these metrics from the node IPs.

**Current State (After Talos Configuration):**
- kube-controller-manager metrics exposed on node port 10257
- kube-scheduler metrics exposed on node port 10259
- kube-proxy metrics exposed on node port 10249
- Prometheus still showing these components as DOWN

**Root Cause:**
kube-prometheus-stack default ServiceMonitors assume control plane components run as pods with Kubernetes endpoints. On Talos:
1. Components run as host services, not pods
2. Metrics are on node IPs, not service endpoints
3. Default scrape configs use `kubernetes_sd_configs: role: endpoints` which won't find host services

## Solution

Update Prometheus configuration to scrape control plane components via node IPs:

1. **Disable default ServiceMonitors for control plane**
   In values/kube-prometheus-stack.yaml:
   ```yaml
   kubeControllerManager:
     enabled: false  # Disable default ServiceMonitor

   kubeScheduler:
     enabled: false  # Disable default ServiceMonitor

   kubeProxy:
     enabled: false  # Disable default ServiceMonitor
   ```

2. **Add custom scrape configs for Talos control plane**
   In values/prometheus.yaml, add additional scrape configs:
   ```yaml
   prometheus:
     prometheusSpec:
       additionalScrapeConfigs:
         # Controller Manager
         - job_name: 'talos-controller-manager'
           kubernetes_sd_configs:
             - role: node
           relabel_configs:
             - source_labels: [__address__]
               target_label: __param_target
             - source_labels: [__param_target]
               regex: ([^:]+):\d+
               replacement: ${1}:10257
               target_label: __address__
             - action: labelmap
               regex: __meta_kubernetes_node_label_(.+)
             - target_label: __metrics_path__
               replacement: /metrics
           scheme: https
           tls_config:
             insecure_skip_verify: true
           bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

         # Scheduler
         - job_name: 'talos-scheduler'
           kubernetes_sd_configs:
             - role: node
           relabel_configs:
             - source_labels: [__address__]
               target_label: __param_target
             - source_labels: [__param_target]
               regex: ([^:]+):\d+
               replacement: ${1}:10259
               target_label: __address__
             - action: labelmap
               regex: __meta_kubernetes_node_label_(.+)
             - target_label: __metrics_path__
               replacement: /metrics
           scheme: https
           tls_config:
             insecure_skip_verify: true
           bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token

         # Kube Proxy
         - job_name: 'talos-kube-proxy'
           kubernetes_sd_configs:
             - role: node
           relabel_configs:
             - source_labels: [__address__]
               target_label: __param_target
             - source_labels: [__param_target]
               regex: ([^:]+):\d+
               replacement: ${1}:10249
               target_label: __address__
             - action: labelmap
               regex: __meta_kubernetes_node_label_(.+)
             - target_label: __metrics_path__
               replacement: /metrics
           scheme: http  # kube-proxy uses HTTP
   ```

## Prerequisites

**MUST be completed first:**
- [Configure Talos to expose control plane metrics](2026-03-12-configure-talos-to-expose-control-plane-metrics.md)
  - Controller-manager exposing :10257
  - Scheduler exposing :10259
  - Kube-proxy exposing :10249

## Verification

After applying configuration:
```bash
# Check new scrape targets appear
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# Open http://localhost:9090/targets
# Look for talos-controller-manager, talos-scheduler, talos-kube-proxy jobs

# Verify metrics are being collected
kubectl exec -it prometheus-kube-prometheus-stack-prometheus-0 -n monitoring -- \
  wget -qO- http://localhost:9090/api/v1/targets | grep talos
```

## Deployment Steps

1. Verify Talos metrics endpoints are exposed (curl test from node)
2. Update values/prometheus.yaml with additionalScrapeConfigs
3. Update values/kube-prometheus-stack.yaml to disable defaults
4. Apply changes: `helmfile -f helmfile.yaml sync`
5. Verify targets in Prometheus UI

## Priority

**Low** - Depends on Talos configuration todo. Core metrics working without this.

## References

- kube-prometheus-stack documentation: additionalScrapeConfigs
- Prometheus documentation: relabel_configs and kubernetes_sd_configs
- Related todo: Configure Talos to expose control plane metrics
