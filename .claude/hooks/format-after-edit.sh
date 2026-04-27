#!/usr/bin/env bash
# Hook: PostToolUse on Edit|Write
# Purpose: Run the project formatter on the edited file.
# Reads the formatter command from .claude/project/PROFILE.md.
# Never fails the turn — logs and returns 0 even on formatter error.

set -uo pipefail

payload=$(cat)
file=$(echo "$payload" | jq -r '.tool_input.file_path // empty')
[[ -z "$file" ]] && exit 0
[[ ! -f "$file" ]] && exit 0

profile=".claude/project/PROFILE.md"
[[ ! -f "$profile" ]] && exit 0

run() {
  # shellcheck disable=SC2086
  $1 "$file" >/dev/null 2>&1 || {
    mkdir -p .claude/trace
    printf '{"ts":"%s","file":"%s","formatter":"%s","status":"failed"}\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$file" "$1" \
      >> .claude/trace/format-failures.jsonl
  }
}

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.md|*.yml|*.yaml)
    if command -v pnpm >/dev/null 2>&1 && [[ -f package.json ]]; then
      run "pnpm prettier --write --log-level=silent"
    elif command -v npx >/dev/null 2>&1; then
      run "npx --yes prettier --write --log-level=silent"
    fi
    ;;
  *.cs)
    if command -v dotnet >/dev/null 2>&1; then
      run "dotnet format --include"
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      run "ruff format"
    elif command -v black >/dev/null 2>&1; then
      run "black --quiet"
    fi
    ;;
  *.go)
    if command -v gofmt >/dev/null 2>&1; then
      run "gofmt -w"
    fi
    ;;
esac

exit 0
