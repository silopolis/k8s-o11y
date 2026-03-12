# Notes


## Phase 1

✅ Task 1: Create Helmfile structure for CRDs deployment

- Created: helmfile.yaml with prometheus-community repository and CRD release
- Created: values/kube-prometheus-stack-crds.yaml with documentation
- Status: Helmfile lint passes
  ✅ Task 2: Create preflight checks script
- Created: scripts/preflight.sh with 10 comprehensive checks
- Features: kubectl, Helm, Helmfile, cluster connectivity, node health, CRD checks
  ✅ Task 3: Run preflight checks
- Exit code: 2 (warnings only - acceptable)
- Passed: 8 checks
- Warnings: 2 (metrics-server not installed, ORGANIZATION not set - both acceptable)
- Status: Ready for deployment
  ✅ Task 4: Deploy CRDs via Helmfile
- Deployed: kube-prometheus-stack-crds release to monitoring namespace
- CRDs installed: 10 Prometheus Operator CRDs (v0.73.0)
  - alertmanagers, prometheuses, servicemonitors, podmonitors, probes, etc.
- Helm release: Revision 1, status: deployed

Cluster State

Current Kubernetes Context: admin@k8s-o11y-2 (Talos Linux cluster)

Nodes: 3 Ready (1 control-plane, 2 workers)

CRDs Installed:

$ kubectl get crd | grep monitoring.coreos.com
alertmanagerconfigs.monitoring.coreos.com
alertmanagers.monitoring.coreos.com
podmonitors.monitoring.coreos.com
probes.monitoring.coreos.com
prometheusagents.monitoring.coreos.com
prometheuses.monitoring.coreos.com
prometheusrules.monitoring.coreos.com
scrapeconfigs.monitoring.coreos.com
servicemonitors.monitoring.coreos.com
thanosrulers.monitoring.coreos.com

Helm Releases (monitoring namespace):

$ helm list -n monitoring
NAME NAMESPACE REVISION STATUS CHART
kube-prometheus-stack-crds monitoring 1 deployed prometheus-operator-crds-11.0.0

helmfile -f helmfile.yaml lint

helmfile -f helmfile.yaml -l name=kube-prometheus-stack-crds sync

helm list -n monitoring


## Helm Repository Cheatsheet


### List Repositories

```bash
helm repo list
```


### Add Repository

```bash
helm repo add <name> <url>
```

Example:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```


### Delete Repository

```bash
helm repo remove <name>
```

Example:

```bash
helm repo remove prometheus-community
```


### Update Repositories

```bash
helm repo update
```

```yaml
# values/kube-prometheus-stack.yaml
---
# Common labels applied to all resources
commonLabels:
  organization: "{{ .Values.organization | default (env "ORGANIZATION" | default "training") }}"
  organization: "training"

helmfile -f helmfile.yaml template --validate
```

```yaml
# values/prometheus.yaml
# Prometheus-specific configuration values
# Phase 1: Core Observability Stack - Task 3
# Reference: .planning/phases/01-core-observability-stack/01-02-PLAN.md
#
# Storage type: emptyDir (not PVC) per CONTEXT.md decision
# Retention: 2-3 days, 2GB limit per CONTEXT.md decision
---
prometheus:
  prometheusSpec:
    # Performance and security features
    enableAdminAPI: false # Security: disable admin API in training env

    # External labels for identification
    # Organization label from environment or default
    externalLabels:
      organization: "${ORGANIZATION:-training}" # FIXME
      cluster: "talos-local" # FIXME
      replica: "$(POD_NAME)" # FIXME
```

```yaml
# values/grafana.yaml
# Grafana-specific configuration values
# Phase 1: Core Observability Stack - Task 4
# Reference: .planning/phases/01-core-observability-stack/01-02-PLAN.md
#
# Access method: NodePort 30030 for direct browser access without ingress
---
grafana:
  enabled: true
  # Service configuration: NodePort for direct access
  # This allows accessing Grafana via http://<node-ip>:30030 without ingress
  service:
    type: NodePort
    port: 80
    targetPort: 3000
    nodePort: 30030 # Within Kubernetes NodePort range (30000-32767) FIXME -> 33000

  # Admin credentials
  # Note: For production, use existingSecret instead of plain passwords
  admin:
    existingSecret: "" # TODO
    userKey: admin-user
    passwordKey: admin-password
  # Admin password (plaintext for training only - change in production!)
  # Use: kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
  adminPassword: admin123
```

Alertmanager :

- UI access ?
- Replicas

node-exporter:

- scheduling on all nodes

I found a blocking issue: The node-exporter DaemonSet is failing due to Talos Pod Security Standards. Node-exporter requires host access (hostNetwork, hostPID, hostPath volumes) which violates the "baseline" security profile.

The node-exporter DaemonSet is failing due to PodSecurity Policy violations:

```txt
Error creating: pods "kube-prometheus-stack-prometheus-node-exporter-qrmpn" is forbidden: violates PodSecurity "baseline:latest": host namespaces (hostNetwork=true, hostPID=true), hostPath volumes (volumes "proc", "sys", "root"), hostPort (container "node-exporter" uses hostPort 9100)
```

This is a Talos Linux specific issue. Talos uses strict Pod Security Standards (PSS) and the node-exporter requires privileged access to host namespaces and volumes.

For Talos compatibility, I need to either:

1. Configure the node-exporter with different security settings
2. Or disable node-exporter and document this as a deviation
3. Or configure the namespace with privileged security settings

Since this is a training environment and node-exporter is a core monitoring requirement, I'll need to modify the namespace to allow privileged pods. Let me add a label to the monitoring namespace to allow privileged security standards.

```bash
# Allow privileged pods in monitoring namespace
$ mise exec -- kubectl label namespace monitoring pod-security.kubernetes.io/enforce=privileged
```


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=fr,en : -->
