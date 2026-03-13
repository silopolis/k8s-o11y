---
created: 2026-03-12T17:59:48.907Z
title: Add pre-commit hooks support to the repository
area: tooling
files: []
---

## Problem

The repository lacks pre-commit hooks to enforce code quality standards before commits are made. Currently, there's no automated mechanism to:

- Run markdownlint on documentation before committing
- Validate YAML configuration files
- Ensure consistent code formatting
- Prevent commits of secrets or sensitive data

This can lead to broken builds, inconsistent formatting, and quality issues being discovered only after commits are pushed.

## Solution

Set up pre-commit framework with appropriate hooks for the project:

1. Install pre-commit configuration (`.pre-commit-config.yaml`)
2. Include hooks for:
   - markdownlint-cli2 for documentation
   - YAML validation
   - Trailing whitespace removal
   - End-of-file fixer
   - Secret detection (gitleaks or similar)
3. Document setup in README or AGENTS.md
4. Consider mise task for installing hooks

The repository already uses markdownlint-cli2 via npx, so the pre-commit hooks should leverage existing tooling patterns.
