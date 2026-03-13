---
phase: quick
plan: 11
type: execute
wave: 1
depends_on: []
files_modified:
  - .mise/tasks/check/preflight
  - .mise/tasks/secrets/age/init
  - .mise/tasks/check/prometheus
  - .mise/tasks/check/stack
  - .mise/tasks/check/talos/metrics
  - .mise/tasks/backup/talos/config
  - .mise/tasks/deploy/talos/config
  - scripts/preflight.sh
  - scripts/secrets-age-init.sh
  - scripts/verify-prometheus.sh
  - scripts/verify-phase1.sh
  - scripts/verify-talos-metrics.sh
  - scripts/backup-talos-config.sh
  - scripts/apply-talos-metrics-config.sh
autonomous: true
requirements:
  - Q11-01
must_haves:
  truths:
    - All mise tasks contain their script content inline (no script calls)
    - Scripts directory is empty after migration (all 7 scripts removed)
    - New directories created for new task locations
    - All existing task functionality preserved
  artifacts:
    - path: .mise/tasks/check/preflight
      provides: Preflight checks (merged from scripts/preflight.sh)
      min_lines: 50
    - path: .mise/tasks/secrets/age/init
      provides: Age key initialization (merged from scripts/secrets-age-init.sh)
      min_lines: 35
    - path: .mise/tasks/check/prometheus
      provides: Prometheus verification (merged from scripts/verify-prometheus.sh)
      min_lines: 55
    - path: .mise/tasks/check/stack
      provides: Stack verification (merged from scripts/verify-phase1.sh)
      min_lines: 380
    - path: .mise/tasks/check/talos/metrics
      provides: Talos metrics verification (merged from scripts/verify-talos-metrics.sh)
      min_lines: 110
    - path: .mise/tasks/backup/talos/config
      provides: Talos config backup (merged from scripts/backup-talos-config.sh)
      min_lines: 55
    - path: .mise/tasks/deploy/talos/config
      provides: Talos metrics config deployment (merged from scripts/apply-talos-metrics-config.sh)
      min_lines: 145
  key_links:
    - from: mise tasks
      to: lib/output.sh, lib/checks.sh, lib/talos.sh
      via: source statements
      pattern: "source.*lib/.*\.sh"
---

<objective>
Merge all shell scripts from scripts/ directory into their corresponding mise tasks in .mise/tasks/, replacing script calls with inline content.

Purpose: Consolidate tooling by making mise tasks self-contained, eliminating the scripts/ directory dependency.
Output: 7 self-contained mise tasks, empty scripts/ directory ready for deletion.
</objective>

<execution_context>
@/home/tarax/.config/opencode/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.mise/tasks/check/preflight
@.mise/tasks/secrets/age/init
@.mise/tasks/check/prometheus
@.mise/tasks/check/stack
@scripts/preflight.sh
@scripts/secrets-age-init.sh
@scripts/verify-prometheus.sh
@scripts/verify-phase1.sh
@scripts/verify-talos-metrics.sh
@scripts/backup-talos-config.sh
@scripts/apply-talos-metrics-config.sh
</context>

<tasks>

<task type="auto">
  <name>Task 1: Merge existing task scripts (check/preflight, secrets/age/init, check/prometheus, check/stack)</name>
  <files>
    .mise/tasks/check/preflight
    .mise/tasks/secrets/age/init
    .mise/tasks/check/prometheus
    .mise/tasks/check/stack
  </files>
  <action>
Replace the script call (./scripts/XXX.sh) with the actual content from each corresponding script file.

For .mise/tasks/check/preflight:
- Replace `./scripts/preflight.sh` with full content from scripts/preflight.sh
- Preserve the [MISE] header comment
- Add set -euo pipefail at the top after shebang
- Ensure library sourcing paths use correct relative paths from .mise/tasks/

For .mise/tasks/secrets/age/init:
- Replace `./scripts/secrets-age-init.sh` with full content from scripts/secrets-age-init.sh
- Preserve the [MISE] header comment
- The script uses $KEY_FILE, $PUB_FILE, $KEY_DIR variables - ensure these are documented or defaulted

For .mise/tasks/check/prometheus:
- Replace `./scripts/verify-prometheus.sh` with full content from scripts/verify-prometheus.sh
- Preserve the [MISE] header comment
- The script uses jq for JSON processing - ensure this is available via mise

For .mise/tasks/check/stack:
- This currently has inline content, NOT a script call
- Replace current simple content with full content from scripts/verify-phase1.sh
- This is the comprehensive Phase 1 verification script (382 lines)
- Preserve the [MISE] description

After merging, delete the source scripts:
- rm scripts/preflight.sh
- rm scripts/secrets-age-init.sh
- rm scripts/verify-prometheus.sh
- rm scripts/verify-phase1.sh
  </action>
  <verify>
# Check that scripts were removed
[ ! -f scripts/preflight.sh ] && [ ! -f scripts/secrets-age-init.sh ] && [ ! -f scripts/verify-prometheus.sh ] && [ ! -f scripts/verify-phase1.sh ] && echo "Scripts removed OK"

# Check that tasks don't call scripts anymore
grep -l "scripts/" .mise/tasks/check/preflight .mise/tasks/secrets/age/init .mise/tasks/check/prometheus .mise/tasks/check/stack 2>/dev/null && echo "ERROR: Still references scripts" || echo "No script references OK"

# Check files have substantial content
wc -l .mise/tasks/check/preflight .mise/tasks/secrets/age/init .mise/tasks/check/prometheus .mise/tasks/check/stack
  </verify>
  <done>
All 4 existing tasks contain merged script content, no script calls remain, source scripts deleted.
  </done>
</task>

