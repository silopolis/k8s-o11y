# Domain Pitfalls: Kubernetes Monitoring with kube-prometheus-stack

**Domain:** Kubernetes observability stack (kube-prometheus-stack, Traefik Gateway API, prometheus-adapter, Loki)
**Context:** Talos Linux on Docker, single-node, 2-day deadline, Helmfile deployment
**Researched:** 2026-03-11
**Confidence:** HIGH (based on official docs, GitHub issues, and community reports)

---

## Critical Pitfalls

### Pitfall 1: ServiceMonitor Label Selector Mismatch

**What goes wrong:**
ServiceMonitors are created but Prometheus never discovers the targets. Metrics don't appear in Prometheus, dashboards show "No Data", and alerts never fire. This is the #1 support issue in prometheus-operator.

**Why it happens:**
The Prometheus CRD has a `serviceMonitorSelector` that filters which ServiceMonitors to scrape. By default, kube-prometheus-stack sets this to `release: kube-prometheus-stack`. If your ServiceMonitor doesn't have this exact label, it's ignored silently. No error is logged—the operator just skips it.

**How to avoid:**
```yaml
# ServiceMonitor MUST include this label
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: traefik
  namespace: traefik
  labels:
    release: kube-prometheus-stack  # REQUIRED - must match Helm release name
spec:
  endpoints:
    - port: metrics
      interval: 15s
  namespaceSelector:
    matchNames:
      - traefik
  selector:
    matchLabels:
      app.kubernetes.io/name: traefik
```

Always verify the selector matches your Helm release name:
```bash
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector -A 5
```

**Warning signs:**
- Prometheus UI shows no targets for your service
- `kubectl get servicemonitor -n traefik` exists but Prometheus UI → Status → Targets doesn't list it
- Grafana dashboards imported but show "No Data"
- Query `{__name__=~"traefik_.*"}` returns empty in Prometheus

**Phase to address:** Phase 2 (Traefik Gateway API setup)

---

### Pitfall 2: Prometheus Storage Misconfiguration on Single Node

**What goes wrong:**
Prometheus pod runs out of disk space, crashes, or enters `CrashLoopBackOff`. Data is lost on pod restart because storage wasn't actually persisted. In the worst case, the node runs out of disk and becomes unresponsive.

**Why it happens:**
On Talos Linux with Docker, there's no dynamic provisioner by default. PVCs stay in `Pending` state waiting for a StorageClass that doesn't exist. Even with persistence enabled, if the PVC isn't properly configured, Prometheus uses ephemeral storage which gets wiped on pod reschedule.

**How to avoid:**
```yaml
# values/kube-prometheus-stack.yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ""  # Use emptyDir if no SC available
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
    retention: "7d"
    retentionSize: "8GB"
```

For Talos Docker (no CSI), use `emptyDir` with retention limits:
```yaml
prometheus:
  prometheusSpec:
    storageSpec: {}
    retention: "2d"  # Short retention for local dev
    retentionSize: "2GB"
```

**Warning signs:**
- `kubectl get pvc -n monitoring` shows PVC in `Pending`
- `kubectl describe pvc prometheus-kube-prometheus-stack-prometheus-db` shows "no persistent volumes available"
- Prometheus pod events: `FailedMount`, `FailedScheduling`
- Prometheus log: `write to WAL: log samples: write /prometheus/wal: no space left on device`

**Phase to address:** Phase 1 (Core monitoring stack)

---

### Pitfall 3: Traefik Gateway API CRD Version Mismatch

**What goes wrong:**
Traefik fails to start or Gateway API resources (HTTPRoute, Gateway) aren't recognized. Helm install fails with `no matches for kind "Gateway" in version "gateway.networking.k8s.io/v1alpha2"`. Routes aren't created, applications unreachable.

**Why it happens:**
Gateway API CRDs must be installed BEFORE Traefik. The CRD versions evolve rapidly (v1alpha2 → v1beta1 → v1). Traefik chart version X requires Gateway API version Y. Mismatched versions cause immediate failure.

