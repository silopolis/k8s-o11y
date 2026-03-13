---
phase: quick
type: execute
plan: "15"
plan_name: Create commit for staged changes
wave: 1
depends_on: []
files_modified:
  - .mise/tasks/lint/all
  - .mise/tasks/lint/shell/_default
  - .mise/tasks/lint/shell/all
  - .mise/tasks/verify/wave2
  - lib/checks.sh
  - lib/lint.sh
  - lib/talos.sh
  - mise.toml
autonomous: true
---

<objective>
Create a commit for the currently staged Wave 2 quality gate files. These include lint tasks, shell lint tasks, verification task, shared lint library, and related library modifications.
</objective>

<tasks>

<task type="auto" id="1">
  <title>Commit Wave 2 quality gate implementation files</title>
  <files>.mise/tasks/lint/all, .mise/tasks/lint/shell/_default, .mise/tasks/lint/shell/all, .mise/tasks/verify/wave2, lib/checks.sh, lib/lint.sh, lib/talos.sh, mise.toml</files>
  <action>
    Commit the staged Wave 2 implementation files with a descriptive message explaining the quality gate infrastructure.
    
    Commit message: "feat(quality): implement Wave 2 quality gates infrastructure
    
    - Add shell lint tasks (lint:shell) using shellcheck
    - Add Wave 2 verification task (verify:wave2)
    - Create shared lint library (lib/lint.sh) with reusable functions
    - Update lib/checks.sh and lib/talos.sh with pre-commit fixes
    - Update mise.toml with lint:markdown and lint:shell task references"
  </action>
  <verify>Run git log -1 --oneline to verify commit was created</verify>
  <done>Wave 2 implementation files committed</done>
</task>

</tasks>

<success_criteria>
- [ ] Staged Wave 2 files are committed
- [ ] Commit has descriptive message explaining the quality gate infrastructure
- [ ] git status shows no staged files remaining
</success_criteria>

<output>
After completion, create `.planning/quick/15-create-commit-for-staged-changes/15-SUMMARY.md`

**Files Modified:**
- .mise/tasks/lint/all (updated - aggregate lint task with lib/lint.sh)
- .mise/tasks/lint/shell/_default (new - default shell lint task)
- .mise/tasks/lint/shell/all (new - shellcheck task)
- .mise/tasks/verify/wave2 (new - Wave 2 verification task)
- lib/checks.sh (modified - pre-commit fixes)
- lib/lint.sh (new - shared linting utilities)
- lib/talos.sh (modified - pre-commit fixes)
- mise.toml (modified - added lint:markdown and lint:shell tasks)
</output>
