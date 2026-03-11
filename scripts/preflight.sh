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

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++)) || true
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++)) || true
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Source check functions
source "${PROJECT_ROOT}/lib/checks.sh"

# Run all checks (capture return codes to prevent set -e from exiting)
check_kubectl_installed || true
check_cluster_connectivity || true
check_helm_installed || true
check_helmfile_installed || true
check_node_health || true
check_metrics_api || true
check_monitoring_namespace || true
check_prometheus_crds || true
check_org_config || true
check_helmfile_config || true

# Summary
header "PREFLIGHT SUMMARY"

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
