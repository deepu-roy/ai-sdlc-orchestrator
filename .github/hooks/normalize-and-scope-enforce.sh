#!/usr/bin/env bash
# Copilot preToolUse hook: normalize input → run scope-enforce
# Only acts on file-writing tools (replaces the removed matcher.toolName filter).
set -euo pipefail

normalized=$(cat | .github/hooks/normalize-input.sh)

# Filter: only check file-writing tools
tool_name=$(echo "$normalized" | jq -r '.tool_name // empty' | tr '[:upper:]' '[:lower:]')
case "$tool_name" in
  edit|create|write) ;;
  *) exit 0 ;;
esac

result=$(echo "$normalized" | .github/hooks/scope-enforce.sh 2>&1) && exit_code=$? || exit_code=$?

if [[ $exit_code -eq 2 ]]; then
  jq -cn --arg r "$result" '{permissionDecision:"deny",permissionDecisionReason:$r}'
elif [[ $exit_code -ne 0 ]]; then
  jq -cn --arg r "Scope enforcement error: $result" '{permissionDecision:"deny",permissionDecisionReason:$r}'
fi
