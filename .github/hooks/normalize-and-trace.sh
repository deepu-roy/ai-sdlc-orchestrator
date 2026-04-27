#!/usr/bin/env bash
# Copilot postToolUse hook: normalize input → run trace-decisions
# Runs for all tools — trace-decisions.sh handles per-tool logic internally.
set -uo pipefail
cat | .github/hooks/normalize-input.sh | .claude/hooks/trace-decisions.sh
exit 0
