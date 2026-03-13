---
phase: quick
plan: 9
type: execute
wave: 1
depends_on: []
files_modified:
  - .mise/tasks/secrets/age-init
  - .mise/tasks/secrets/init
  - .mise/tasks/secrets/edit
  - .mise/tasks/cluster/up
  - .mise/tasks/cluster/destroy
  - .mise/tasks/cluster/context/list
  - .mise/tasks/cluster/context/set
  - .mise/tasks/cluster/context/remove
  - .mise/tasks/check/preflight
  - .mise/tasks/lint/md
  - .mise/tasks/lint/md-fix
  - .mise/tasks/lint/helmfile
  - .mise/tasks/lint/values
  - .mise/tasks/lint/values-strict
  - .mise/tasks/lint/template
  - .mise/tasks/template/stack
  - .mise/tasks/install/helm-plugins
  - .mise/tasks/deploy/prom-crds
  - .mise/tasks/deploy/phase1
  - .mise/tasks/deploy/stack-quick
  - .mise/tasks/deploy/stack-diff
  - .mise/tasks/deploy/stack-apply
  - .mise/tasks/check/validate-stack
  - .mise/tasks/verify/stack
  - .mise/tasks/verify/retention
  - .mise/tasks/verify/grafana
  - .mise/tasks/verify/prometheus
  - .mise/tasks/verify/alertmanager
  - mise.toml
autonomous: true
requirements:
  - REFACTOR-01
must_haves:
  truths:
    - All 28 inline tasks from mise.toml are converted to executable file tasks
    - Each file task contains proper MISE metadata directives
    - All file tasks have executable permissions (chmod +x)
    - mise.toml inline task definitions are removed (replaced with file = references)
    - Task functionality is preserved during conversion
    - Task can be run via `mise run <task-name>` without errors
  artifacts:
    - path: ".mise/tasks/secrets/age-init"
      provides: "Age encryption keys initialization"
      min_lines: 5
    - path: ".mise/tasks/secrets/init"
      provides: "Encrypted env file creation"
      min_lines: 5
    - path: ".mise/tasks/secrets/edit"
      provides: "SOPS encrypted file editing"
      min_lines: 5
    - path: ".mise/tasks/cluster/up"
      provides: "Talos cluster creation"
      min_lines: 5
    - path: ".mise/tasks/cluster/destroy"
      provides: "Talos cluster destruction"
      min_lines: 5
    - path: ".mise/tasks/cluster/context/list"
      provides: "List Talos contexts"
      min_lines: 5
    - path: ".mise/tasks/cluster/context/set"
      provides: "Set Talos context"
      min_lines: 10
    - path: ".mise/tasks/cluster/context/remove"
      provides: "Remove Talos context"
      min_lines: 10
    - path: ".mise/tasks/check/preflight"
      provides: "Pre-deployment checks"
      min_lines: 5
    - path: ".mise/tasks/lint/md"
      provides: "Markdown linting"
      min_lines: 5
    - path: ".mise/tasks/lint/md-fix"
      provides: "Markdown linting with auto-fix"
      min_lines: 5
    - path: ".mise/tasks/lint/helmfile"
      provides: "Helmfile configuration linting"
      min_lines: 5
    - path: ".mise/tasks/lint/values"
      provides: "YAML values linting"
      min_lines: 10
    - path: ".mise/tasks/lint/values-strict"
      provides: "Helm schema validation"
      min_lines: 15
    - path: ".mise/tasks/lint/template"
      provides: "Template YAML validation"
      min_lines: 15
    - path: ".mise/tasks/template/stack"
      provides: "Stack templating"
      min_lines: 10
    - path: ".mise/tasks/install/helm-plugins"
      provides: "Helm plugin installation"
      min_lines: 10
    - path: ".mise/tasks/deploy/prom-crds"
      provides: "Prometheus CRDs deployment"
      min_lines: 5
    - path: ".mise/tasks/deploy/phase1"
      provides: "Phase 1 deployment workflow"
      min_lines: 20
    - path: ".mise/tasks/deploy/stack-quick"
      provides: "Quick stack deployment"
      min_lines: 5
    - path: ".mise/tasks/deploy/stack-diff"
      provides: "Stack diff preview"
      min_lines: 15
    - path: ".mise/tasks/deploy/stack-apply"
      provides: "Stack apply with confirmation"
      min_lines: 5
    - path: ".mise/tasks/check/validate-stack"
      provides: "Stack validation"
      min_lines: 10
    - path: ".mise/tasks/verify/stack"
      provides: "Stack deployment verification"
      min_lines: 10
    - path: ".mise/tasks/verify/retention"
      provides: "Prometheus retention verification"
      min_lines: 10
    - path: ".mise/tasks/verify/grafana"
      provides: "Grafana verification"
      min_lines: 10
    - path: ".mise/tasks/verify/prometheus"
      provides: "Prometheus metrics verification"
      min_lines: 5
    - path: ".mise/tasks/verify/alertmanager"
      provides: "Alertmanager verification"
      min_lines: 10
    - path: "mise.toml"
      provides: "Updated mise configuration with file task references"
      contains: "file = \".mise/tasks/"
  key_links:
    - from: "mise.toml"
      to: ".mise/tasks/"
      via: "file = references"
      pattern: "file = \".mise/tasks/"
