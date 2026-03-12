#!/usr/bin/env bash
#
# Verify Prometheus is collecting metrics with formatted table output
# Usage: ./scripts/verify-prometheus.sh

set -euo pipefail

echo "Getting operator pod..."
OPERATOR_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-prometheus-stack-prometheus-operator -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "=== Checking prometheus targets ==="
echo ""

# Get all targets
TARGETS_OUTPUT=$(kubectl exec -n monitoring "$OPERATOR_POD" -- wget -qO- http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/targets 2>/dev/null)

if [ -n "$TARGETS_OUTPUT" ]; then
  # Print header
  echo "Prometheus Targets:"
  echo ""
  printf "%-28s %-22s %-20s %-10s\n" "JOB" "INSTANCE" "NODE" "HEALTH"
  printf "%-28s %-22s %-20s %-10s\n" "----------------------------" "----------------------" "--------------------" "----------"
  
  # Process targets with jq
  echo "$TARGETS_OUTPUT" | jq -r '
    .data.activeTargets[] | 
    (.labels.job | sub("kube-prometheus-stack-"; "kps-")) + "|" + 
    .labels.instance + "|" + 
    (.discoveredLabels.__meta_kubernetes_endpoint_node_name // 
     .discoveredLabels.__meta_kubernetes_pod_node_name // "N/A") + "|" + 
    .health
  ' 2>/dev/null | while IFS='|' read -r job instance node health; do
    # Truncate long names
    if [ ${#job} -gt 26 ]; then job="${job:0:23}..."; fi
    if [ ${#node} -gt 18 ]; then node="${node:0:15}..."; fi
    
    # Status indicator
    if [ "$health" = "up" ]; then status="✓ up"; else status="✗ down"; fi
    
    printf "%-28s %-22s %-20s %s\n" "$job" "$instance" "$node" "$status"
  done
  
  echo ""
  
  # Count by health status
  UP_COUNT=$(echo "$TARGETS_OUTPUT" | jq '[.data.activeTargets[] | select(.health == "up")] | length' 2>/dev/null || echo "0")
  DOWN_COUNT=$(echo "$TARGETS_OUTPUT" | jq '[.data.activeTargets[] | select(.health == "down")] | length' 2>/dev/null || echo "0")
  TOTAL_COUNT=$(echo "$TARGETS_OUTPUT" | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
  
  echo "Summary: $UP_COUNT up, $DOWN_COUNT down, $TOTAL_COUNT total"
else
  echo "Failed to retrieve targets (requires jq and wget)"
fi

echo ""
echo "Checking metrics query endpoint..."
QUERY_RESULT=$(kubectl exec -n monitoring "$OPERATOR_POD" -- wget -qO- 'http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up' 2>/dev/null | jq '.data.result | length' 2>/dev/null || echo "0")
echo "Active metrics returned: $QUERY_RESULT"
