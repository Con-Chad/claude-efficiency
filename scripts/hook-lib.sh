#!/usr/bin/env bash
# hook-lib.sh — small helpers shared by the hook scripts. SOURCED, not run.
#
#   HOOK_PAYLOAD   the JSON Claude Code sent on stdin (set by hook_read)
#   PROJECT_DIR    the project root
#   STATE_DIR      .claude/state (git-ignored scratch: counters, snapshots)
#
# jq is used when present; otherwise a grep/sed fallback handles the simple
# string/boolean fields these hooks need. Set HOOK_NO_JQ=1 to force the
# fallback (the tests do this to prove both paths work).

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="$PROJECT_DIR/.claude/state"
HOOK_PAYLOAD=""

# Read stdin into HOOK_PAYLOAD (never blocks when run by hand in a terminal).
hook_read() {
  if [ -t 0 ]; then HOOK_PAYLOAD="{}"; else HOOK_PAYLOAD="$(cat)"; fi
}

have_jq() { [ "${HOOK_NO_JQ:-0}" != "1" ] && command -v jq >/dev/null 2>&1; }

# json_get <jq-path> <fallback-key>  -> prints a string field (or nothing)
json_get() {
  if have_jq; then
    printf '%s' "$HOOK_PAYLOAD" | jq -r "($1) // empty | tostring" 2>/dev/null
  else
    printf '%s' "$HOOK_PAYLOAD" | tr '\n' ' ' \
      | sed -nE 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' \
      | sed -e 's/\\n/\
/g' -e 's/\\t/	/g' -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\\\/\\/g'
  fi
}

# json_true <jq-path> <fallback-key>  -> exit 0 if the field is boolean true
json_true() {
  if have_jq; then
    [ "$(printf '%s' "$HOOK_PAYLOAD" | jq -r "($1) == true" 2>/dev/null)" = "true" ]
  else
    printf '%s' "$HOOK_PAYLOAD" | tr '\n' ' ' | grep -qE '"'"$2"'"[[:space:]]*:[[:space:]]*true'
  fi
}

# hook_disabled <name>  -> exit 0 if HOOKS_OFF (comma list) names this hook or "all"
hook_disabled() {
  case ",${HOOKS_OFF:-}," in *",$1,"*|*",all,"*) return 0;; esac
  return 1
}

# Session id safe for a filename.
session_key() {
  local s; s="$(json_get '.session_id' 'session_id' | tr -cd 'A-Za-z0-9_-')"
  printf '%s' "${s:-default}"
}
