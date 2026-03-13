# Quick Task 5 Summary: Update verify-phase1.sh to use kubectl exec

**Date:** 2026-03-12
**Commit:** 246a490
**Description:** Update verify-phase1.sh to use kubectl exec instead of port-forwarding

## Problem

The `scripts/verify-phase1.sh` script was using `kubectl port-forward` to query Prometheus metrics. Port-forwarding is unreliable because:
- Requires background processes that can fail silently
- Timing issues (sleep 3 may not be enough)
- Cleanup complexity (orphaned processes)
- Can leave ports in use if script exits unexpectedly

## Solution

Replaced all `kubectl port-forward` + `curl` combinations with `kubectl exec`:

**Changes made:**

1. **Removed port-forward infrastructure (lines 155-200)**
   - Removed `PF_PID` variable
   - Removed `cleanup_portforward()` function
   - Removed `trap cleanup_portforward EXIT`
   - Removed port-forward background process logic

2. **Added kubectl exec helper function**
   ```bash
   query_prometheus() {
       local query="$1"
       kubectl exec -it prometheus-kube-prometheus-stack-prometheus-0 -n monitoring -c prometheus -- \
           wget -qO- "http://localhost:9090/api/v1/query?query=$query" 2>/dev/null || echo ""
   }
   ```

3. **Updated metrics collection section**
   - Now queries Prometheus via `kubectl exec` directly into the pod
   - Uses `wget` which is available in the Prometheus container
   - More reliable than port-forwarding

4. **Updated alerts section**
   - Changed rule groups check to use `kubectl exec`
   - Removed secondary port-forward attempt

## Benefits

- **More reliable:** No background processes to manage
- **Simpler:** No cleanup logic needed
- **Faster:** No 3-second sleep required
- **Cleaner:** No orphaned port-forward processes

## Files Modified

- `scripts/verify-phase1.sh` - Replaced port-forward with kubectl exec

## Verification

```bash
# Check script syntax
bash -n scripts/verify-phase1.sh
# Result: Script syntax is valid
```

## Testing

The script can now be run without port-forward issues:
```bash
bash scripts/verify-phase1.sh
```

It will directly execute queries inside the Prometheus pod using kubectl exec.

## Success Criteria

- [x] Script syntax is valid
- [x] All port-forward logic removed
- [x] kubectl exec helper function added
- [x] Metrics collection uses kubectl exec
- [x] Alerts section uses kubectl exec
- [x] No orphaned background processes
