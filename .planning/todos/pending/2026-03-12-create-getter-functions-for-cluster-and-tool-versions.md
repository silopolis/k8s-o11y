---
created: 2026-03-12T15:06:44.841Z
title: Create getter functions for cluster and tool versions
area: tooling
files:
  - lib/talos.sh
  - lib/checks.sh
  - lib/kubernetes.sh (to be created)
---

## Problem

Scripts currently query tool versions and cluster state inline using subshells and kubectl commands. This leads to:
- Code duplication across multiple scripts
- Inconsistent error handling when commands fail
- Harder to test and mock in unit tests
- Verbose inline code that obscures business logic

Current inline queries found in codebase:
- Talos version: `talosctl version` (not currently captured)
- Kubernetes version: `kubectl version -o json | grep...` (inline in checks.sh)
- kubectl version: `kubectl version --client -o json | grep...` (inline in checks.sh)
- Helm version: `helm version --short` (inline in checks.sh)
- Helmfile version: `helmfile version --short` (inline in checks.sh)
- Node count: `kubectl get nodes --no-headers | wc -l` (inline in checks.sh)
- Control plane node count: Uses label selector (inline in multiple scripts)
- Worker node count: Not currently captured separately
- Node ready status: Complex jsonpath query (inline in checks.sh)
- CRD list: `kubectl get crd | grep...` (inline in checks.sh)

## Solution

Create a new library file `lib/kubernetes.sh` with getter functions for cluster queries, and extend `lib/talos.sh` for Talos-specific queries.

### Proposed Functions

**lib/talos.sh additions:**
```bash
get_talos_version()           # Returns Talos OS version
get_talosctl_version()        # Returns talosctl CLI version
```

**lib/kubernetes.sh (new file):**
```bash
get_kubectl_version()         # Returns kubectl client version
get_kubernetes_version()      # Returns Kubernetes server version
get_helm_version()            # Returns Helm version
get_helmfile_version()        # Returns Helmfile version
get_node_count()              # Returns total node count
get_control_plane_node_count() # Returns control plane node count
get_worker_node_count()       # Returns worker node count
get_nodes_not_ready()         # Returns count of not-ready nodes
get_prometheus_crd_count()    # Returns count of monitoring.coreos.com CRDs
get_prometheus_crds()         # Returns list of monitoring CRD names
```

### Implementation Notes

- Functions should return raw values (not echo with formatting)
- Functions should return empty string on failure (not error messages)
- Functions should use proper error handling with || true
- Use consistent naming pattern: get_<resource>_<attribute>()
- Document return values in function comments

### Migration Plan

1. Create lib/kubernetes.sh with all getter functions
2. Add tests for each function (optional)
3. Refactor lib/checks.sh to use getter functions
4. Refactor scripts/apply-talos-metrics-config.sh to use getter functions
5. Refactor scripts/verify-talos-metrics.sh to use getter functions
6. Eventually refactor scripts/preflight.sh to use getter functions

### Benefits

- Single source of truth for cluster queries
- Easier to mock for testing
- Consistent error handling
- More readable script logic
- Reusable across all deployment/validation scripts
