---
created: 2026-03-12T18:14:13.467Z
title: Fix Talos control plane metrics exposition
area: tooling
files:
  - .planning/todos/completed/2026-03-12-configure-talos-to-expose-control-plane-metrics.md
  - .talos/clusters/
  - docs/talos-metrics.md
---

## Problem

The Talos control plane metrics configuration implemented in the completed todo (`.planning/todos/completed/2026-03-12-configure-talos-to-expose-control-plane-metrics.md`) has issues that need to be addressed.

**Original Implementation Issues:**

The previous implementation configured Talos machine config with extraArgs for:
- controller-manager bind-address: 0.0.0.0
- scheduler bind-address: 0.0.0.0
- kube-proxy metrics-bind-address: 0.0.0.0:10249

**Potential Problems:**
- The bind-address configuration may not be the correct approach for Talos
- Talos may require different configuration paths or additional settings
- Metrics endpoints may not be accessible from Prometheus even after configuration
- Security implications of binding to 0.0.0.0 on all interfaces
- Missing firewall or network policy considerations

**What Needs Fixing:**
- Verify the configuration syntax is correct for Talos Linux
- Ensure metrics endpoints are actually accessible after configuration
- Add proper security controls (firewall rules, network policies)
- Update documentation with correct implementation steps
- Test and validate the configuration works in the actual cluster

## Solution

Review and fix the Talos control plane metrics implementation:

1. **Review the completed todo implementation**
   - Check `.planning/todos/completed/2026-03-12-configure-talos-to-expose-control-plane-metrics.md`
   - Identify what was wrong or incomplete

2. **Research correct Talos approach**
   - Check Talos documentation for proper metrics exposure methods
   - Look for Talos-specific configuration options beyond extraArgs
   - Consider if Talos requires different port bindings

3. **Implement fixes**
   - Update machine configuration with correct settings
   - Apply to all control plane nodes
   - Verify metrics are accessible via curl from appropriate sources

4. **Update documentation**
   - Fix `docs/talos-metrics.md` with correct configuration
   - Document security considerations
   - Add verification steps

## References

- Original implementation: `.planning/todos/completed/2026-03-12-configure-talos-to-expose-control-plane-metrics.md`
- Related pending todo: `.planning/todos/pending/2026-03-12-configure-talos-control-plane-monitoring.md` (monitoring stack side)