---

<objective>
Refactor all 28 inline mise tasks from mise.toml into individual executable file tasks organized in the .mise/tasks/ directory tree.

Purpose: Improve maintainability, enable task reuse, follow mise best practices for task organization, and allow task dependencies via the `depends` directive.
Output: 28 executable file tasks in appropriate subdirectories + updated mise.toml with file task references.
</objective>

<execution_context>
@/home/tarax/.config/opencode/get-shit-done/workflows/execute-plan.md
@/home/tarax/.config/opencode/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@mise.toml
@.mise/tasks/deploy/stack (reference template for file task structure)
</context>

<tasks>

<task type="auto">
  <name>Create all 28 file tasks in .mise/tasks/ directory tree</name>
  <files>
    .mise/tasks/secrets/age-init
    .mise/tasks/secrets/init
    .mise/tasks/secrets/edit
    .mise/tasks/cluster/up
    .mise/tasks/cluster/destroy
    .mise/tasks/cluster/context/list
    .mise/tasks/cluster/context/set
    .mise/tasks/cluster/context/remove
    .mise/tasks/check/preflight
    .mise/tasks/lint/md
    .mise/tasks/lint/md-fix
    .mise/tasks/lint/helmfile
    .mise/tasks/lint/values
    .mise/tasks/lint/values-strict
    .mise/tasks/lint/template
    .mise/tasks/template/stack
    .mise/tasks/install/helm-plugins
    .mise/tasks/deploy/prom-crds
    .mise/tasks/deploy/phase1
    .mise/tasks/deploy/stack-quick
    .mise/tasks/deploy/stack-diff
    .mise/tasks/deploy/stack-apply
    .mise/tasks/check/validate-stack
    .mise/tasks/verify/stack
    .mise/tasks/verify/retention
    .mise/tasks/verify/grafana
    .mise/tasks/verify/prometheus
    .mise/tasks/verify/alertmanager
  </files>
  <action>
    Convert each inline task from mise.toml into an executable file task following the established pattern in .mise/tasks/deploy/stack:

    Pattern for file tasks:
    1. Shebang: #!/usr/bin/env bash
    2. MISE directives in comments: # [MISE] description="..."
    3. Use set -e for error handling
    4. Preserve original logic exactly (copy run commands)
    5. For multi-line run arrays, join with newlines
    6. Make file executable with chmod +x

    Task conversion details:

    secrets/age-init:
    - description: "Initialize age encryption keys for SOPS"
    - run: ./scripts/secrets-age-init.sh

    secrets/init:
    - description: "Create encrypted .env.enc file with placeholder secrets"
    - run: ./scripts/secrets-init.sh

    secrets/edit:
    - description: "Edit encrypted secrets file"
    - run: sops .env.yaml

    cluster/up:
    - description: "Create Talos cluster using Docker"
    - quiet = true
    - run: talosctl cluster create docker --name "$TALOS_CLUSTER_NAME" --state "$TALOS_STATE_DIR" --workers $TALOS_WORKER_COUNT

    cluster/destroy:
    - description: "Destroy Talos cluster and remove context"
    - quiet = true
    - Multi-line array:
      1. talosctl cluster destroy --name "$TALOS_CLUSTER_NAME"
      2. yq -i 'del(.contexts[env(TALOS_CONTEXT)])' "$TALOSCONFIG" 2>/dev/null || true

    cluster/context/list:
    - description: "List all Talos contexts and show current"
    - quiet = true
    - run: talosctl config contexts

    cluster/context/set:
    - description: "Set current Talos context"
    - quiet = true
    - Has usage argument: arg '<context>' help='Context name to switch to'
    - run: talosctl config context "${usage_context}"
    - Note: File tasks use $1 for first argument instead of ${usage_context}

    cluster/context/remove:
    - description: "Remove a Talos context from config"
    - quiet = true
    - Has usage argument: arg '<context>' help='Context name to remove'
    - run: CONTEXT="${usage_context}" yq -i "del(.contexts[env(CONTEXT)])" "$TALOSCONFIG"
    - Note: Convert to use $1 for argument

    check/preflight:
    - description: "Run preflight checks before deployment"
    - run: ./scripts/preflight.sh

    lint/md:
    - description: "Lint all markdown files"
    - run: npx markdownlint-cli2 '**/*.md'

    lint/md-fix:
    - description: "Lint and auto-fix markdown files"
    - run: npx markdownlint-cli2 '**/*.md' --fix

    lint/helmfile:
    - description: "Lint Helmfile configuration"
    - run: helmfile -f helmfile.yaml lint

    lint/values:
    - description: "Lint all Phase 01-02 values YAML files"
    - Multi-line heredoc with for loop over values files

    lint/values-strict:
    - description: "Strict lint of Phase 01-02 values with Helm schema validation"
    - Complex multi-line with temp dir, helm pull, helm lint

    lint/template:
    - description: "Lint the templated YAML for syntax errors"
    - Multi-line with temp file, helmfile template, yq validation

    template/stack:
    - description: "Template kube-prometheus-stack without deploying"
    - Multi-line with temp file, helmfile template, wc -l output

    install/helm-plugins:
    - description: "Install required Helm plugins (helm-diff)"
    - Multi-line conditional check for plugin installation

    deploy/prom-crds:
    - description: "Sync CRDs release via Helmfile"
    - run: helmfile -f helmfile.yaml -l name=kube-prometheus-stack-crds sync

    deploy/phase1:
    - description: "Run complete Phase 1 deployment workflow (preflight → lint → deploy CRDs)"
    - Multi-line array of 4 echo + mise run commands
    - Use mise run commands (not mise run task_name)

    deploy/stack-quick:
    - description: "Deploy main kube-prometheus-stack only (CRDs must exist)"
    - run: helmfile -f helmfile.yaml -l name=kube-prometheus-stack sync

    deploy/stack-diff:
    - description: "Show diff before deploying stack"
    - Multi-line with conditional plugin check and helmfile diff

    deploy/stack-apply:
    - description: "Apply stack with automatic confirmation"
    - run: helmfile -f helmfile.yaml -l name=kube-prometheus-stack apply

    check/validate-stack:
    - description: "Validate stack configuration (lint + template check)"
    - Multi-line array calling: lint_helmfile, lint_values, template_stack, lint_template
    - Add depends metadata: depends = ["lint_helmfile", "lint_values", "template_stack", "lint_template"]

    verify/stack:
    - description: "Verify Phase 01-02 deployment is healthy"
    - Multi-line with kubectl get pods and services

    verify/retention:
    - description: "Verify Prometheus retention configuration"
    - Multi-line with kubectl get prometheus and conditional output

    verify/grafana:
    - description: "Verify Grafana NodePort is accessible"
    - Multi-line with service check, node IP extraction, URL output

    verify/prometheus:
    - description: "Verify Prometheus is collecting metrics"
    - run: ./scripts/verify-prometheus.sh

    verify/alertmanager:
    - description: "Verify Alertmanager is operational"
    - Multi-line with operator pod lookup and wget/jq check

    IMPORTANT NOTES:
    1. For tasks with "usage" arguments (ctx_set, ctx_remove): use $1 in file tasks
    2. For "quiet = true" tasks: add "# [MISE] quiet = true" directive
    3. For multi-line run arrays: convert to bash script with proper error handling
    4. All files must be chmod +x after creation
    5. Follow exact naming convention: task-name in inline becomes task_name in file path
  </action>
  <verify>
    # Verify all 28 files exist and are executable
    ls -la .mise/tasks/secrets/age-init .mise/tasks/secrets/init .mise/tasks/secrets/edit
    ls -la .mise/tasks/cluster/up .mise/tasks/cluster/destroy
    ls -la .mise/tasks/cluster/context/list .mise/tasks/cluster/context/set .mise/tasks/cluster/context/remove
    ls -la .mise/tasks/check/preflight .mise/tasks/lint/md .mise/tasks/lint/md-fix .mise/tasks/lint/helmfile
    ls -la .mise/tasks/lint/values .mise/tasks/lint/values-strict .mise/tasks/lint/template .mise/tasks/template/stack
    ls -la .mise/tasks/install/helm-plugins .mise/tasks/deploy/prom-crds .mise/tasks/deploy/phase1
    ls -la .mise/tasks/deploy/stack-quick .mise/tasks/deploy/stack-diff .mise/tasks/deploy/stack-apply
    ls -la .mise/tasks/check/validate-stack .mise/tasks/verify/stack .mise/tasks/verify/retention
    ls -la .mise/tasks/verify/grafana .mise/tasks/verify/prometheus .mise/tasks/verify/alertmanager
    # Spot check file content has proper structure
    head -5 .mise/tasks/deploy/stack .mise/tasks/deploy/phase1 .mise/tasks/check/validate-stack
  </verify>
  <done>
    All 28 file tasks exist in correct directories with executable permissions, proper shebang, MISE metadata, and correct script content matching original inline tasks.
  </done>
