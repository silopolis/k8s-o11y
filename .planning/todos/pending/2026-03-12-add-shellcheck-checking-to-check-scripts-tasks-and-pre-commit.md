---
created: 2026-03-12T18:01:36.516Z
title: Add shellcheck checking to check scripts, tasks and pre-commit
area: tooling
files: []
---

## Problem

Shell scripts in the repository lack automated static analysis for common bash scripting issues. Scripts like `check_preflight`, `verify-phase1.sh`, and other tooling in the `scripts/` directory may contain:

- Unquoted variables causing word splitting issues
- Deprecated or non-portable syntax
- Unused variables or unreachable code
- Missing error handling patterns
- Shell compatibility issues

Without shellcheck integration, these issues may only be discovered when scripts fail in production.

## Solution

Integrate shellcheck into the project's quality assurance pipeline:

1. Add shellcheck to `.pre-commit-config.yaml` (when created)
2. Create a mise task for running shellcheck locally: `shellcheck scripts/*.sh`
3. Add shellcheck to CI/CD if applicable
4. Run initial shellcheck pass on existing scripts and fix critical issues
5. Document shellcheck usage in AGENTS.md or README

Focus on scripts in:
- `scripts/` directory (verify-phase1.sh, check_preflight, etc.)
- Root-level scripts
- Any shell-based mise tasks

Consider starting with relaxed settings (e.g., allowing `SC2034` for unused variables in library scripts) and tightening over time.
