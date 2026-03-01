#!/bin/bash
# Smart error sound wrapper for remote playback.
# Reads hook JSON from stdin, filters noise, sends real errors to Windows server.

WINDOWS_HOST="10.0.0.210"
PORT=7865
CACHE_DIR="$HOME/.cache"
mkdir -p "$CACHE_DIR"
COOLDOWN_FILE="$CACHE_DIR/sc2-claude-last-error"
COOLDOWN_SECONDS=15

# Read the hook JSON from stdin
INPUT=$(cat)

# Use python3 to decide whether this error is worth alerting on
SHOULD_PLAY=$(echo "$INPUT" | python3 -c "
import sys, json, re

try:
    d = json.load(sys.stdin)
except:
    print('no')
    sys.exit()

# Skip user interrupts
if d.get('is_interrupt'):
    print('no')
    sys.exit()

command = d.get('tool_input', {}).get('command', '')
error = d.get('error', '')
combined = command + ' ' + error

# --- Command denylist: these 'fail' as part of normal operation ---
skip_prefixes = [
    'which ', 'command -v ', 'type ',
    'grep ', 'rg ', 'ag ',
    'pkill ', 'pgrep ',
    'diff ', 'cmp ',
    'find ', 'ls ', 'stat ',
    'file ',
    'test ', '[ ',
    'cat ', 'head ', 'tail ',
    'readlink ',
]

cmd_stripped = command.lstrip()
for prefix in skip_prefixes:
    if cmd_stripped.startswith(prefix):
        print('no')
        sys.exit()

# --- Error pattern allowlist: only play if something genuinely went wrong ---
interesting_patterns = [
    r'Build failed', r'ERROR in', r'error TS\d', r'SyntaxError',
    r'Module not found', r'Cannot find module', r'compilation failed',
    r'Tests?:.*failed', r'FAIL ', r'Assert(ion)?Error', r'test.*failed',
    r'fatal:', r'CONFLICT', r'rejected\b', r'merge conflict',
    r'not a git repository',
    r'[Pp]ermission denied', r'EACCES', r'command not found',
    r'No space left', r'ENOSPC', r'Cannot allocate memory', r'ENOMEM',
    r'Segmentation fault', r'Killed', r'Traceback \(most recent',
    r'TypeError', r'ReferenceError', r'panic:', r'SIGKILL|SIGSEGV|SIGABRT',
    r'core dumped',
    r'ECONNREFUSED', r'Connection refused', r'ETIMEDOUT',
    r'ERR!', r'error: could not install', r'Failed to resolve',
]

for pattern in interesting_patterns:
    if re.search(pattern, combined, re.IGNORECASE):
        print('yes')
        sys.exit()

print('no')
" 2>/dev/null)

if [ "$SHOULD_PLAY" != "yes" ]; then
  exit 0
fi

# Cooldown: don't play if we played an error sound recently
if [ -f "$COOLDOWN_FILE" ]; then
  LAST=$(cat "$COOLDOWN_FILE" 2>/dev/null)
  NOW=$(date +%s)
  if [ -n "$LAST" ] && [ $((NOW - LAST)) -lt "$COOLDOWN_SECONDS" ]; then
    exit 0
  fi
fi

# Record timestamp and send to Windows
date +%s > "$COOLDOWN_FILE"
curl -sf -X POST "http://${WINDOWS_HOST}:${PORT}/play" \
  -H "Content-Type: application/json" \
  -d '{"category": "error"}' \
  --connect-timeout 1 --max-time 2 &>/dev/null &
