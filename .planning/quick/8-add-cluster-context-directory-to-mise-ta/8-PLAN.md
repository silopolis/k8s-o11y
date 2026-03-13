---
phase: quick
plan: 8
type: execute
wave: 1
depends_on: []
files_modified: [.mise/tasks/cluster/context/.gitkeep]
autonomous: true
requirements: []
must_haves:
  truths:
    - cluster/context directory exists in .mise/tasks/
    - Directory is tracked by git
  artifacts:
    - path: .mise/tasks/cluster/context/.gitkeep
      provides: "Git tracking placeholder for empty directory"
  key_links: []
---

<objective>
Add a 'cluster/context' subdirectory to the .mise/tasks/ directory structure.

Purpose: Extend the mise tasks directory tree to support cluster context management operations.
Output: New directory `.mise/tasks/cluster/context/` with git tracking.
</objective>

<execution_context>
@/home/tarax/.config/opencode/get-shit-done/workflows/execute-plan.md
@/home/tarax/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.mise/tasks/cluster
</context>

<tasks>

<task type="auto">
  <name>Create cluster/context directory structure</name>
  <files>.mise/tasks/cluster/context/.gitkeep</files>
  <action>
    Create the `.mise/tasks/cluster/context/` directory with a `.gitkeep` file.

    The .mise/tasks/ structure follows a tree pattern where related operations are grouped.
    The `cluster/` directory already exists (contains only .gitkeep), and now needs a `context/`
    subdirectory for cluster context management tasks.

    Create the directory and add a `.gitkeep` file to ensure git tracks the empty directory.
  </action>
  <verify>
    ls -la .mise/tasks/cluster/context/
    git status --short .mise/tasks/cluster/context/
  </verify>
  <done>
    - Directory `.mise/tasks/cluster/context/` exists
    - `.gitkeep` file exists in the directory
    - Directory is ready for future task scripts
  </done>
</task>

</tasks>

<verification>
- Directory structure matches pattern: `.mise/tasks/cluster/context/`
- Git recognizes the new directory with .gitkeep
</verification>

<success_criteria>
- `ls .mise/tasks/cluster/context/` shows `.gitkeep`
- Directory is tracked by git (shows in `git status`)
- Follows existing directory naming conventions
</success_criteria>

<output>
After completion, create `.planning/quick/8-add-cluster-context-directory-to-mise-ta/8-SUMMARY.md`
</output>

<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline : -->
