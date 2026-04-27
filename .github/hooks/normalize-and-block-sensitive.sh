#!/usr/bin/env bash
# Copilot preToolUse hook: normalize input → run block-sensitive-files
# Only acts on file-writing tools (replaces the removed matcher.toolName filter).
# Exit codes: 0=allow, non-zero=deny
# For Copilot, denial is communicated via JSON on stdout.
set -euo pipefail

normalized=$(cat | .github/hooks/normalize-input.sh)

# Filter: only check file-writing tools
tool_name=$(echo "$normalized" | jq -r '.tool_name // empty' | tr '[:upper:]' '[:lower:]')
case "$tool_name" in
  edit|create|write) ;;
  *) exit 0 ;;
esac

result=$(echo "$normalized" | .claude/hooks/block-sensitive-files.sh 2>&1) && exit_code=$? || exit_code=$?

if [[ $exit_code -eq 2 ]]; then
  # Claude hook exit 2 = block. Translate to Copilot deny format.
  jq -cn --arg r "$result" '{permissionDecision:"deny",permissionDecisionReason:$r}'
elif [[ $exit_code -ne 0 ]]; then
  jq -cn --arg r "Hook error: $result" '{permissionDecision:"deny",permissionDecisionReason:$r}'
fi
# exit 0 = allow (no output needed for Copilot)
