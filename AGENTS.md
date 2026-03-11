# AGENTS.md — Coding Guidelines for AI Agents


## Project Overview

This is a training/documentation project for Prometheus observability and orchestration.
It uses Talos Linux for Kubernetes cluster management and includes extensive documentation.


## Build/Lint/Test Commands


### Documentation Linting

```bash
# Lint all markdown files (primary command)
npx markdownlint-cli2 "**/*.md"

# Lint specific file
npx markdownlint-cli2 docs/config.md

# Fix auto-fixable issues
npx markdownlint-cli2 "**/*.md" --fix
```


### Environment, Tools and Tasks Management (via mise)

```bash
# Install tools defined in mise.toml
mise install

# Run talosctl
talosctl <command>

# Run kubectl
kubectl <command>
```


## Code Style Guidelines


### Markdown Documentation

**Formatting:**

- Use semantic line breaks (no hard line length limit - MD013 disabled)
- Files must end with single newline (MD047)
- Maximum 2 consecutive blank lines (MD012)
- Use backtick code fences with language tags (MD040, MD046, MD048)

**Headings:**

- Headings must have 2 blank lines above, 1 below (MD022)
- No trailing punctuation in headings except `!?` (MD026)
- Use sentence case for headings

**Lists:**

- Unordered list indent: 2 spaces (MD007)
- Ordered list indent: 4 spaces (MD007)
- No spaces after single-line list markers, 1 space after multi-line (MD030)
- Ordered list style: `one_or_ordered` (MD029)

**Emphasis:**

- Use `*italic*` not `_italic_` (MD049)
- Use `**bold**` not `__bold__` (MD050)

**Code Blocks:**

- Always specify language for syntax highlighting
- Use fenced blocks (```) not indented
- YAML, JSON, bash, Python and Ruby are common languages used

**MyST/Quarto Extensions:**

- Allow inline HTML for MyST/Quarto features (MD033 disabled)
- Use `:::note`, `:::warning` and other admonitions where appropriate
- Front matter `title:` satisfies first-line-h1 rule (MD041)


### YAML Configuration

**Style:**

- 2-space indentation
- Use single quotes for strings containing special characters
- Quote port numbers and version strings to avoid type coercion
- Group related configuration under logical keys

**Prometheus Configuration:**

- Recording rules use colon-separated naming: `app:metric:aggregation`
- Alert names use severity prefix: `WARN`, `ERR` or `CRIT`
- Always include `for` duration for alerts to avoid flapping
- Use `external_labels` for multi-datacenter identification


### Shell Commands in Documentation

**Style:**

- Use `$` prefix for shell examples when showing output
- Include expected output in code blocks where helpful
- Prefer `curl` with `-s` flag for API examples


## Naming Conventions


### Files and Directories

- Use kebab-case for multi-word filenames: `servicemonitor-traefik.yaml`
- Use leading underscore for partial/rule files: `_rec_app.yml`
- Keep manifests in `manifests/` directory
- Values files in `values/` directory


### Resources

- Prometheus instances: `prom10`, `prom20`, `prom01`
- Services use FQDN pattern: `dc01.prom.localhost`
- Docker Compose services and container names: lowercase with hyphens


### Labels and Selectors

- Use standard Kubernetes labels: `app.kubernetes.io/name`
- ServiceMonitor selector must match chart release label: `release: kube-prometheus-stack`


## Error Handling and Validation


### Documentation Quality

- Verify all code examples are tested and working
- Include expected output for API queries
- Use jq for JSON formatting in examples
- Add validation steps after configuration examples


### Prometheus Rules

- Always test recording rules with actual query
- Validate alert expression syntax
- Include severity level and description annotations
- Set appropriate evaluation intervals


## Project Structure

```text
.
├── docs/                    # Documentation (markdown)
│   ├── index.md
│   ├── config.md           # Main configuration guide
│   └── etude.md            # Study/comparative analysis
├── specs/                   # Specifications
│   ├── specs.md            # Exercise specifications
│   └── diagrams/           # Architecture diagrams
├── .talos/                   # Talos cluster configuration
│   ├── clusters/
│   └── talosconfig
├── .kube/                   # Kubernetes configs
├── mise.toml               # Tool definitions
└── .markdownlint-cli2.yaml  # Linting configuration
```


## Common Tasks


### Adding New Documentation

1. Create markdown file in appropriate directory
2. Follow heading hierarchy (start with H1)
3. Add to relevant section if part of series
4. Run markdownlint before committing


### Adding Prometheus Rules

1. Create in `config/prometheus/rules/common/`
2. Use descriptive filename with severity prefix for alerts
3. Test rules against live Prometheus instance
4. Document expected behavior in specs


### Kubernetes Manifests

1. Use ServiceMonitor for Prometheus scraping
2. Include proper labels for operator selection
3. Add PrometheusRule for alerts in same namespace
4. Test with `kubectl apply --dry-run=client`


<!-- vim: set ts=2 sts=2 sw=2 et endofline fixendofline spell spl=en : -->
