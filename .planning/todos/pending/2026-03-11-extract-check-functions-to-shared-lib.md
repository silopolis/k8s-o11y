---
created: 2026-03-11T16:10:18.388Z
title: Extract check functions to shared lib
area: tooling
files:
  - scripts/preflight.sh:59-193
  - lib/
---

## Problem

The `scripts/preflight.sh` script has 10 inline checks (lines 59-193) that are currently embedded directly in the main script flow:

**Current checks (lines 59-193):**
1. **Check 1:** kubectl installed (lines 59-67)
2. **Check 2:** Kubernetes cluster connectivity (lines 69-82)
3. **Check 3:** Helm installed (lines 84-92)
4. **Check 4:** Helmfile installed (lines 94-103)
5. **Check 5:** Node health status (lines 105-121)
6. **Check 6:** Cluster resources/metrics API (lines 123-131)
7. **Check 7:** Monitoring namespace check (lines 133-147)
8. **Check 8:** Existing Prometheus CRDs (lines 149-162)
9. **Check 9:** Organization configuration (lines 164-172)
10. **Check 10:** Helmfile configuration (lines 174-193)

Each check is currently inline code that:
- Prints a header
- Runs validation logic
- Prints pass/fail/warn results
- Updates global ERRORS/WARNINGS counters

This structure makes the checks:
- Non-reusable (can't be used by other scripts)
- Hard to test individually
- Difficult to extend with new checks
- Mixes orchestration logic with check implementation

## Solution

Create a library of reusable check functions:

1. Create `lib/checks.sh` with individual check functions:
   ```bash
   check_kubectl_installed()
   check_cluster_connectivity()
   check_helm_installed()
   check_helmfile_installed()
   check_node_health()
   check_metrics_api()
   check_monitoring_namespace()
   check_prometheus_crds()
   check_org_config()
   check_helmfile_config()
   ```

2. Each function should:
   - Accept parameters for configuration
   - Return exit codes (0=pass, 1=fail, 2=warn)
   - Output results via shared print functions
   - Be independently testable

3. Update `scripts/preflight.sh` to:
   - Source the checks library
   - Define which checks to run in a list/array
   - Loop through checks and aggregate results
   - Keep the summary logic

This makes checks composable, testable, and reusable across different deployment/validation scripts.
