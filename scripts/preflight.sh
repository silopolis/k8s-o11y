#!/usr/bin/env bash
#
# Preflight checks for kube-prometheus-stack deployment
# Phase 1 Plan 01: Environment validation
#
# Usage: ./scripts/preflight.sh
# Exit codes:
#   0: All checks passed
#   1: Critical failure (stop deployment)
#   2: Warnings only (proceed with caution)
#
# Reference: .planning/phases/01-core-observability-stack/01-01-PLAN.md

set -euo pipefail

# Add mise paths if available (for tools managed by mise)
if [ -d "$HOME/.local/share/mise/shims" ]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
elif [ -d "/home/linuxbrew/.linuxbrew/bin" ]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track warnings and failures
WARNINGS=0
ERRORS=0

# Print functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++)) || true
}

print_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++)) || true
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check 1: kubectl installed
print_header "CHECK 1: kubectl Installation"
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    print_pass "kubectl is installed (version: $KUBECTL_VERSION)"
else
    print_fail "kubectl is not installed or not in PATH"
    echo "  Install: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
fi

# Check 2: kubectl context valid and cluster reachable
print_header "CHECK 2: Kubernetes Cluster Connectivity"
if kubectl cluster-info &> /dev/null; then
    CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
    print_pass "Cluster is reachable (context: $CONTEXT)"
    
    # Show cluster details
    CLUSTER_VERSION=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    print_info "Cluster version: $CLUSTER_VERSION"
else
    print_fail "Cannot connect to Kubernetes cluster"
    echo "  Check: kubectl config get-contexts"
    echo "  Fix: kubectl config use-context <your-context>"
fi

# Check 3: Helm installed
print_header "CHECK 3: Helm Installation"
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null || echo "unknown")
    print_pass "Helm is installed (version: $HELM_VERSION)"
else
    print_fail "Helm is not installed"
    echo "  Install: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
fi

# Check 4: Helmfile installed
print_header "CHECK 4: Helmfile Installation"
if command -v helmfile &> /dev/null; then
    HELMFILE_VERSION=$(helmfile version --short 2>/dev/null || echo "unknown")
    print_pass "Helmfile is installed (version: $HELMFILE_VERSION)"
else
    print_fail "Helmfile is not installed"
    echo "  Install: https://helmfile.readthedocs.io/en/latest/#installation"
    echo "  Quick install: brew install helmfile"
fi

# Check 5: Nodes are healthy and ready
print_header "CHECK 5: Node Health Status"
if kubectl get nodes &> /dev/null; then
    # Use grep -v with || true to prevent exit when all nodes are ready (no matches)
    NOT_READY=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -v "True" | wc -w || true)
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    
    if [ "$NOT_READY" -eq 0 ]; then
        print_pass "All $NODE_COUNT nodes are Ready"
    else
        print_fail "$NOT_READY node(s) are not Ready"
        echo "  Check: kubectl get nodes"
        kubectl get nodes 2>/dev/null | tail -n +2
    fi
else
    print_warn "Cannot check node status (cluster connection issue)"
fi

# Check 6: Sufficient resources available
print_header "CHECK 6: Cluster Resources"
if kubectl top node &> /dev/null 2>&1; then
    print_pass "Metrics API available for resource checks"
    # Note: kubectl top requires metrics-server
else
    print_warn "Metrics API not available (metrics-server may not be installed)"
    echo "  This is OK for preflight - basic node check passes"
fi

# Check 7: Monitoring namespace doesn't exist or is empty
print_header "CHECK 7: Monitoring Namespace Check"
if kubectl get namespace monitoring &> /dev/null; then
    NS_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l)
    if [ "$NS_PODS" -eq 0 ]; then
        print_warn "Namespace 'monitoring' exists but is empty"
        echo "  Continuing - CRDs will be installed in this namespace"
    else
        print_warn "Namespace 'monitoring' exists with $NS_PODS pod(s)"
        echo "  Existing resources may conflict with new deployment"
        echo "  Consider: kubectl delete namespace monitoring"
    fi
else
    print_pass "Namespace 'monitoring' does not exist (will be created)"
fi

# Check 8: No conflicting CRDs from previous installs
print_header "CHECK 8: Existing Prometheus CRDs"
EXISTING_CRDS=$(kubectl get crd 2>/dev/null | grep -c "monitoring.coreos.com" 2>/dev/null | head -1 || echo "0")
if [ "$EXISTING_CRDS" -gt 0 ]; then
    CRD_LIST=$(kubectl get crd 2>/dev/null | grep "monitoring.coreos.com" | awk '{print $1}' | head -5)
    print_warn "Found $EXISTING_CRDS Prometheus Operator CRD(s) already installed"
    echo "  CRDs found:"
    echo "$CRD_LIST" | while read crd; do
        echo "    - $crd"
    done
    echo "  If versions are compatible, this is OK. CRDs will be updated."
else
    print_pass "No existing Prometheus Operator CRDs found (clean install)"
fi

# Check 9: Organization environment variable
print_header "CHECK 9: Organization Configuration"
if [ -n "${ORGANIZATION:-}" ]; then
    print_pass "ORGANIZATION environment variable is set: $ORGANIZATION"
else
    print_warn "ORGANIZATION environment variable is not set"
    echo "  Helmfile will use default value 'dev-org'"
    echo "  To set: export ORGANIZATION=<your-org-name>"
fi

# Check 10: Helmfile.yaml exists and is valid
print_header "CHECK 10: Helmfile Configuration"
if [ -f "helmfile.yaml" ]; then
    print_pass "helmfile.yaml exists"
    
    # Check if values directory and files exist
    if [ -d "values" ]; then
        print_pass "values/ directory exists"
    else
        print_fail "values/ directory not found"
    fi
    
    if [ -f "values/kube-prometheus-stack-crds.yaml" ]; then
        print_pass "values/kube-prometheus-stack-crds.yaml exists"
    else
        print_fail "values/kube-prometheus-stack-crds.yaml not found"
    fi
else
    print_fail "helmfile.yaml not found in current directory"
fi

# Summary
print_header "PREFLIGHT SUMMARY"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC} Ready for deployment."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}All critical checks passed with $WARNINGS warning(s).${NC}"
    echo -e "Review warnings above. You may proceed with deployment."
    exit 2
else
    echo -e "${RED}Preflight checks failed with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    echo -e "Please address critical errors before deployment."
    exit 1
fi
