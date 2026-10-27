#!/usr/bin/env bash
# session-start.sh — Claude Code SessionStart hook.
# Whatever this prints on stdout is added to Claude's context at session start.
#
# Line 1 (always): reminder naming the MISTAKES.md patterns.
# Then, BOUNDED (default 3000 chars; idea adapted from ECC's session-start
# loader), so Claude doesn't spend tool calls re-reading them every session:
#   - the last 3 decision headings from record/DECISIONS.md
#   - the "## Next" section of handoff.md, if one exists
#   - after a /compact or a resume: the state snapshot that save-state.sh
#     wrote just before (.claude/state/last-session.md)
# Off switches: HOOKS_OFF=session-context (extras only); SESSION_START_MAX_CHARS=N.
set -u
. "$(dirname "$0")/hook-lib.sh"
dir="$PROJECT_DIR"
hook_read
source_evt="$(json_get '.source' 'source')"

patterns=""
if [ -f "$dir/MISTAKES.md" ]; then
  # Pattern headings look like: "## P1 — Name of pattern"
  patterns="$(grep -E '^## P[0-9]+' "$dir/MISTAKES.md" | sed -E 's/^## //' | paste -sd ';' - | sed 's/;/; /g')"
fi
echo "SESSION START: before any work, read the patterns in MISTAKES.md (${patterns:-file missing!}); append to record files, never edit them."

# Baseline for scripts/stop-check.sh: "files changed since this session began".
mkdir -p "$STATE_DIR" 2>/dev/null && touch "$STATE_DIR/session-started" 2>/dev/null

hook_disabled session-context && exit 0
max="${SESSION_START_MAX_CHARS:-3000}"
case "$max" in ''|*[!0-9]*) max=3000;; esac

{
  if [ -f "$dir/record/DECISIONS.md" ]; then
    recent="$(awk '/^## Entries/{on=1; next} on && /^### D-[0-9]+/' "$dir/record/DECISIONS.md" | tail -3)"
    [ -n "$recent" ] && printf 'Recent decisions (record/DECISIONS.md — settled; supersede, do not re-open):\n%s\n' "$recent"
  fi
  if [ -f "$dir/handoff.md" ]; then
    when="$(date -r "$dir/handoff.md" '+%Y-%m-%d %H:%M' 2>/dev/null || echo '?')"
    next="$(awk '/^## Next/{on=1; next} on && /^## /{exit} on && NF' "$dir/handoff.md" | head -8)"
    printf 'handoff.md (last saved %s) — read it in full before starting. Its "Next":\n%s\n' "$when" "${next:-  (empty)}"
  fi
  case "$source_evt" in
    compact|resume)
      if [ -f "$STATE_DIR/last-session.md" ]; then
        echo "State snapshot saved before the $source_evt (mechanical, from .claude/state/last-session.md — verify before trusting):"
        sed -n '2,60p' "$STATE_DIR/last-session.md"
      fi ;;
  esac
} | head -c "$max"
exit 0