**How to avoid:**
```yaml
# helmfile.yaml - CRDs FIRST
releases:
  # Install Gateway API CRDs before Traefik
  - name: gateway-api-crds
    namespace: traefik
    chart: oci://ghcr.io/traefik-charts/gateway-api-crds
    version: 1.0.0
    
  - name: traefik
    namespace: traefik
    needs: [traefik/gateway-api-crds]  # Helmfile dependency
    chart: traefik/traefik
    version: 34.x.x
    values:
      - values/traefik.yaml
```

Verify CRDs exist before Traefik install:
```bash
kubectl get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
```

**Warning signs:**
- `helmfile sync` fails with CRD version errors
- Traefik pod in `CrashLoopBackOff`
- `kubectl get gateway` returns `error: the server doesn't have a resource type "gateway"`
- HTTPRoute resources created but Traefik doesn't serve traffic

**Phase to address:** Phase 2 (Traefik Gateway API controller)

---

### Pitfall 4: Prometheus-Adapter Custom Metrics API Registration Failure

**What goes wrong:**
HPA shows `<unknown>` for custom metrics. `kubectl top` works but `kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"` returns 404. Autoscaling never triggers based on application metrics.

**Why it happens:**
Prometheus-adapter requires APIService registration. The `seriesQuery` must match EXACTLY how metrics are stored in Prometheus, including label names. Common mistake: using `namespace` in config when metric has `kubernetes_namespace`, or missing `resources.overrides` mapping.

**How to avoid:**
```yaml
# values/prometheus-adapter.yaml
prometheus:
  url: http://prometheus-operated.monitoring.svc
  port: 9090

rules:
  default: false  # Don't use default rules - define explicit ones
  custom:
    - seriesQuery: 'http_requests_total{namespace!="",pod!=""}'  # Match Prometheus labels
      resources:
        overrides:
          namespace: {resource: "namespace"}  # Map metric label to K8s resource
          pod: {resource: "pod"}
      name:
        matches: "^(.*)_total"
        as: "${1}_per_second"
      metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[5m])) by (<<.GroupBy>>)'
```

Verify the adapter is serving:
```bash
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1" | jq .
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/default/pods/*/http_requests_per_second" | jq .
```

**Warning signs:**
- `kubectl describe hpa` shows `failed to get metric` errors
- HPA status shows `ScalingActive: False` with `FailedGetPodsMetric`
- Adapter logs show `no metrics found for query`
- Metric visible in Prometheus but `kubectl get --raw` returns empty

**Phase to address:** Phase 3 (prometheus-adapter HPA metrics)

---

### Pitfall 5: Loki Retention Policy Not Enforced Leading to Disk Exhaustion

**What goes wrong:**
Loki consumes all available disk space. Logs are never deleted. Loki crashes with `no space left on device`. Query performance degrades as index grows unbounded.

**Why it happens:**
Loki retention only works with specific storage engines (boltdb-shipper or tsdb) AND requires the compactor component. Many configs set `retention_period` in wrong location or without enabling `retention_enabled: true` in compactor config.

**How to avoid:**
```yaml
# values/loki.yaml
loki:
  limits_config:
    retention_period: 168h  # 7 days - this alone doesn't delete anything!
  
  compactor:
    retention_enabled: true  # REQUIRED for deletion to work
    retention_delete_delay: 2h
    compaction_interval: 10m
    working_directory: /var/loki/compactor
    shared_store: filesystem
  
  # For single node, use filesystem storage
  storage:
    type: filesystem
    filesystem:
      chunks_directory: /var/loki/chunks
      rules_directory: /var/loki/rules
```

Verify retention is active:
```bash
kubectl exec -it loki-0 -n monitoring -- cat /etc/loki/config/config.yaml | grep -A5 retention
```

**Warning signs:**
- `kubectl exec loki-0 -- du -sh /var/loki/chunks` grows continuously
- Loki log: `mkdir /data: read-only file system` or `no space left on device`
- Queries become slower over time
- `table_manager.retention_deletes_enabled` not found errors (wrong config location)

**Phase to address:** Phase 4 (Loki log aggregation)

---

### Pitfall 6: Helmfile Deployment Order Violations

