#!/usr/bin/env bash
# Hook: PreToolUse on Edit|Write
# Purpose: Enforce that a subagent only writes within its declared scope.
# Reads .claude/agents/scope-map.json. If the caller is the main agent (no subagent),
# this hook is a no-op (the main agent operates under block-sensitive-files only).
# Exit 2 = block.

set -euo pipefail

payload=$(cat)
file=$(echo "$payload" | jq -r '.tool_input.file_path // empty')
subagent=$(echo "$payload" | jq -r '.subagent_type // .subagent // empty')

# No file path or no subagent context — pass through.
[[ -z "$file" ]] && exit 0
[[ -z "$subagent" ]] && exit 0

scope_file=".claude/agents/scope-map.json"
[[ ! -f "$scope_file" ]] && exit 0

file="${file#./}"

# Read scopes for this subagent.
denied=$(jq -r --arg s "$subagent" '.[$s].denied // [] | .[]' "$scope_file")
read_only=$(jq -r --arg s "$subagent" '.[$s].read_only // [] | .[]' "$scope_file")
read_write=$(jq -r --arg s "$subagent" '.[$s].read_write // [] | .[]' "$scope_file")

# Subagent not in map — permissive (treat as main agent).
if ! jq -e --arg s "$subagent" '.[$s]' "$scope_file" >/dev/null 2>&1; then
  exit 0
fi

glob_match() {
  # $1 = pattern, $2 = path. Uses bash extglob.
  local pat="$1" p="$2"
  # Convert ** and * to a regex-ish comparison using bash globbing.
  shopt -s extglob globstar nullglob
  [[ "$p" == $pat ]]
}

log_and_block() {
  local reason="$1"
  mkdir -p .claude/trace
  printf '{"ts":"%s","subagent":"%s","file":"%s","reason":"%s"}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$subagent" "$file" "$reason" \
    >> ".claude/trace/scope-blocks.jsonl"
  echo "BLOCKED by scope-enforce: $file" >&2
  echo "Subagent '$subagent' $reason" >&2
  echo "Return a blocker in your JSON summary instead of editing out of scope." >&2
  exit 2
}

# 1. Denied wins.
while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  if glob_match "$pat" "$file"; then
    log_and_block "is denied from writing $pat"
  fi
done <<< "$denied"

# 2. Read-only: writes are not allowed.
while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  if glob_match "$pat" "$file"; then
    log_and_block "has read-only access to $pat"
  fi
done <<< "$read_only"

# 3. Read-write: allowed.
while IFS= read -r pat; do
  [[ -z "$pat" ]] && continue
  if glob_match "$pat" "$file"; then
    exit 0
  fi
done <<< "$read_write"

# 4. Not matched by any scope → block by default.
log_and_block "has no declared scope covering $file"
