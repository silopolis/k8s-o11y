---
created: 2026-03-11T16:05:27.988Z
title: Extract colors and print functions to shared lib
area: tooling
files:
  - scripts/preflight.sh:23-57
  - lib/
---

## Problem

The `scripts/preflight.sh` script has color definitions and print helper functions embedded directly in the script (lines 23-57):

**Color definitions (lines 23-28):**
```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
```

**Print functions (lines 35-57):**
- `print_header()` - Display section headers
- `print_pass()` - Success messages with ✓
- `print_fail()` - Error messages with ✗
- `print_warn()` - Warning messages with ⚠
- `print_info()` - Info messages with ℹ

These utilities are likely needed by other scripts in the project. Currently they would need to be duplicated in every script that needs colored output, leading to code duplication and maintenance issues.

## Solution

Create a shared library structure:

1. Create `lib/` directory at project root
2. Create `lib/output.sh` containing:
   - Color definitions (RED, GREEN, YELLOW, BLUE, NC)
   - Print helper functions (header, pass, fail, warn, info)
   - Warning/Error tracking variables (WARNINGS, ERRORS counters)
3. Source the library in scripts:
   ```bash
   source "$(dirname "$0")/../lib/output.sh"
   ```
4. Update `scripts/preflight.sh` to use the shared library instead of inline definitions

This follows DRY principles and allows other deployment/utility scripts to have consistent, colored output without duplication.
