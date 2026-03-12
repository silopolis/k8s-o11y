---
created: 2026-03-12T18:05:04.236Z
title: Add markdownlint-cli to mise tools and pre-commit checking
area: tooling
files: []
---

## Problem

Currently markdownlint is invoked via `npx markdownlint-cli2` in AGENTS.md and documentation. This has drawbacks:

- Requires Node.js/npm to be available
- Slower due to npx resolution overhead
- Version not pinned in project configuration
- Inconsistent with the project's mise-based tooling approach

The project uses mise (formerly rtx) for tool management (talosctl, kubectl, helm, etc.), but markdownlint is not managed as a mise tool.

## Solution

Add markdownlint-cli2 as a proper mise tool and integrate into quality checks:

1. Add `markdownlint-cli2` to `mise.toml` under `[tools]` section
2. Create a mise task `lint_md` or `lint_docs` that runs markdownlint on all `.md` files
3. Update AGENTS.md to reference the mise task instead of npx
4. Ensure this integrates with the pre-commit hooks setup (complements the existing pre-commit hooks todo)

Benefits:
- Consistent tooling management via mise
- Faster local execution (no npx overhead)
- Version pinned in mise.toml
- CI/CD and local development use same tool versions
