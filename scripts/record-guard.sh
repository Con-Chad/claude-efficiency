#!/usr/bin/env bash
# record-guard.sh — Claude Code PreToolUse hook for Edit|Write|MultiEdit.
#
# Rule H2 at the moment of action: record/*.md and MISTAKES.md are append-only.
# tests/test_append_only.sh catches a rewrite after the fact; this hook stops
# it before it happens (idea adapted from ECC's config-protection hook: stop
# the agent changing the guard-rail instead of doing the work).
#
#   Write to an EXISTING record file      -> block (whole-file overwrite)
#   Edit whose new_string doesn't contain  -> block (existing text changed)
#     its old_string verbatim
#   Edit that keeps old_string and adds     -> allow (that's appending)
#   old_string contains "placeholder"/"{{"  -> allow (filling template slots)
#   New file / any other path               -> allow
#
# Exit 0 = allow, 2 = block (reason on stderr goes back to Claude).
# Off switch: HOOKS_OFF=record-guard (e.g. in .claude/settings.local.json env).
# Seatbelt, not a lock: shell redirection (>, sed -i) is not seen here; the
# append-only test still backs it up.
set -u
. "$(dirname "$0")/hook-lib.sh"
hook_disabled record-guard && exit 0
hook_read

fp="$(json_get '.tool_input.file_path' 'file_path')"
[ -z "$fp" ] && exit 0
case "$fp" in /*) ;; *) fp="$PROJECT_DIR/$fp";; esac
[ -f "$fp" ] || exit 0   # creating a new file is fine

# Resolve both sides physically so /tmp vs /private/tmp, symlinks, etc. agree.
pdir="$(cd "$PROJECT_DIR" 2>/dev/null && pwd -P)" || exit 0
fdir="$(cd "$(dirname "$fp")" 2>/dev/null && pwd -P)" || exit 0
rel="${fdir#"$pdir"}/$(basename "$fp")"
case "$rel" in
  /record/*.md|/MISTAKES.md) ;;
  *) exit 0 ;;
esac
name="${rel#/}"

tool="$(json_get '.tool_name' 'tool_name')"
reason=""

if [ "$tool" = "Write" ]; then
  reason="Write would overwrite the whole of $name"
elif [ "$tool" = "MultiEdit" ]; then
  if have_jq; then
    ok="$(printf '%s' "$HOOK_PAYLOAD" | jq -r '[.tool_input.edits[]? | (.old_string // "") as $o
          | ((.new_string // "") | contains($o)) or ($o | test("placeholder|\\{\\{"))] | all' 2>/dev/null)"
    [ "$ok" = "true" ] || reason="a MultiEdit changes existing text in $name"
  else
    reason="MultiEdit on $name can't be checked without jq — use one Edit per appended entry"
  fi
else
  old="$(json_get '.tool_input.old_string' 'old_string')"
  new="$(json_get '.tool_input.new_string' 'new_string')"
  case "$old" in *placeholder*|*'{{'*) exit 0;; esac
  case "$new" in *"$old"*) exit 0;; esac
  reason="the edit changes or removes existing text in $name"
fi
[ -z "$reason" ] && exit 0

{
  echo "RECORD GUARD: blocked — $reason."
  echo "record/*.md and MISTAKES.md are append-only (CLAUDE.md rule H2). Do not rewrite, reword, re-status or delete entries."
  echo "To add: use Edit with old_string = the file's current last line(s) and new_string = those same lines followed by the new entry."
  echo "To correct or reverse something: append a NEW entry that references the old one (Supersedes: D-xxx)."
  echo "If the user explicitly wants an uncommitted entry you just wrote fixed, ask them to set HOOKS_OFF=record-guard for that change."
} >&2
exit 2
