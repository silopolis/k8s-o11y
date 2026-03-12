#!/usr/bin/env bash
#
# Apply Talos control plane metrics configuration with rolling update
# Usage: ./scripts/apply-talos-metrics-config.sh
#

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_ROOT}/lib/output.sh"

PATCH_FILE="${PROJECT_ROOT}/config/talos/control-plane-metrics-patch.yaml"
SLEEP_DURATION=45

# Check prerequisites
check_prerequisites() {
    header "Prerequisites Check"
    
    if ! command -v talosctl &> /dev/null; then
        fail "talosctl not found in PATH"
        exit 1
    fi
    pass "talosctl is available"
    
    if ! command -v kubectl &> /dev/null; then
        fail "kubectl not found in PATH"
        exit 1
    fi
    pass "kubectl is available"
    
    if [ ! -f "$PATCH_FILE" ]; then
        fail "Patch file not found: $PATCH_FILE"
        exit 1
    fi
    pass "Patch file exists: $PATCH_FILE"
    
    echo ""
}

# Get control plane nodes
get_control_plane_nodes() {
    kubectl get nodes -l node-role.kubernetes.io/control-plane \
      -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo ""
}

# Apply configuration to a single node
apply_to_node() {
    local node=$1
    
    echo "=== Processing node: $node ==="
    
    # Check node is ready before starting
    if ! kubectl get node "$node" &> /dev/null; then
        # Try to find node by hostname
        local node_name
        node_name=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$node')].metadata.name}" 2>/dev/null || echo "")
        if [ -z "$node_name" ]; then
            fail "Cannot find node with IP $node"
            return 1
        fi
        echo "Node name: $node_name"
    fi
    
    # Apply patch
    echo "Applying patch..."
    if talosctl -n "$node" patch mc --patch @"$PATCH_FILE"; then
        pass "Patch applied successfully"
    else
        fail "Failed to apply patch to node $node"
        return 1
    fi
    
    # Wait for components to restart
    echo ""
    echo "Waiting ${SLEEP_DURATION}s for control plane components to restart..."
    sleep "$SLEEP_DURATION"
    
    # Verify node is still ready
    echo "Verifying node health..."
    local node_name
    node_name=$(kubectl get nodes -o jsonpath="{.items[?(@.status.addresses[?(@.type=='InternalIP')].address=='$node')].metadata.name}" 2>/dev/null || echo "")
    
    if [ -n "$node_name" ]; then
        if kubectl wait --for=condition=Ready "node/$node_name" --timeout=120s &> /dev/null; then
            pass "Node is Ready"
        else
            fail "Node did not become Ready within timeout"
            return 1
        fi
    else
        warn "Could not verify node status (node name lookup failed)"
    fi
    
    # Verify metrics endpoints
    echo ""
    echo "Verifying metrics endpoints..."
    verify_metrics_endpoint "$node" "10257" "controller-manager"
    verify_metrics_endpoint "$node" "10259" "scheduler"
    verify_metrics_endpoint "$node" "10249" "kube-proxy"
    
    echo ""
    pass "=== Node $node completed ==="
    echo ""
    
    return 0
}

# Verify a single metrics endpoint
verify_metrics_endpoint() {
    local node=$1
    local port=$2
    local component=$3
    
    # Create a test pod with hostNetwork to access the endpoint
    local pod_name="metrics-test-${port}-$(date +%s)"
    
    if kubectl run "$pod_name" --image=curlimages/curl:latest \
        --restart=Never --overrides='{"spec":{"hostNetwork":true}}' \
        -- curl -s -o /dev/null -w "%{http_code}" "http://'$node':'$port'/healthz" 2>/dev/null | grep -q "200"; then
        pass "$component metrics endpoint responding (port $port)"
        kubectl delete pod "$pod_name" --force 2>/dev/null || true
    else
        warn "$component metrics endpoint not responding yet (port $port)"
        kubectl delete pod "$pod_name" --force 2>/dev/null || true
    fi
}

# Main execution
main() {
    header "Talos Control Plane Metrics Configuration"
    echo "This script will configure Talos to expose control plane component metrics"
    echo ""
    
    check_prerequisites
    
    # Get nodes
    NODES=$(get_control_plane_nodes)
    
    if [ -z "$NODES" ]; then
        fail "No control plane nodes found"
        exit 1
    fi
    
    NODE_COUNT=$(echo "$NODES" | wc -w)
    echo "Found $NODE_COUNT control plane node(s):"
    for node in $NODES; do
        echo "  - $node"
    done
    echo ""
    
    # Confirm before proceeding
    echo -n "Proceed with rolling update? This will restart control plane components. [y/N]: "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
    
    # Run backup first
    echo "Creating backup of current configurations..."
    "${SCRIPT_DIR}/backup-talos-config.sh" || warn "Backup script failed, continuing anyway"
    echo ""
    
    # Apply to each node sequentially
    header "Rolling Update: Applying Configuration"
    
    for node in $NODES; do
        if ! apply_to_node "$node"; then
            fail "Failed to apply configuration to node $node"
            echo ""
            echo "Rolling update stopped. Previous nodes were configured successfully."
            echo "To rollback, restore from backup in .talos/backup-*/"
            exit 1
        fi
    done
    
    # Summary
    header "Configuration Complete"
    
    if [ $(get_errors) -eq 0 ]; then
        pass "All control plane nodes configured successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Verify Prometheus can scrape the new endpoints"
        echo "  2. Check Prometheus targets page for controller-manager, scheduler, kube-proxy"
        echo "  3. Configure Prometheus scrape configs if needed"
    else
        warn "Completed with $(get_errors) error(s) and $(get_warnings) warning(s)"
        echo ""
        echo "Review the output above for any issues."
    fi
}

main "$@"
