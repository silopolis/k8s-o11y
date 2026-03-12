#!/usr/bin/env bash
#
# Backup Talos machine configurations for all control plane nodes
# Usage: ./scripts/backup-talos-config.sh
#

set -euo pipefail

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_ROOT}/lib/output.sh"

# Custom fail function that exits
fail_fatal() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Create backup directory
BACKUP_DIR=".talos/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

header "Talos Machine Config Backup"
echo "Backup directory: $BACKUP_DIR"
echo ""

# Get control plane nodes
NODES=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)

if [ -z "$NODES" ]; then
    fail_fatal "No control plane nodes found. Is kubectl configured?"
fi

NODE_COUNT=$(echo "$NODES" | wc -w)
pass "Found $NODE_COUNT control plane node(s)"
echo ""

# Backup each node
for node in $NODES; do
    echo "Backing up node: $node"
    
    if talosctl -n "$node" get machineconfig -o yaml > "$BACKUP_DIR/$node-mc.yaml" 2>/dev/null; then
        pass "Backup saved to $BACKUP_DIR/$node-mc.yaml"
    else
        warn "Failed to backup node $node (talosctl may not have access)"
    fi
done

echo ""
pass "Backup complete. Files saved in: $BACKUP_DIR"
echo ""
echo "To restore a node configuration:"
echo "  talosctl -n <node-ip> apply-config -f $BACKUP_DIR/<node-ip>-mc.yaml"
