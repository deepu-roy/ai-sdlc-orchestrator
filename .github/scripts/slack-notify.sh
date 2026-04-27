#!/usr/bin/env bash
# Usage: slack-notify.sh <message...>
# Requires SLACK_WEBHOOK_URL in env.
# Fails quietly if the webhook is not configured.

set -euo pipefail

if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "SLACK_WEBHOOK_URL not set; skipping Slack notification." >&2
  exit 0
fi

msg="$*"
if [[ -z "$msg" ]]; then
  echo "Usage: $0 <message>" >&2
  exit 2
fi

curl -sS -X POST -H 'Content-type: application/json' \
  --data "$(jq -n --arg t "$msg" '{text:$t}')" \
  "$SLACK_WEBHOOK_URL" >/dev/null
