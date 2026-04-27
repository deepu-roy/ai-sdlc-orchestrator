#!/usr/bin/env bash
# Hook: PostToolUse on all tools
# Purpose: Append one JSON line per tool call to .claude/trace/<run-id>.jsonl.
# Never fails the turn.

set -uo pipefail

payload=$(cat)

# Derive a run id. Prefer env var (set by pipeline) else date+pid.
run_id="${CLAUDE_RUN_ID:-${BUILD_BUILDID:-local-$(date -u +%Y%m%d-%H%M%S)-$$}}"

trace_dir=".claude/trace"
mkdir -p "$trace_dir" 2>/dev/null || exit 0

tool=$(echo "$payload" | jq -r '.tool_name // "unknown"')
subagent=$(echo "$payload" | jq -r '.subagent_type // .subagent // "main"')
file=$(echo "$payload" | jq -r '.tool_input.file_path // empty')
cmd=$(echo "$payload" | jq -r '.tool_input.command // empty' | head -c 200)
status=$(echo "$payload" | jq -r '.tool_response.success // .success // "unknown"')

jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg run "$run_id" \
  --arg sa "$subagent" \
  --arg t "$tool" \
  --arg f "$file" \
  --arg c "$cmd" \
  --arg s "$status" \
  '{ts:$ts, run_id:$run, subagent:$sa, tool:$t, file:$f, command:$c, status:$s}' \
  >> "$trace_dir/$run_id.jsonl" 2>/dev/null || true

exit 0
