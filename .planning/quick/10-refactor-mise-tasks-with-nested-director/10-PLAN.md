---
phase: quick
plan: 10
type: execute
wave: 1
depends_on: []
files_modified:
  - .mise/tasks/secrets/age/init
  - .mise/tasks/lint/markdown/all
  - .mise/tasks/install/helm/plugins
  - .mise/tasks/lint/markdown/fix
  - .mise/tasks/lint/stack
  - .mise/tasks/lint/values/_default
  - .mise/tasks/lint/values/strict
  - .mise/tasks/deploy/crd/kps
  - .mise/tasks/deploy/stack/kps/quick
  - .mise/tasks/deploy/stack/kps/diff
  - .mise/tasks/deploy/stack/kps/apply
  - .mise/tasks/deploy/phase/one
  - .mise/tasks/check/stack
  - .mise/tasks/check/retention
  - .mise/tasks/check/grafana
  - .mise/tasks/check/prometheus
  - .mise/tasks/check/alertmanager
  - .mise/tasks/cluster/context/_default
  - .mise/tasks/lint/markdown/_default
  - .mise/tasks/deploy/stack/kps/_default
autonomous: true
requirements:
  - MISE-REFACTOR-01
must_haves:
  truths:
    - All mise tasks follow consistent nested directory naming convention
    - Default task symlinks exist for discoverable entry points
    - All mise run references updated to new paths
  artifacts:
    - path: ".mise/tasks/lint/markdown/_default"
      provides: "Symlink to all (default markdown lint task)"
    - path: ".mise/tasks/lint/markdown/all"
      provides: "Markdown linting task"
    - path: ".mise/tasks/deploy/stack/kps/_default"
      provides: "Symlink to quick (default stack deploy)"
    - path: ".mise/tasks/deploy/stack/kps/quick"
      provides: "Quick stack deployment"
    - path: ".mise/tasks/cluster/context/_default"
      provides: "Symlink to list (default cluster context)"
  key_links:
    - from: "mise.toml"
      to: "tasks via colon namespace"
      via: "task definitions"
---

<objective>
Refactor mise tasks from flat structure to nested directory structure with default symlinks.

Purpose: Improve task organization and discoverability by using mise's directory-based task hierarchy with `_default` symlinks for sensible defaults.
Output: All 17 tasks reorganized into nested directories with 3 default symlinks.
</objective>

<execution_context>
@/home/tarax/.config/opencode/get-shit-done/workflows/execute-plan.md
@/home/tarax/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/quick/9-refactor-all-mise-inline-tasks-into-file/9-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create nested directory structure and move tasks</name>
  <files>
    .mise/tasks/secrets/age/init
    .mise/tasks/lint/markdown/all
    .mise/tasks/lint/markdown/fix
    .mise/tasks/install/helm/plugins
    .mise/tasks/lint/stack
    .mise/tasks/lint/values/_default
    .mise/tasks/lint/values/strict
    .mise/tasks/deploy/crd/kps
    .mise/tasks/deploy/stack/kps/quick
    .mise/tasks/deploy/stack/kps/diff
    .mise/tasks/deploy/stack/kps/apply
    .mise/tasks/deploy/phase/one
  </files>
  <action>
Create nested directories and move/rename tasks from flat structure:

1. Create directories: secrets/age, lint/markdown, install/helm, lint/values, deploy/crd, deploy/stack/kps, deploy/phase
2. Move files with new names:
   - secrets/age-init → secrets/age/init
   - lint/md → lint/markdown/all
   - lint/md-fix → lint/markdown/fix
   - install/helm-plugins → install/helm/plugins
   - check/validate-stack → lint/stack
   - lint/values → lint/values/_default
   - lint/values-strict → lint/values/strict
   - deploy/prom-crds → deploy/crd/kps
   - deploy/stack-quick → deploy/stack/kps/quick
   - deploy/stack-diff → deploy/stack/kps/diff
   - deploy/stack-apply → deploy/stack/kps/apply
   - deploy/phase1 → deploy/phase/one

3. Update shebang and mise metadata in moved files if needed
4. Remove old empty directories after move

Note: verify/* tasks moved in Task 2 to check/*
  </action>
  <verify>
    ls -la .mise/tasks/secrets/age/ .mise/tasks/lint/markdown/ .mise/tasks/install/helm/ .mise/tasks/lint/values/ .mise/tasks/deploy/crd/ .mise/tasks/deploy/stack/kps/ .mise/tasks/deploy/phase/
  </verify>
  <done>
    All 11 tasks moved to nested directories with correct names, old directories removed
  </done>
</task>

<task type="auto">
  <name>Task 2: Move verify tasks to check directory</name>
  <files>
    .mise/tasks/check/stack
    .mise/tasks/check/retention
    .mise/tasks/check/grafana
    .mise/tasks/check/prometheus
    .mise/tasks/check/alertmanager
  </files>
  <action>
Move all verify/* tasks to check/* for consistent naming:

1. Move files:
   - verify/stack → check/stack
   - verify/retention → check/retention
   - verify/grafana → check/grafana
   - verify/prometheus → check/prometheus
   - verify/alertmanager → check/alertmanager

2. Remove empty verify/ directory
3. Update any internal references if tasks call other tasks
  </action>
  <verify>
    ls -la .mise/tasks/check/ && test ! -d .mise/tasks/verify
  </verify>
  <done>
    All 5 verify tasks moved to check/, verify/ directory removed
  </done>
</task>

<task type="auto">
  <name>Task 3: Create default symlinks</name>
  <files>
    .mise/tasks/cluster/context/_default
    .mise/tasks/lint/markdown/_default
    .mise/tasks/deploy/stack/kps/_default
  </files>
  <action>
Create 3 _default symlinks for discoverable entry points:

1. .mise/tasks/cluster/context/_default → list
2. .mise/tasks/lint/markdown/_default → all
3. .mise/tasks/deploy/stack/kps/_default → quick

Use relative symlinks (ln -s target linkname) so they work regardless of absolute path.

Verify symlinks are correct by checking they resolve to executable files.
  </action>
  <verify>
    test -L .mise/tasks/cluster/context/_default && \
    test -L .mise/tasks/lint/markdown/_default && \
    test -L .mise/tasks/deploy/stack/kps/_default && \
    test -x .mise/tasks/cluster/context/list && \
    test -x .mise/tasks/lint/markdown/all && \
    test -x .mise/tasks/deploy/stack/kps/quick
  </verify>
  <done>
    All 3 _default symlinks created and pointing to valid executable targets
  </done>
</task>

</tasks>

<verification>
- All 17 tasks reorganized into nested directories
- 3 default symlinks created and functional
- No orphaned files in old locations
- All tasks remain executable
- mise run commands would work with new paths
</verification>

<success_criteria>
- Directory structure follows nested convention: category/subcategory/task
- Default symlinks exist: cluster:context, lint:markdown, deploy:stack:kps
- Running `mise run cluster:context` executes list task
- Running `mise run lint:markdown` executes all task  
- Running `mise run deploy:stack:kps` executes quick task
</success_criteria>

<output>
After completion, create `.planning/quick/10-refactor-mise-tasks-with-nested-director/10-SUMMARY.md`
</output>
