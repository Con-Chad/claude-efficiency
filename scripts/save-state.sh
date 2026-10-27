#!/usr/bin/env bash
# save-state.sh — Claude Code PreCompact and SessionEnd hook.
#
# Writes a MECHANICAL snapshot of where the session is to
# .claude/state/last-session.md (git-ignored, overwritten each time), so that
# after a /compact (or when the session is resumed) session-start.sh can put
# it back into Claude's context. Idea adapted from ECC's pre-compact /
# session-end hooks; ECC also asks an LLM for a summary — we don't (no
# runtime, no API call from a hook). The judgement-heavy note is handoff.md,
# which Claude writes with /handoff.
#
# Captures: the last few user requests (needs jq + transcript_path), git
# branch / last commit / uncommitted files (no git: files changed in last 4h),
# newest record IDs, handoff.md age. Never blocks: always exit 0.
# Off switch: HOOKS_OFF=save-state.
set -u
. "$(dirname "$0")/hook-lib.sh"
hook_disabled save-state && exit 0
hook_read
dir="$PROJECT_DIR"
evt="$(json_get '.hook_event_name' 'hook_event_name')"
why="$(json_get '.trigger // .reason' 'trigger')"
tp="$(json_get '.transcript_path' 'transcript_path')"
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
out="$STATE_DIR/last-session.md"
tmp="$out.tmp.$$"

last_id() { # file prefix -> newest "### X-NNN — title" after "## Entries"
  [ -f "$dir/$1" ] && awk -v p="^### $2-[0-9]+" '/^## Entries/{on=1; next} on && $0 ~ p {l=$0} END{print l}' "$dir/$1"
}

{
  echo "# State snapshot — ${evt:-manual}${why:+ ($why)} — $(date '+%Y-%m-%d %H:%M')"
  if [ -n "$tp" ] && [ -f "$tp" ] && have_jq; then
    asks="$(tail -n 400 "$tp" | jq -rR 'fromjson? | select(.type == "user" and (.isMeta | not))
              | .message.content | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join(" ")) end
              | gsub("\\s+"; " ") | select(length > 0 and (startswith("<") | not))' 2>/dev/null \
            | tail -5 | cut -c1-200 | sed 's/^/- /')"
    [ -n "$asks" ] && printf '## Last user requests (newest last, truncated)\n%s\n' "$asks"
  fi
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "## Git"
    echo "- branch: $(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) — last commit: $(git -C "$dir" log -1 --format='%h %s (%cr)' 2>/dev/null || echo none)"
    st="$(git -C "$dir" status --short 2>/dev/null | head -25)"
    [ -n "$st" ] && printf -- '- uncommitted:\n%s\n' "$(printf '%s\n' "$st" | sed 's/^/    /')"
  else
    # Not a git repo yet: list recently changed files instead.
    recent="$(cd "$dir" && find . -type f -mmin -240 \
        -not -path './.claude/state/*' -not -path './backups/*' \
        -not -path '*/node_modules/*' -not -name '.DS_Store' 2>/dev/null | sed 's|^\./||' | head -20)"
    [ -n "$recent" ] && printf '## Files changed in the last 4h\n%s\n' "$(printf '%s\n' "$recent" | sed 's/^/- /')"
  fi
  echo "## Newest record entries"
  for spec in "record/DECISIONS.md D" "record/FACTS.md F" "record/LESSONS.md L"; do
    set -- $spec; l="$(last_id "$1" "$2")"; echo "- $1: ${l:-none yet}"
  done
  if [ -f "$dir/handoff.md" ]; then
    echo "- handoff.md last saved $(date -r "$dir/handoff.md" '+%Y-%m-%d %H:%M' 2>/dev/null)"
  else
    echo "- no handoff.md — if work continues later, write one with /handoff"
  fi
} > "$tmp" 2>/dev/null && mv -f "$tmp" "$out"
rm -f "$tmp" 2>/dev/null
exit 0
