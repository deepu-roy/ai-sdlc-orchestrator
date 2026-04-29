#!/usr/bin/env bash
# Normalize hook input between Claude Code and GitHub Copilot.
#
# Claude Code sends:  { "tool_name": "Edit", "tool_input": { "file_path": "..." }, ... }
# Copilot sends:      { "toolName": "edit", "toolArgs": "{\"path\":\"...\"}", "toolResult": {...}, ... }
#
# This shim reads stdin, detects format, normalizes to Claude Code's shape,
# and outputs to stdout. Downstream scripts consume the Claude Code shape.
#
# Mappings applied:
#   toolName               → tool_name
#   toolArgs (JSON string) → tool_input (object)
#   toolArgs.path|filePath → tool_input.file_path (canonical key downstream scripts expect)
#   toolResult             → tool_response { success, output } (postToolUse)
#
# Usage: cat | .github/hooks/normalize-input.sh | .github/hooks/block-sensitive-files.sh

set -euo pipefail

payload=$(cat)

# Detect Copilot format: has "toolName" but not "tool_name"
if echo "$payload" | jq -e '.toolName' >/dev/null 2>&1 && \
   ! echo "$payload" | jq -e '.tool_name' >/dev/null 2>&1; then

  tool_name=$(echo "$payload" | jq -r '.toolName // "unknown"')
  tool_args_raw=$(echo "$payload" | jq -r '.toolArgs // "{}"')

  # toolArgs arrives as a JSON string in Copilot — parse it into an object
  if echo "$tool_args_raw" | jq -e '.' >/dev/null 2>&1; then
    tool_input="$tool_args_raw"
  else
    tool_input="{}"
  fi

  # Normalize file path: Copilot may send .path or .filePath instead of .file_path
  file_path=$(echo "$tool_input" | jq -r '.file_path // .path // .filePath // empty')
  if [[ -n "$file_path" ]]; then
    tool_input=$(echo "$tool_input" | jq -c --arg fp "$file_path" '. + {"file_path": $fp}')
  fi

  # Reconstruct in Claude Code shape
  normalized=$(echo "$payload" | jq -c \
    --arg tn "$tool_name" \
    --argjson ti "$tool_input" \
    '. + { "tool_name": $tn, "tool_input": $ti }')

  # Normalize toolResult → tool_response (postToolUse only)
  if echo "$payload" | jq -e '.toolResult' >/dev/null 2>&1; then
    echo "$normalized" | jq -c '
      . + {
        "tool_response": {
          "success": (.toolResult.resultType == "success"),
          "output": (.toolResult.textResultForLlm // "")
        }
      }'
  else
    echo "$normalized"
  fi
else
  # Already Claude Code format — pass through
  echo "$payload"
fi
