#!/usr/bin/env bash
# Shared linting utilities for scripts and tasks

# Run markdownlint on specified files or all markdown
lint_markdown() {
  local files=("${@:-**/*.md}")
  mise exec -- markdownlint-cli2 "${files[@]}"
}

# Run markdownlint with auto-fix
lint_markdown_fix() {
  local files=("${@:-**/*.md}")
  mise exec -- markdownlint-cli2 "${files[@]}" --fix
}

# Run shellcheck on specified shell scripts
lint_shell() {
  local files=("${@}")
  if [[ ${#files[@]} -eq 0 ]]; then
    # Find all .sh files excluding node_modules and .git
    mapfile -t files < <(
      find . -name "*.sh" \
        -not -path "./node_modules/*" \
        -not -path "./.helm/*" \
        -not -path "./.kube/*" \
        -not -path "./.vagrant/*" \
        -not -path "./.ansible/*" \
        -not -path "./.git/*"
    )
  fi
  mise exec -- shellcheck "${files[@]}"
}

# Run shellcheck with severity warning
lint_shell_strict() {
  local files=("${@}")
  if [[ ${#files[@]} -eq 0 ]]; then
    mapfile -t files < <(find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*")
  fi
  mise exec -- shellcheck --severity=warning "${files[@]}"
}

# Check if tools are available
lint_check_tools() {
  command -v mise >/dev/null 2>&1 || {
    echo "mise not found"
    return 1
  }
  mise exec -- markdownlint-cli2 --version >/dev/null 2>&1 || {
    echo "markdownlint-cli2 not available via mise"
    return 1
  }
  mise exec -- shellcheck --version >/dev/null 2>&1 || {
    echo "shellcheck not available via mise"
    return 1
  }
  echo "All linting tools available"
  return 0
}
