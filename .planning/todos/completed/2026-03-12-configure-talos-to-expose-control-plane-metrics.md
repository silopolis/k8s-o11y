---
created: 2026-03-12T13:32:27.292Z
title: Configure Talos to expose control plane metrics
area: tooling
files:
  - .talos/clusters/
  - docs/talos-metrics.md
---

## Problem

Control plane components (kube-controller-manager, kube-scheduler, kube-proxy) are showing as DOWN in Prometheus targets. To monitor these components, Talos must first be configured to expose their metrics endpoints.

**Current State:**
- kube-controller-manager DOWN
- kube-scheduler DOWN
- kube-proxy DOWN

**Root Cause:**
Talos Linux runs control plane components as host services (systemd/static pods) rather than as regular cluster pods. By default, Talos doesn't expose these metrics on the standard ports.

**Talos-Specific Challenge:**
Unlike standard Kubernetes distributions (kubeadm, kOps), Talos:
1. Doesn't expose controller-manager metrics on :10257 by default
2. Doesn't expose scheduler metrics on :10259 by default
3. Doesn't expose kube-proxy metrics on :10249 by default
4. Runs components as host services outside the cluster network

## Solution

Configure Talos machine configuration to enable control plane metrics exposure:

1. **Enable controller-manager metrics endpoint**
   Update Talos machine config to expose controller-manager metrics:
   ```yaml
   cluster:
     controllerManager:
       extraArgs:
         bind-address: 0.0.0.0  # Default is 127.0.0.1 (localhost only)
   ```

2. **Enable scheduler metrics endpoint**
   Update Talos machine config to expose scheduler metrics:
   ```yaml
   cluster:
     scheduler:
       extraArgs:
         bind-address: 0.0.0.0  # Default is 127.0.0.1 (localhost only)
   ```

3. **Enable kube-proxy metrics endpoint**
   Update Talos machine config to expose kube-proxy metrics:
   ```yaml
   cluster:
     proxy:
       extraArgs:
         metrics-bind-address: 0.0.0.0:10249  # Default is 127.0.0.1:10249
   ```

4. **Apply configuration to all control plane nodes**
   Use `talosctl edit mc` or patch command:
   ```bash
   # For each control plane node
   talosctl -n <node-ip> edit mc

   # Or apply via patch
   talosctl -n <node-ip> patch mc --patch @control-plane-metrics.yaml
   ```

## Documentation

Create docs/talos-metrics.md documenting:
- Default Talos metrics exposure behavior
- Required configuration changes
- How to verify metrics are exposed (curl from node)
- Security considerations (firewall rules, network policies)

## Verification

After configuration, verify metrics endpoints are accessible:
```bash
# From a node or pod with host network
kubectl run --rm -it test --image=curlimages/curl --restart=Never -- \
  curl -s http://<node-ip>:10257/metrics  # controller-manager
curl -s http://<node-ip>:10259/metrics  # scheduler
curl -s http://<node-ip>:10249/metrics  # kube-proxy
```

## Dependencies

- Requires access to Talos control plane nodes via talosctl
- May require cluster maintenance window (components restart)
- Should be done BEFORE configuring Prometheus scrape configs

## Priority

**Low** - Core cluster metrics (node-exporter, kube-state-metrics) are working. This enables additional control plane introspection but isn't blocking.

## References

- Talos documentation: Machine configuration reference
- Talos GitHub issues: Control plane metrics exposure
- Kubernetes documentation: Control plane component metrics
