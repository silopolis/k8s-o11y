#!/usr/bin/env bash
#
# Shared check functions for deployment validation
# These functions can be sourced by any deployment or validation script
#
# Usage: source "$(dirname "$0")/../lib/checks.sh"
# Dependencies: lib/output.sh must be sourced first

# Check 1: kubectl installed
check_kubectl_installed() {
  header "CHECK 1: kubectl Installation"
  if command -v kubectl &>/dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    pass "kubectl is installed (version: $KUBECTL_VERSION)"
    return 0
  else
    fail "kubectl is not installed or not in PATH"
    detail "Install: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    return 1
  fi
}

# Check 2: Kubernetes cluster connectivity
check_cluster_connectivity() {
  header "CHECK 2: Kubernetes Cluster Connectivity"
  if kubectl cluster-info &>/dev/null; then
    CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
    pass "Cluster is reachable (context: $CONTEXT)"

    # Show cluster details
    CLUSTER_VERSION=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    info "Cluster version: $CLUSTER_VERSION"
    return 0
  else
    fail "Cannot connect to Kubernetes cluster"
    detail "Check: kubectl config get-contexts"
    detail "Fix: kubectl config use-context <your-context>"
    return 1
  fi
}

# Check 3: Helm installed
check_helm_installed() {
  header "CHECK 3: Helm Installation"
  if command -v helm &>/dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null || echo "unknown")
    pass "Helm is installed (version: $HELM_VERSION)"
    return 0
  else
    fail "Helm is not installed"
    detail "Install: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    return 1
  fi
}

# Check 4: Helmfile installed
check_helmfile_installed() {
  header "CHECK 4: Helmfile Installation"
  if command -v helmfile &>/dev/null; then
    HELMFILE_VERSION=$(helmfile version --short 2>/dev/null || echo "unknown")
    pass "Helmfile is installed (version: $HELMFILE_VERSION)"
    return 0
  else
    fail "Helmfile is not installed"
    detail "Install: https://helmfile.readthedocs.io/en/latest/#installation"
    detail "Quick install: brew install helmfile"
    return 1
  fi
}

# Check 5: Node health status
check_node_health() {
  header "CHECK 5: Node Health Status"
  if kubectl get nodes &>/dev/null; then
    # Use grep -v with || true to prevent exit when all nodes are ready (no matches)
    NOT_READY=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -v "True" | wc -w || true)
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

    if [ "$NOT_READY" -eq 0 ]; then
      pass "All $NODE_COUNT nodes are Ready"
      return 0
    else
      fail "$NOT_READY node(s) are not Ready"
      detail "Check: kubectl get nodes"
      kubectl get nodes 2>/dev/null | tail -n +2
      return 1
    fi
  else
    warn "Cannot check node status (cluster connection issue)"
    return 2
  fi
}

# Check 6: Metrics API availability
check_metrics_api() {
  header "CHECK 6: Cluster Resources"
  if kubectl top node &>/dev/null 2>&1; then
    pass "Metrics API available for resource checks"
    # Note: kubectl top requires metrics-server
    return 0
  else
    warn "Metrics API not available (metrics-server may not be installed)"
    detail "This is OK for preflight - basic node check passes"
    return 2
  fi
}

# Check 7: Monitoring namespace status
check_monitoring_namespace() {
  header "CHECK 7: Monitoring Namespace Check"
  if kubectl get namespace monitoring &>/dev/null; then
    NS_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l)
    if [ "$NS_PODS" -eq 0 ]; then
      warn "Namespace 'monitoring' exists but is empty"
      detail "Continuing - CRDs will be installed in this namespace"
      return 2
    else
      warn "Namespace 'monitoring' exists with $NS_PODS pod(s)"
      detail "Existing resources may conflict with new deployment"
      detail "Consider: kubectl delete namespace monitoring"
      return 2
    fi
  else
    pass "Namespace 'monitoring' does not exist (will be created)"
    return 0
  fi
}

# Check 8: Existing Prometheus CRDs
check_prometheus_crds() {
  header "CHECK 8: Existing Prometheus CRDs"
  EXISTING_CRDS=$(kubectl get crd 2>/dev/null | grep -c "monitoring.coreos.com" 2>/dev/null | head -1 || echo "0")
  if [ "$EXISTING_CRDS" -gt 0 ]; then
    CRD_LIST=$(kubectl get crd 2>/dev/null | grep "monitoring.coreos.com" | awk '{print $1}' | head -5)
    warn "Found $EXISTING_CRDS Prometheus Operator CRD(s) already installed"
    detail "CRDs found:"
    echo "$CRD_LIST" | while read -r crd; do
      bullet "$crd"
    done
    detail "If versions are compatible, this is OK. CRDs will be updated."
    return 2
  else
    pass "No existing Prometheus Operator CRDs found (clean install)"
    return 0
  fi
}

# Check 9: Organization configuration
check_org_config() {
  header "CHECK 9: Organization Configuration"
  if [ -n "${ORGANIZATION:-}" ]; then
    pass "ORGANIZATION environment variable is set: $ORGANIZATION"
    return 0
  else
    warn "ORGANIZATION environment variable is not set"
    detail "Helmfile will use default value 'dev-org'"
    detail "To set: export ORGANIZATION=<your-org-name>"
    return 2
  fi
}

# Check 10: Helmfile configuration
check_helmfile_config() {
  header "CHECK 10: Helmfile Configuration"
  if [ -f "helmfile.yaml" ]; then
    pass "helmfile.yaml exists"

    # Check if values directory and files exist
    if [ -d "values" ]; then
      pass "values/ directory exists"
    else
      fail "values/ directory not found"
      return 1
    fi

    if [ -f "values/kube-prometheus-stack-crds.yaml" ]; then
      pass "values/kube-prometheus-stack-crds.yaml exists"
      return 0
    else
      fail "values/kube-prometheus-stack-crds.yaml not found"
      return 1
    fi
  else
    fail "helmfile.yaml not found in current directory"
    return 1
  fi
}
