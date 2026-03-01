#!/bin/bash
# Sends a play request to the SC2 sound server on Windows.
# Usage: play-remote.sh <category>
# Categories: session-start, task-complete, needs-permission, error

WINDOWS_HOST="10.0.0.210"
PORT=7865
CATEGORY="$1"

[ -z "$CATEGORY" ] && exit 0

# Fire-and-forget: don't block Claude Code
curl -sf -X POST "http://${WINDOWS_HOST}:${PORT}/play" \
  -H "Content-Type: application/json" \
  -d "{\"category\": \"${CATEGORY}\"}" \
  --connect-timeout 1 --max-time 2 &>/dev/null &
