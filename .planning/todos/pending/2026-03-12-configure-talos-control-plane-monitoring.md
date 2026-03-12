---
created: 2026-03-12T10:30:00Z
title: Configure Talos control plane monitoring for kube-prometheus-stack
area: tooling
files:
  - values/prometheus.yaml
  - values/kube-prometheus-stack.yaml
---

## Problem

Control plane components (kube-controller-manager, kube-scheduler, kube-proxy) are showing as DOWN in Prometheus targets:

**Current State:**
- kube-controller-manager DOWN
- kube-scheduler DOWN
- kube-proxy DOWN

**Root Cause:**
Talos Linux runs control plane components as host services (systemd/static pods) rather than as regular cluster pods. By default, kube-prometheus-stack's ServiceMonitors look for these components via Kubernetes service endpoints, but:

1. Talos doesn't expose these metrics on the default ports by default
2. The components aren't accessible via cluster networking
3. kube-prometheus-stack default scrape configs assume standard Kubernetes deployment

**Prometheus Discovery Log:**
```
msg="Using pod service account via in-cluster config" 
component="discovery manager scrape" 
discovery=kubernetes 
config=serviceMonitor/monitoring/kube-prometheus-stack-kube-scheduler/0
```

The ServiceMonitor exists but endpoints aren't accessible.

## Solution

To monitor Talos control plane components, need to:

1. **Configure Talos to expose metrics**
   - Enable metrics endpoints in Talos machine config
   - Or use node-exporter host network to reach host ports

2. **Update Prometheus scrape configuration**
   Add additional scrape configs to reach control plane via node IPs:
   ```yaml
   prometheus:
     prometheusSpec:
       additionalScrapeConfigs:
         - job_name: 'kubernetes-controller-manager'
           kubernetes_sd_configs:
             - role: node
           relabel_configs:
             - source_labels: [__address__]
               target_label: __param_target
             - target_label: __address__
               replacement: kubernetes.default.svc:443
             - source_labels: [__meta_kubernetes_node_name]
               target_label: instance
           scheme: https
           tls_config:
             ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
           bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
   ```

3. **Alternative: Use Talos-specific scrape endpoints**
   Talos may expose aggregated metrics via its own endpoints

## References

- kube-prometheus-stack issue: Control plane scraping on non-kubeadm clusters
- Talos documentation: Machine configuration for metrics exposure
- Prometheus configuration: Additional scrape configs for static targets

## Priority

**Low** - Core metrics (node-exporter, kube-state-metrics) are working. Control plane monitoring is supplemental for Phase 1.

## Workaround

For now, document that control plane metrics are not available and track node-level metrics via node-exporter instead.
