#!/usr/bin/env bash
#
# Shared output library for colored terminal output
# Provides color definitions and print helper functions
#
# Usage: source "$(dirname "$0")/../lib/output.sh"
#

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

# Print indented detail message (2 spaces)
detail() {
    echo "  $1"
}

# Print bullet point with 4-space indent
bullet() {
    echo "    - $1"
}

# Get current error count
get_errors() {
    echo "$ERRORS"
}

# Get current warning count
get_warnings() {
    echo "$WARNINGS"
}

# Reset counters
reset_counters() {
    ERRORS=0
    WARNINGS=0
}