**What goes wrong:**
Helmfile sync fails with dependency errors. Charts install in wrong order causing crash loops. Traefik installed before Gateway API CRDs. Prometheus-adapter before Prometheus. Apps before their monitoring configuration.

**Why it happens:**
Helmfile applies releases in parallel by default. Without explicit `needs` declarations, there's no guarantee Traefik CRDs exist before Traefik, or that Prometheus is ready before prometheus-adapter queries it.

**How to avoid:**
```yaml
# helmfile.yaml
releases:
  # Phase 1: Core infrastructure
  - name: traefik-crds
    namespace: traefik
    chart: traefik/gateway-api-crds
    
  - name: traefik
    namespace: traefik
    needs: [traefik/traefik-crds]
    
  # Phase 2: Monitoring stack
  - name: kube-prometheus-stack
    namespace: monitoring
    createNamespace: true
    
  - name: loki
    namespace: monitoring
    needs: [monitoring/kube-prometheus-stack]
    
  - name: prometheus-adapter
    namespace: monitoring
    needs: [monitoring/kube-prometheus-stack]  # Must have Prometheus first
    
  # Phase 3: Applications
  - name: training-app
    namespace: default
    needs: [traefik/traefik, monitoring/kube-prometheus-stack]
```

Use `helmfile template` to verify order:
```bash
helmfile template --debug | grep -E "(release|needs)"
```

**Warning signs:**
- `helmfile sync` fails with `Error: failed to install CRD... no matches for kind`
- Pods in `CrashLoopBackOff` because they can't reach dependencies
- `helmfile list` shows releases installed but apps not functional
- Race conditions where app starts before its ConfigMap/Secret exists

**Phase to address:** Phase 1-4 (All phases - deployment orchestration)

---

### Pitfall 7: Alertmanager Routing Configuration Mismatch

**What goes wrong:**
Alerts fire in Prometheus but notifications never sent. Slack/email receivers not working. All alerts route to default receiver despite matchers. Silence configs ignored.

**Why it happens:**
Alertmanager uses a routing tree. First matching route wins (unless `continue: true`). Common errors: incorrect matcher syntax (using `=` instead of `=~` for regex), wrong label names, or attempting to use `AlertmanagerConfig` CRDs without proper `alertmanagerConfigSelector`.

**How to avoid:**
```yaml
# values/kube-prometheus-stack.yaml
alertmanager:
  config:
    global:
      slack_api_url: '${SLACK_WEBHOOK_URL}'
    route:
      receiver: 'default'
      group_by: ['alertname', 'namespace', 'severity']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      routes:
        - match:
            severity: critical
          receiver: 'pagerduty'
          continue: true  # Allow matching additional routes
        - match_re:
            namespace: .*(prod|production).*
          receiver: 'slack-prod'
    receivers:
      - name: 'default'
        slack_configs:
          - channel: '#alerts'
      - name: 'pagerduty'
        pagerduty_configs:
          - service_key: '${PD_SERVICE_KEY}'
      - name: 'slack-prod'
        slack_configs:
          - channel: '#alerts-production'
            send_resolved: true
```

Test routing with amtool:
```bash
kubectl exec alertmanager-kube-prometheus-stack-0 -n monitoring -- amtool config routes test --config.file=/etc/alertmanager/config/alertmanager.yaml severity=critical namespace=production
```

**Warning signs:**
- Prometheus UI shows alerts firing (red) but no notifications received
- `kubectl logs alertmanager-0 -n monitoring` shows `no routes matched`
- All alerts go to default receiver regardless of labels
- Alertmanager UI shows alerts but receivers column is empty

