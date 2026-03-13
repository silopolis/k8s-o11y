# Talos Control Plane Metrics Configuration

This document explains how to configure Talos Linux to expose control plane component metrics for Prometheus scraping.

## Background

By default, Talos Linux does not expose control plane component metrics on the standard ports that Prometheus expects. Unlike standard Kubernetes distributions (kubeadm, kOps), Talos runs control plane components as host services and binds them to localhost only for security.

### Default Behavior

| Component | Default Bind Address | Standard Port | Status |
|-----------|---------------------|---------------|--------|
| kube-controller-manager | 127.0.0.1 | 10257 | Not exposed externally |
| kube-scheduler | 127.0.0.1 | 10259 | Not exposed externally |
| kube-proxy | 127.0.0.1 | 10249 | Not exposed externally |

This is why these components show as **DOWN** in Prometheus targets by default.

## Solution

Configure Talos machine configuration to bind metrics endpoints to all interfaces (0.0.0.0) instead of localhost only.

## Configuration

### Patch File

The configuration patch is located at:
```
config/talos/control-plane-metrics-patch.yaml
```

Contents:
```yaml
cluster:
  controllerManager:
    extraArgs:
      bind-address: 0.0.0.0
  scheduler:
    extraArgs:
      bind-address: 0.0.0.0
  proxy:
    extraArgs:
      metrics-bind-address: 0.0.0.0:10249
```

### Scripts Provided

1. **Backup Script**: `scripts/backup-talos-config.sh`
   - Creates backups of current machine configurations
   - Run before applying changes

2. **Apply Script**: `scripts/apply-talos-metrics-config.sh`
   - Performs rolling update across all control plane nodes
   - Backs up configs before starting
   - Waits for each node to be ready before proceeding
   - Verifies metrics endpoints are responding

3. **Verify Script**: `scripts/verify-talos-metrics.sh`
   - Tests all metrics endpoints on all control plane nodes
   - Can test specific node: `./scripts/verify-talos-metrics.sh <node-ip>`

## Usage

### Step 1: Backup Current Configuration

```bash
./scripts/backup-talos-config.sh
```

This creates backups in `.talos/backup-YYYYMMDD-HHMMSS/`.

### Step 2: Apply Configuration (Rolling Update)

```bash
./scripts/apply-talos-metrics-config.sh
```

The script will:
1. Check prerequisites (talosctl, kubectl access)
2. Backup current configurations
3. Apply patch to each control plane node sequentially
4. Wait for components to restart (45s per node)
5. Verify node is still healthy
6. Test metrics endpoints
7. Move to next node

**Time estimate**: ~5 minutes per node

### Step 3: Verify Configuration

```bash
# Verify all nodes
./scripts/verify-talos-metrics.sh

# Verify specific node
./scripts/verify-talos-metrics.sh 192.168.1.10
```

### Step 4: Manual Verification (Optional)

Test endpoints directly:

```bash
# From a pod with host network access
kubectl run test --rm -it --image=curlimages/curl --restart=Never \
  --overrides='{"spec":{"hostNetwork":true}}' -- \
  curl -s http://<node-ip>:10257/metrics | head
```

## Security Considerations

### Network Exposure

Binding metrics to `0.0.0.0` exposes them on all interfaces:

- **Risk**: Metrics endpoints are unauthenticated by default
- **Mitigation**:
  - Ensure firewall rules restrict access to cluster network only
  - Consider network policies to limit Prometheus pod access
  - Monitor access logs if available

### Talos Security Model

Talos intentionally binds to localhost by default. Before applying:

1. Review your network security posture
2. Ensure Prometheus has legitimate need for these metrics
3. Document the configuration change for security audits

## Troubleshooting

### Node Not Ready After Patch

If a node doesn't become Ready after 120 seconds:

```bash
# Check node status
kubectl describe node <node-name>

# Check Talos logs
talosctl -n <node-ip> logs

# Rollback if needed
talosctl -n <node-ip> apply-config -f .talos/backup-<timestamp>/<node-ip>-mc.yaml
```

### Metrics Endpoint Not Responding

1. Verify patch was applied:
   ```bash
   talosctl -n <node-ip> get machineconfig -o yaml | grep bind-address
   ```

2. Check if component restarted:
   ```bash
   kubectl get pods -n kube-system | grep <component>
   ```

3. Test from node directly:
   ```bash
   talosctl -n <node-ip> dashboard  # Check component health
   ```

### Rollback Procedure

If you need to revert the changes:

```bash
# Find your backup
ls -la .talos/backup-*/

# Apply previous config to a node
talosctl -n <node-ip> apply-config -f .talos/backup-<timestamp>/<node-ip>-mc.yaml

# Repeat for each node
```

## Next Steps

After configuring Talos:

1. **Configure Prometheus scrape configs** to discover and scrape these endpoints
2. **Import Grafana dashboards** for control plane components
3. **Set up alerts** for control plane health

See related todo: `Update monitoring stack to scrape Talos control plane metrics`

## References

- [Talos Machine Configuration](https://www.talos.dev/v1.9/reference/configuration/)
- [Kubernetes Control Plane Metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
- [Prometheus Kubernetes SD](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config)
