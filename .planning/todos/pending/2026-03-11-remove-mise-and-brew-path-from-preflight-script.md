---
created: 2026-03-11T16:00:33.900Z
title: Remove mise and brew PATH from preflight script
area: tooling
files:
  - scripts/preflight.sh:16-21
---

## Problem

The `scripts/preflight.sh` script currently hardcodes PATH modifications for mise and homebrew on lines 16-21:

```bash
# Add mise paths if available (for tools managed by mise)
if [ -d "$HOME/.local/share/mise/shims" ]; then
    export PATH="$HOME/.local/share/mise/shims:$PATH"
elif [ -d "/home/linuxbrew/.linuxbrew/bin" ]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi
```

This approach is problematic because:
1. It assumes specific installation paths for mise and brew
2. It may override user's preferred PATH configuration
3. It creates maintenance burden when tool paths change
4. Users should manage their own PATH environment

The script should rely on the user's environment being correctly configured rather than trying to fix it automatically.

## Solution

Remove the PATH modification block (lines 16-21) from `scripts/preflight.sh`. Instead:

1. Add documentation at the top of the script explaining required tools
2. Include a check that fails with helpful error message if tools aren't found
3. Suggest users configure their PATH properly in their shell profile

The preflight checks already exist (checks 3-4 for Helm and Helmfile) that will fail with installation instructions if tools are missing.