</task>

<task type="auto">
  <name>Update mise.toml to replace inline tasks with file task references</name>
  <files>mise.toml</files>
  <action>
    Remove all 28 inline task definitions from mise.toml and replace with file task references.

    Tasks to convert (remove [tasks.X] sections, add [tasks."X"] with file = references):

    1. secrets-age-init → [tasks."secrets:age-init"] file = ".mise/tasks/secrets/age-init"
    2. secrets-init → [tasks."secrets:init"] file = ".mise/tasks/secrets/init"
    3. secrets-edit → [tasks."secrets:edit"] file = ".mise/tasks/secrets/edit"
    4. cls_up → [tasks."cluster:up"] file = ".mise/tasks/cluster/up"
    5. cls_destroy → [tasks."cluster:destroy"] file = ".mise/tasks/cluster/destroy"
    6. ctx_list → [tasks."cluster:context:list"] file = ".mise/tasks/cluster/context/list"
    7. ctx_set → [tasks."cluster:context:set"] file = ".mise/tasks/cluster/context/set"
    8. ctx_remove → [tasks."cluster:context:remove"] file = ".mise/tasks/cluster/context/remove"
    9. check_preflight → [tasks."check:preflight"] file = ".mise/tasks/check/preflight"
    10. lint_md → [tasks."lint:md"] file = ".mise/tasks/lint/md"
    11. lint_md_fix → [tasks."lint:md-fix"] file = ".mise/tasks/lint/md-fix"
    12. lint_helmfile → [tasks."lint:helmfile"] file = ".mise/tasks/lint/helmfile"
    13. install_helm_plugins → [tasks."install:helm-plugins"] file = ".mise/tasks/install/helm-plugins"
    14. deploy_prom_crds → [tasks."deploy:prom-crds"] file = ".mise/tasks/deploy/prom-crds"
    15. deploy_phase1 → [tasks."deploy:phase1"] file = ".mise/tasks/deploy/phase1"
    16. lint_values → [tasks."lint:values"] file = ".mise/tasks/lint/values"
    17. lint_values_strict → [tasks."lint:values-strict"] file = ".mise/tasks/lint/values-strict"
    18. template_stack → [tasks."template:stack"] file = ".mise/tasks/template/stack"
    19. lint_template → [tasks."lint:template"] file = ".mise/tasks/lint/template"
    20. validate_stack → [tasks."check:validate-stack"] file = ".mise/tasks/check/validate-stack"
    21. deploy_stack_quick → [tasks."deploy:stack-quick"] file = ".mise/tasks/deploy/stack-quick"
    22. deploy_stack_diff → [tasks."deploy:stack-diff"] file = ".mise/tasks/deploy/stack-diff"
    23. deploy_stack_apply → [tasks."deploy:stack-apply"] file = ".mise/tasks/deploy/stack-apply"
    24. verify_stack → [tasks."verify:stack"] file = ".mise/tasks/verify/stack"
    25. verify_retention → [tasks."verify:retention"] file = ".mise/tasks/verify/retention"
    26. verify_grafana → [tasks."verify:grafana"] file = ".mise/tasks/verify/grafana"
    27. verify_prometheus → [tasks."verify:prometheus"] file = ".mise/tasks/verify/prometheus"
    28. verify_alertmanager → [tasks."verify:alertmanager"] file = ".mise/tasks/verify/alertmanager"

    IMPORTANT NOTES:
    1. Keep existing file tasks unchanged (deploy:stack, lint:all, verify:wave1)
    2. Use colon notation for namespaced tasks (e.g., "check:preflight" not "check_preflight")
    3. Ensure proper TOML formatting with quotes around task names containing colons
    4. Remove all description, run, quiet, usage lines from old inline definitions
    5. Preserve all [settings], [tools], [env] sections exactly as they are
    6. Keep all env var definitions and tool versions unchanged
    7. Verify file paths are correct relative to project root
  </action>
  <verify>
    # Verify TOML syntax is valid
    yq eval '.' mise.toml > /dev/null && echo "TOML syntax valid"
    # Check that inline task sections are removed (should not see [tasks.X] with run =)
    grep -E '^\[tasks\.' mise.toml | head -20
    # Verify file task references exist
    grep 'file = "\.mise/tasks/' mise.toml | wc -l
    # Verify no old inline task names remain as section headers
    ! grep -E '\[tasks\.secrets-age-init\]' mise.toml
    ! grep -E '\[tasks\.cls_up\]' mise.toml
  </verify>
  <done>
    mise.toml contains no inline task definitions, all 28 tasks converted to file references with colon namespacing, TOML syntax valid, all [settings], [tools], [env] sections preserved.
  </done>
