---
phase: quick
plan: 7
type: execute
wave: 1
depends_on: []
files_modified: [.mise/tasks/check/, .mise/tasks/cluster/, .mise/tasks/secrets/, .mise/tasks/install/, .mise/tasks/template/]
autonomous: true
requirements: [QUICK-07]
must_haves:
  truths:
    - All five directories exist in .mise/tasks/
    - Directory structure is consistent with existing directories
  artifacts:
    - path: .mise/tasks/check/
      provides: "Directory for check-related mise tasks"
    - path: .mise/tasks/cluster/
      provides: "Directory for cluster-related mise tasks"
    - path: .mise/tasks/secrets/
      provides: "Directory for secrets management mise tasks"
    - path: .mise/tasks/install/
      provides: "Directory for installation mise tasks"
    - path: .mise/tasks/template/
      provides: "Directory for template-related mise tasks"
  key_links: []
---

<objective>
Create five new task directories in .mise/tasks/ to organize mise tasks by category.

Purpose: Establish directory structure for the pending todo "Refactor mise tasks to use directory tree in .mise/tasks/" (PENDING: 2026-03-12-refactor-mise-tasks-to-use-directory-tree-in-mise-tasks.md).
Output: Five new directories (check, cluster, secrets, install, template) alongside existing directories.
</objective>

<execution_context>
@/home/tarax/.config/opencode/get-shit-done/workflows/execute-plan.md
@/home/tarax/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.mise/tasks/

Pending todo: .planning/todos/pending/2026-03-12-refactor-mise-tasks-to-use-directory-tree-in-mise-tasks.md

Existing directories in .mise/tasks/:
- deploy/
- lint/
- utils/
- verify/
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create mise task directories</name>
  <files>.mise/tasks/check/, .mise/tasks/cluster/, .mise/tasks/secrets/, .mise/tasks/install/, .mise/tasks/template/</files>
  <action>
    Create five new directories in .mise/tasks/:
    1. .mise/tasks/check/ - for check-related tasks (validation, health checks)
    2. .mise/tasks/cluster/ - for cluster-related tasks (cluster operations)
    3. .mise/tasks/secrets/ - for secrets management tasks (API keys, credentials)
    4. .mise/tasks/install/ - for installation tasks (CRDs, helm charts, etc.)
    5. .mise/tasks/template/ - for template generation tasks

    Ensure consistent structure with existing directories (deploy/, lint/, utils/, verify/). Create directories as empty folders - task scripts will be added separately.
  </action>
  <verify>ls -la .mise/tasks/ | grep -E "^d.*check$|^d.*cluster$|^d.*secrets$|^d.*install$|^d.*template$"</verify>
  <done>All five directories (check, cluster, secrets, install, template) exist in .mise/tasks/ alongside existing directories</done>
</task>

</tasks>

<verification>
1. Run `ls -la .mise/tasks/` and verify output shows 9 directories total:
   - deploy/
   - lint/
   - utils/
   - verify/
   - check/
   - cluster/
   - secrets/
   - install/
   - template/
2. Run `find .mise/tasks/ -type d | wc -l` should return 10 (including .mise/tasks/ itself plus 9 subdirectories)
</verification>

<success_criteria>
- Five new directories created in .mise/tasks/
- Directory names match specification: check, cluster, secrets, install, template
- Structure is consistent with existing directories
- Task directories are ready for future task script additions
</success_criteria>

<output>
After completion, create `.planning/quick/7-add-check-cluster-secrets-install-templa/7-SUMMARY.md`
</output>
