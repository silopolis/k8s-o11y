---
created: 2026-03-12T13:49:35.980Z
title: Add mise tasks for Phase 01-02 linting deployment and verification
area: tooling
files:
  - mise.toml
  - values/kube-prometheus-stack.yaml
  - values/prometheus.yaml
  - values/grafana.yaml
  - values/alertmanager.yaml
---

## Problem

Phase 01-02 created several configuration files that need linting, deployment, and verification tasks in mise. Currently, only basic tasks exist from Quick Task 1, but Phase 01-02 specific operations are missing convenient mise shortcuts.

**Files Created in Phase 01-02:**
- `values/kube-prometheus-stack.yaml` (86 lines) - Main chart configuration
- `values/prometheus.yaml` (70 lines) - Prometheus-specific config with storage/retention
- `values/grafana.yaml` (82 lines) - Grafana config with NodePort
- `values/alertmanager.yaml` (105 lines) - Alertmanager configuration

**Current Gap:**
No dedicated mise tasks for:
1. Linting Phase 01-02 values files (YAML validation)
2. Template validation for the full stack
3. Deployment of just the main kube-prometheus-stack (without CRDs)
4. Post-deployment verification of Phase 01-02 components
5. Checking specific Phase 01-02 configurations (retention, NodePort, etc.)

## Solution

Add Phase 01-02 specific mise tasks to `mise.toml`:

### 1. Lint Tasks for Phase 01-02 Values

```toml
[tasks.lint-values]
description = "Lint all Phase 01-02 values YAML files"
run = """
for file in values/kube-prometheus-stack.yaml values/prometheus.yaml values/grafana.yaml values/alertmanager.yaml; do
  echo "Linting $file..."
  yq eval '.' "$file" > /dev/null && echo "  ✓ Valid YAML"
done
"""

[tasks.lint-values-strict]
description = "Strict lint of Phase 01-02 values with schema validation"
run = """
echo "Validating kube-prometheus-stack values..."
helm lint prometheus-community/kube-prometheus-stack --values values/kube-prometheus-stack.yaml --values values/prometheus.yaml --values values/grafana.yaml --values values/alertmanager.yaml
"""
```

### 2. Template/Validation Tasks

```toml
[tasks.template-stack]
description = "Template kube-prometheus-stack without deploying"
run = "helmfile -f helmfile.yaml -l name=kube-prometheus-stack template > /tmp/stack-template.yaml && echo 'Template written to /tmp/stack-template.yaml'"

[tasks.validate-stack]
description = "Validate stack configuration (lint + template check)"
run = [
  "mise run lint-helmfile",
  "mise run lint-values",
  "mise run template-stack",
]
```

### 3. Deployment Tasks (Specific to Phase 01-02)

```toml
[tasks.deploy-stack]
description = "Deploy main kube-prometheus-stack (CRDs must exist)"
run = "helmfile -f helmfile.yaml -l name=kube-prometheus-stack sync"

[tasks.deploy-stack-diff]
description = "Show diff before deploying stack"
run = "helmfile -f helmfile.yaml -l name=kube-prometheus-stack diff"

[tasks.deploy-stack-apply]
description = "Apply stack with automatic confirmation"
run = "helmfile -f helmfile.yaml -l name=kube-prometheus-stack apply"
```

### 4. Verification Tasks (Post-Deployment)

```toml
[tasks.verify-stack]
description = "Verify Phase 01-02 deployment is healthy"
run = """
echo "=== Checking pods ==="
kubectl get pods -n monitoring
echo ""
echo "=== Checking services ==="
kubectl get svc -n monitoring
echo ""
echo "=== Checking prometheus targets ==="
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring &
sleep 2
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health == \"up\") | .labels.job' 2>/dev/null || echo "Targets check requires jq"
pkill -f "port-forward"
"""

[tasks.verify-retention]
description = "Verify Prometheus retention configuration"
run = "kubectl exec -it prometheus-kube-prometheus-stack-prometheus-0 -n monitoring -- cat /etc/prometheus/prometheus.yml | grep -A5 retention || echo 'Checking retention via API...'"

[tasks.verify-grafana]
description = "Verify Grafana NodePort is accessible"
run = """
echo "Grafana service:"
kubectl get svc kube-prometheus-stack-grafana -n monitoring
echo ""
echo "NodePort URL: http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}'):30030"
"""

[tasks.verify-prometheus]
description = "Verify Prometheus is collecting metrics"
run = """
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring &
sleep 2
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length' 2>/dev/null || echo "Query failed"
pkill -f "port-forward"
"""

[tasks.verify-alertmanager]
description = "Verify Alertmanager is operational"
run = """
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring &
sleep 2
curl -s http://localhost:9093/api/v2/status | jq '.cluster.status' 2>/dev/null || echo "Alertmanager check requires jq"
pkill -f "port-forward"
"""
```

### 5. Composite Task for Full Phase 01-02 Workflow

```toml
[tasks.phase-02-deploy]
description = "Complete Phase 01-02 deployment workflow: validate → deploy → verify"
run = [
  "mise run validate-stack",
  "mise run deploy-stack",
  "sleep 30",  # Wait for pods to start
  "mise run verify-stack",
]
```

## Prerequisites

- Quick Task 1 must be complete (basic mise tasks exist)
- Phase 01-02 values files must exist
- helmfile and kubectl must be available via mise

## Task List

- [ ] Add `lint-values` task for YAML validation
- [ ] Add `lint-values-strict` task for Helm lint
- [ ] Add `template-stack` task for dry-run templating
- [ ] Add `validate-stack` composite task
- [ ] Add `deploy-stack` task for main deployment
- [ ] Add `deploy-stack-diff` task for change preview
- [ ] Add `verify-stack` task for health checks
- [ ] Add `verify-retention` task for retention config check
- [ ] Add `verify-grafana` task for Grafana accessibility
- [ ] Add `verify-prometheus` task for metrics collection
- [ ] Add `verify-alertmanager` task for Alertmanager status
- [ ] Add `phase-02-deploy` composite task
- [ ] Test all tasks with `mise tasks`
- [ ] Document tasks in mise.toml comments

## Dependencies

This todo depends on:
- Quick Task 1 completion (basic mise infrastructure)
- Phase 01-02 completion (values files exist)

## Priority

**Medium** - These tasks will make Phase 01-02 operations more convenient and repeatable. Not blocking but improves workflow.

## References

- Phase 01-02 summary: `.planning/phases/01-core-observability-stack/01-02-SUMMARY.md`
- Quick Task 1: `.planning/quick/1-add-mise-tasks-for-phase-one-operations-/1-SUMMARY.md`
- Mise documentation: https://mise.jdx.dev/
