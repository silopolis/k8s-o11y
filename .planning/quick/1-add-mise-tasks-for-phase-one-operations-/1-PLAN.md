---
type: quick
task: 1
description: add mise tasks for phase one operations (preflight check, linting, deployment, etc.)
date: 2026-03-11
slug: add-mise-tasks-for-phase-one-operations-
files_modified:
  - mise.toml
must_haves:
  truths:
    - mise tasks provide convenient aliases for common Phase 1 operations
    - All tasks must be executable via `mise run <task>`
  artifacts:
    - path: mise.toml
      provides: mise task definitions for Phase 1 operations
      min_lines: 20
---

## Goal

Add mise task definitions to `mise.toml` for common Phase 1 operations, making it easier to run preflight checks, linting, deployment, and other frequent tasks with a simple `mise run <task>` command.

## Context

The project uses mise for tool management. Adding tasks to `mise.toml` provides:
- Convenient shortcuts for common operations
- Self-documenting task list via `mise tasks`
- Consistent command interface across team members

Existing Phase 1 operations that should be wrapped:
- Preflight checks (`scripts/preflight.sh`)
- Helmfile deployment commands
- Markdown linting (`npx markdownlint-cli2`)

## Tasks

### Task 1: Read current mise.toml and add Phase 1 tasks

**Files:** `mise.toml`

**Action:**
1. Read the current `mise.toml` to understand existing structure
2. Add a `[tasks]` section (or extend existing one) with the following tasks:

```toml
[tasks]
preflight = "./scripts/preflight.sh"
lint = "npx markdownlint-cli2 '**/*.md'"
lint-fix = "npx markdownlint-cli2 '**/*.md' --fix"
sync-crds = "helmfile -f helmfile.yaml -l name=kube-prometheus-stack-crds sync"
lint-helmfile = "helmfile -f helmfile.yaml lint"
```

3. Add descriptions to tasks for better discoverability:
```toml
[tasks]
preflight = { run = "./scripts/preflight.sh", description = "Run preflight checks before deployment" }
lint = { run = "npx markdownlint-cli2 '**/*.md'", description = "Lint all markdown files" }
lint-fix = { run = "npx markdownlint-cli2 '**/*.md' --fix", description = "Lint and auto-fix markdown files" }
sync-crds = { run = "helmfile -f helmfile.yaml -l name=kube-prometheus-stack-crds sync", description = "Sync CRDs release via Helmfile" }
lint-helmfile = { run = "helmfile -f helmfile.yaml lint", description = "Lint Helmfile configuration" }
```

**Verify:**
```bash
# Check mise.toml exists and has tasks section
[ -f mise.toml ] && grep -q '\[tasks\]' mise.toml && echo "Tasks section added"

# Verify tasks are recognized
mise tasks | grep -E "preflight|lint|sync-crds" | wc -l
```

**Done:** mise.toml updated with Phase 1 task definitions

## Verification

After completing:
1. Run `mise tasks` - should show the new tasks with descriptions
2. Run `mise run preflight --help` (or similar) to verify task syntax is valid
3. mise.toml should be valid TOML syntax

## Success Criteria

- [ ] mise.toml contains a [tasks] section
- [ ] At least 4 tasks defined: preflight, lint, sync-crds, lint-helmfile
- [ ] Tasks have descriptions for discoverability
- [ ] `mise tasks` command lists all new tasks
- [ ] Valid TOML syntax (no parse errors)