<task type="auto">
  <name>Task 2: Create new task directories and merge remaining scripts</name>
  <files>
    .mise/tasks/check/talos/metrics
    .mise/tasks/backup/talos/config
    .mise/tasks/deploy/talos/config
  </files>
  <action>
Create new directory structure and merge remaining 3 scripts:

1. Create directories:
   - mkdir -p .mise/tasks/check/talos
   - mkdir -p .mise/tasks/backup/talos
   - mkdir -p .mise/tasks/deploy/talos

2. Create .mise/tasks/check/talos/metrics from scripts/verify-talos-metrics.sh:
   - Add shebang and [MISE] description="Verify Talos control plane metrics endpoints"
   - Include full script content (110 lines)
   - Ensure lib/output.sh and lib/talos.sh sourcing uses correct relative path: ../../lib/ or ../../../lib/

3. Create .mise/tasks/backup/talos/config from scripts/backup-talos-config.sh:
   - Add shebang and [MISE] description="Backup Talos machine configurations"
   - Include full script content (55 lines)
   - Ensure lib/output.sh sourcing uses correct relative path

4. Create .mise/tasks/deploy/talos/config from scripts/apply-talos-metrics-config.sh:
   - Add shebang and [MISE] description="Apply Talos control plane metrics configuration"
   - Include full script content (147 lines)
   - Ensure lib/output.sh and lib/talos.sh sourcing uses correct relative path
   - The script calls backup script - update to call the new mise task location or include backup logic inline
   - Check: line 114 calls "${SCRIPT_DIR}/backup-talos-config.sh" - change to call "mise run backup:talos:config" or similar

5. Delete the source scripts:
   - rm scripts/verify-talos-metrics.sh
   - rm scripts/backup-talos-config.sh
   - rm scripts/apply-talos-metrics-config.sh
  </action>
  <verify>
# Check directories exist
[ -d .mise/tasks/check/talos ] && [ -d .mise/tasks/backup/talos ] && [ -d .mise/tasks/deploy/talos ] && echo "Directories created OK"

# Check files exist and are executable
[ -x .mise/tasks/check/talos/metrics ] && [ -x .mise/tasks/backup/talos/config ] && [ -x .mise/tasks/deploy/talos/config ] && echo "Files created and executable OK"

# Check scripts were removed
[ ! -f scripts/verify-talos-metrics.sh ] && [ ! -f scripts/backup-talos-config.sh ] && [ ! -f scripts/apply-talos-metrics-config.sh ] && echo "Scripts removed OK"

# Check files have substantial content
wc -l .mise/tasks/check/talos/metrics .mise/tasks/backup/talos/config .mise/tasks/deploy/talos/config

# Check no script references remain
grep -l "scripts/" .mise/tasks/check/talos/metrics .mise/tasks/backup/talos/config .mise/tasks/deploy/talos/config 2>/dev/null && echo "ERROR: Still references scripts" || echo "No script references OK"
  </verify>
  <done>
3 new task directories created, 3 new tasks with merged content, no script references remain, source scripts deleted.
  </done>
</task>

<task type="auto">
  <name>Task 3: Verify scripts directory cleanup and mise task registration</name>
  <files>
    scripts/
  </files>
  <action>
Final cleanup and verification:

1. Check scripts/ directory status:
   - List remaining files in scripts/
   - If directory is empty (or only contains .gitkeep), remove all files
   - If any non-script files exist, leave them

2. Verify all tasks are properly registered with mise:
   - Run: mise tasks | grep -E "(check:preflight|secrets:age:init|check:prometheus|check:stack|check:talos:metrics|backup:talos:config|deploy:talos:config)"
   - All 7 tasks should appear in the list

3. Test task structure:
   - All files should have proper shebang (#!/usr/bin/env bash)
   - All files should have [MISE] description comment
   - All files should be executable (chmod +x)

4. Document any remaining files in scripts/ that couldn't be migrated (if any)
  </action>
  <verify>
# Check scripts directory
ls -la scripts/ 2>/dev/null || echo "Scripts directory empty or removed"

# Verify mise sees all tasks
mise tasks | grep -c "check:preflight\|secrets:age:init\|check:prometheus\|check:stack\|check:talos:metrics\|backup:talos:config\|deploy:talos:config" | grep -q "7" && echo "All 7 tasks registered in mise"

# Verify file permissions and headers
for task in .mise/tasks/check/preflight .mise/tasks/secrets/age/init .mise/tasks/check/prometheus .mise/tasks/check/stack .mise/tasks/check/talos/metrics .mise/tasks/backup/talos/config .mise/tasks/deploy/talos/config; do
  [ -x "$task" ] && head -1 "$task" | grep -q "#!/usr/bin/env bash" && grep -q "\[MISE\]" "$task" && echo "✓ $task OK"
done
  </verify>
  <done>
Scripts directory is empty or cleaned up, all 7 tasks registered with mise, all tasks have proper headers and permissions.
  </done>
</task>

</tasks>

<verification>
- All 7 scripts migrated from scripts/ to .mise/tasks/
- No script calls remain in any mise task
- All tasks have [MISE] description headers
- All tasks are executable
- Scripts directory is empty (only .gitkeep if needed)
- mise tasks command lists all 7 migrated tasks
</verification>

<success_criteria>
- Task 1: 4 existing mise tasks contain merged script content, 4 scripts removed
- Task 2: 3 new task directories created, 3 new tasks created with merged content, 3 scripts removed
- Task 3: scripts/ directory cleaned up, all tasks visible in `mise tasks`
- Zero scripts remain in scripts/ directory (except .gitkeep if present)
</success_criteria>

<output>
After completion, create `.planning/quick/11-merge-scripts-into-their-corresponding-m/11-SUMMARY.md`
</output>