**Phase to address:** Phase 5 (Alerting rules and routing)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `storageSpec: {}` (ephemeral) | Works immediately without storage class | Data loss on pod restart; retention ignored | **Day 1 only** - Must add PVC before any real use |
| Disable kubelet scraping (`kubelet.enabled: false`) | Fixes permission errors quickly | Missing container metrics; broken dashboards | **Never** - Fix RBAC instead |
| Short scrape intervals (5s) | Faster metrics appearing | High CPU, network, and memory usage | Only for critical demos; use 15-30s for production |
| `insecureSkipTLSVerify: true` | Works without cert management | Security vulnerability; MITM risk | **Local dev only** - Never in production |
| Use `hostPath` for Loki storage | Simplest storage option | Node affinity issues; data lost on node drain | Single-node dev only |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Traefik → Prometheus | Forgetting to enable metrics in Traefik values | `metrics.prometheus.enabled: true` and `metrics.prometheus.addEntrypointsLabels: true` |
| Prometheus → Grafana | Missing data source provisioning | Set `grafana.datasources.datasources.yaml.apiVersion: 1` with proper Prometheus URL |
| Gateway API → Traefik | Installing Traefik before Gateway CRDs | Always install `gateway-api-crds` chart first; verify with `kubectl get crd gateways.gateway.networking.k8s.io` |
| Loki → Alloy | Using deprecated Promtail config syntax | Alloy uses different config structure; use `loki.write` and `loki.source.kubernetes` components |
| prometheus-adapter → HPA | Wrong metric type in HPA spec | Custom metrics use `type: Pods`, external metrics use `type: External` - never mix them |
| ServiceMonitor → Prometheus | Wrong `release` label value | Must match `helm list` output name; check `kubectl get prometheus -o yaml` for exact selector |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| High cardinality metrics | Prometheus OOM; slow queries | Drop high-cardinality labels in `metricRelabelings` | > 100k series per metric |
| No metric retention limits | Disk fills up; compaction errors | Set `retentionSize` alongside `retention` | 2-3 days without limits |
| Scrape intervals too short | Prometheus CPU throttling; missed scrapes | Use 15-30s default; 60s for non-critical | > 500 targets with <15s interval |
| Loki without retention | Query timeouts; disk exhaustion | Enable compactor with `retention_enabled: true` | > 7 days of logs |
| Gateway API HTTPRoute without hostname filter | Traefik processes excessive routes | Always set `hostnames` in HTTPRoute | > 100 routes per gateway |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Exposing Prometheus/Alertmanager without auth | Anyone can view metrics, silence alerts | Enable basic auth in ingress; use `prometheus.prometheusSpec.enableAdminAPI: false` |
| Storing alertmanager secrets in plain YAML | Secrets committed to git; credential leaks | Use `alertmanager.configFromSecret` or external secret management |
| Loki with `allow_structured_metadata: true` uncontrolled | Arbitrary labels can explode cardinality | Set `limits_config.max_label_name_length` and `max_label_value_length` |
| Prometheus with `enableRemoteWriteReceiver: true` default | Unauthorized metric injection | Disable unless actively using remote write; add auth proxy if needed |
| Traefik Gateway API with permissive CORS | Cross-origin attacks from any domain | Explicitly set allowed origins in middleware; don't use `*` in production |

---

## Talos Linux Specific Pitfalls

| Issue | Why It Happens | Solution |
|-------|---------------|----------|
| kubelet metrics 401 Unauthorized | Talos secures kubelet with auth | Set `kubelet.enabled: false` in kube-prometheus-stack ONLY if using alternative node monitoring; otherwise configure proper TLS/cert access |
| etcd metrics inaccessible | etcd runs as system service, not pod | Configure `etcd.enabled: false` for Talos - etcd metrics not scrapable by standard means; use Talos API instead |
| Containerd socket path different | Talos uses non-standard paths | Don't mount containerd socket for cadvisor; use `kubelet.serviceMonitor.https: true` |
| Node-exporter network issues | Talos immutable filesystem | Use `nodeExporter.hostNetwork: false` and `hostPID: false` with standard ServiceMonitor |
| Control plane taints block operator | Default Talos taints | Either tolerate control plane taints or ensure worker nodes exist for operator pods |

---

## "Looks Done But Isn't" Checklist

