#!/usr/bin/env bash
# Copilot postToolUse hook: normalize input → run format-after-edit
# Only acts on file-writing tools (replaces the removed matcher.toolName filter).
# Never denies — just formats.
set -uo pipefail

normalized=$(cat | .github/hooks/normalize-input.sh)

# Filter: only format after file-writing tools
tool_name=$(echo "$normalized" | jq -r '.tool_name // empty' | tr '[:upper:]' '[:lower:]')
case "$tool_name" in
  edit|create|write) ;;
  *) exit 0 ;;
esac

echo "$normalized" | .claude/hooks/format-after-edit.sh
exit 0