</task>

<task type="auto">
  <name>Validate task functionality with mise run commands</name>
  <files>mise.toml</files>
  <action>
    Verify key tasks work correctly by running mise commands to validate the refactoring.

    Test commands to run:
    1. mise tasks (list all tasks - should show all 28 file tasks)
    2. mise run check:preflight --help (verify task is recognized)
    3. mise run lint:md --help (verify task is recognized)

    IMPORTANT: Do NOT actually run tasks that would execute real operations (like cluster up, deploy, etc.).
    Only validate that mise recognizes the tasks and can parse them correctly.

    If validation fails, identify which task has issues and fix it.
  </action>
  <verify>
    # List all tasks to verify they are recognized
    mise tasks | grep -E "(secrets:|cluster:|check:|lint:|install:|deploy:|template:|verify:)" | wc -l
    # Should show at least 28 tasks
    # Verify specific task help works
    mise run check:preflight --help 2>&1 | head -5
  </verify>
  <done>
    All tasks are recognized by mise (mise tasks lists them), task help can be displayed, and no parsing errors occur.
  </done>
</task>

</tasks>

<verification>
Overall verification steps:
1. All 28 files exist in .mise/tasks/ with correct directory structure
2. All files have executable permissions
3. mise.toml has valid TOML syntax
4. All inline task definitions removed and replaced with file references
5. mise tasks lists all converted tasks
6. Task names use colon namespacing consistently
7. Original functionality preserved (scripts called, commands executed)
8. No broken task references or missing files
</verification>

<success_criteria>
- 28 file tasks created in .mise/tasks/ directory tree
- Each task has proper shebang, MISE metadata, and executable permissions
- mise.toml updated to use file = references for all 28 tasks
- Tasks use colon namespacing (e.g., "check:preflight", "cluster:up")
- mise tasks command lists all converted tasks
- All original task logic preserved exactly
- No inline run commands remain for converted tasks
- TOML syntax validation passes
</success_criteria>

<output>
After completion, create `.planning/quick/9-refactor-all-mise-inline-tasks-into-file/9-SUMMARY.md`

Include:
- List of all 28 tasks converted with their new file paths
- Any notable conversion details (argument handling, quiet flags, dependencies)
- Validation results showing mise tasks command output
- Reference to updated mise.toml structure
</output>