- [ ] **Prometheus targets:** Check Status → Targets in Prometheus UI shows all expected endpoints UP (not just "found")
- [ ] **Grafana data source:** Test the Prometheus data source connection in Grafana UI (Configuration → Data Sources → Test)
- [ ] **ServiceMonitor labels:** Verify `release` label matches Helm release name exactly (case-sensitive)
- [ ] **Alertmanager routing:** Test alert routing with `amtool config routes test` before assuming alerts work
- [ ] **Loki retention:** Confirm compactor is running AND `retention_enabled: true` is set - having retention_period alone does nothing
- [ ] **HPA metrics:** Run `kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"` and verify your metrics appear
- [ ] **Gateway API route propagation:** Check `kubectl get httproute <name> -o yaml` shows `status.parents` with accepted condition
- [ ] **Persistent volumes:** Verify PVCs are `Bound` not `Pending` - single-node Docker often needs explicit `storageClassName: ""`
- [ ] **Helmfile dependencies:** Run `helmfile template --debug` to confirm `needs` relationships are respected
- [ ] **Prometheus-adapter query:** Verify the exact PromQL query from adapter config returns data in Prometheus UI

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| ServiceMonitor label mismatch | LOW | Add correct label: `kubectl label servicemonitor <name> release=kube-prometheus-stack -n <namespace>` |
| Prometheus storage full | MEDIUM | Scale down Prometheus, manually delete WAL files, adjust retention, restart. **Data loss risk.** |
| Gateway API CRD version mismatch | MEDIUM | Uninstall Traefik, install correct CRD version, reinstall Traefik. Check Traefik logs for exact version needed. |
| prometheus-adapter misconfiguration | LOW | Edit ConfigMap, delete adapter pod (it recreates). Verify with `kubectl get --raw` before testing HPA. |
| Loki disk exhaustion | HIGH | Scale down Loki, expand PVC (if possible), or move to object storage. May need to wipe and restart with proper retention. |
| Alertmanager routing broken | LOW | Use `amtool` to test routes, fix config in Helm values, `helmfile sync`. No data loss. |
| Helmfile order violation | LOW | Run `helmfile destroy` on failed release, then `helmfile sync` with corrected `needs` dependencies. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|------------|
| ServiceMonitor label mismatch | Phase 2 (Traefik) | `kubectl get servicemonitor -n traefik -l release=kube-prometheus-stack` returns result |
| Prometheus storage misconfiguration | Phase 1 (Core stack) | `kubectl get pvc -n monitoring` shows `Bound`, Prometheus pod has `/prometheus` mount |
| Gateway API CRD mismatch | Phase 2 (Traefik) | `kubectl get crd gateways.gateway.networking.k8s.io` exists before Traefik install |
| prometheus-adapter registration failure | Phase 3 (Adapter) | `kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1"` returns 200 with metrics list |
| Loki retention not enforced | Phase 4 (Loki) | Loki config shows `retention_enabled: true`, disk usage stable over 24h |
| Helmfile order violations | All phases | `helmfile template` shows correct dependency tree; `helmfile list` shows all releases deployed |
| Alertmanager routing broken | Phase 5 (Alerts) | `amtool config routes test` shows correct receiver for test alert labels |

---

## Sources

- prometheus-community/helm-charts GitHub Issues: #4869 (retention), #5862 (restart loop), #4463 (missing metrics), #6419 (datasource missing)
- prometheus-operator/prometheus-operator GitHub Issues: #6816 (label selectors), #7214 (matchExpression), #7228 (alertmanager config)
- traefik/traefik GitHub Issues: #10440 (CRD versions), #10939 (HTTPRoute updates), #11510 (middleware), #11426 (rule priority)
- grafana/alloy GitHub Issues: #2348 (duplicated targets), #1728 (log rotation), #3292 (scrape errors)
- siderolabs/talos GitHub Issues: #9770 (CPU throttling), #10204 (CPU pressure), #9980 (API access)
- Official Documentation: kube-prometheus-stack README, Traefik Gateway API docs, Prometheus Operator docs, Loki retention docs
- Community Resources: Multiple blog posts and migration guides from Promtail to Alloy (2025)

---

*Pitfalls research for: Kubernetes monitoring with kube-prometheus-stack, Traefik Gateway API, prometheus-adapter, and Loki*
*Context: Talos Linux on Docker, single-node, 2-day deadline, Helmfile deployment*
*Researched: 2026-03-11*
