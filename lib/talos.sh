#!/usr/bin/env bash
#
# Shared Talos Linux utility functions
# Provides functions for interacting with Talos clusters and control plane nodes
#
# Usage: source "$(dirname "$0")/../lib/talos.sh"
# Dependencies: lib/output.sh must be sourced first

# Check prerequisites for Talos operations
# Usage: check_talos_prerequisites <patch_file_path>
check_talos_prerequisites() {
  local patch_file="${1:-}"

  header "Prerequisites Check"

  if ! command -v talosctl &>/dev/null; then
    fail "talosctl not found in PATH"
    exit 1
  fi
  pass "talosctl is available"

  if ! command -v kubectl &>/dev/null; then
    fail "kubectl not found in PATH"
    exit 1
  fi
  pass "kubectl is available"

  if [ -n "$patch_file" ] && [ ! -f "$patch_file" ]; then
    fail "Patch file not found: $patch_file"
    exit 1
  fi

  if [ -n "$patch_file" ]; then
    pass "Patch file exists: $patch_file"
  fi

  echo ""
}

# Get control plane node internal IPs
# Usage: get_control_plane_nodes
# Returns: Space-separated list of node IPs (empty string if none found)
get_control_plane_nodes() {
  kubectl get nodes -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo ""
}

# Verify a Talos control plane metrics endpoint by creating a test pod
# Usage: verify_talos_metrics_endpoint <node_ip> <port> <component_name>
# Example: verify_talos_metrics_endpoint "192.168.1.10" "10257" "controller-manager"
verify_talos_metrics_endpoint() {
  local node=$1
  local port=$2
  local component=$3

  # Create a test pod with hostNetwork to access the endpoint
  local pod_name
  pod_name="metrics-test-${port}-$(date +%s)"

  if kubectl run "$pod_name" --image=curlimages/curl:latest \
    --restart=Never --overrides='{"spec":{"hostNetwork":true}}' \
    -- curl -s -o /dev/null -w "%{http_code}" "http://${node}:${port}/healthz" 2>/dev/null | grep -q "200"; then
    pass "$component metrics endpoint responding (port $port)"
    kubectl delete pod "$pod_name" --force 2>/dev/null || true
  else
    warn "$component metrics endpoint not responding yet (port $port)"
    kubectl delete pod "$pod_name" --force 2>/dev/null || true
  fi
}
