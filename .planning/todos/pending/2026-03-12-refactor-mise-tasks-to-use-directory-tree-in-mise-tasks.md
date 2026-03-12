---
created: 2026-03-12T18:39:08.159Z
title: Refactor mise tasks to use directory tree in .mise/tasks/
area: tooling
files:
  - mise.toml
  - .mise/
---

## Problem

Current mise tasks are defined inline in `mise.toml` using the `[tasks]` section. This approach has limitations:

- **Maintainability:** All tasks are in one file, making it hard to navigate and edit
- **Scalability:** As the project grows, mise.toml becomes unwieldy
- **No shell completion:** Inline tasks don't provide rich completion options
- **Limited organization:** Can't group related tasks by function/phase
- **Version control noise:** Every task change requires editing the main config file

**Current Structure:**
```toml
[tasks]
check_preflight = "scripts/check_preflight.sh"
lint_helmfile = "helmfile lint"
deploy_prom_stack = "helmfile apply -f helmfile.yaml"
```

## Solution

Migrate to mise's directory-based task structure using `.mise/tasks/`:

1. **Create directory structure**
   ```
   .mise/tasks/
   ├── check/
   │   ├── preflight
   │   └── versions
   ├── deploy/
   │   ├── prom-crds
   │   └── prom-stack
   ├── lint/
   │   ├── helmfile
   │   └── markdown
   ├── verify/
   │   └── phase1
   ```

2. **Convert each task to an individual executable file**
   - Each file becomes a standalone script
   - Files are executable and have proper shebang
   - Mise automatically discovers them as tasks

3. **Update mise.toml**
   - Remove inline `[tasks]` section
   - Ensure `.mise/tasks/` is in the task file discovery path
   - May need to set `task_config.file_discovery = true`

4. **Benefits:**
   - Better organization by function
   - Easier to edit individual tasks
   - Shell completion support for task names
   - Can version control tasks separately
   - Self-documenting task structure

## Migration Steps

1. Create `.mise/tasks/` directory tree
2. Move existing tasks from mise.toml to individual files
3. Test each migrated task
4. Update AGENTS.md documentation
5. Remove old inline task definitions

## References

- mise documentation: "File Tasks" feature
- Current tasks defined in: `mise.toml`
- Example tasks: `check_preflight`, `lint_helmfile`, `deploy_prom_crds`, `deploy_prom_stack`, `verify_phase1`
