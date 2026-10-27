#!/usr/bin/env bash
# Hard rule H2 at the moment of action: scripts/record-guard.sh must block
# (exit 2) rewrites of record/*.md and MISTAKES.md, and allow (exit 0)
# appends, placeholder filling, new files and other paths. Runs every case
# through the jq parser AND the grep/sed fallback (HOOK_NO_JQ=1).
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HOOK="$ROOT/scripts/record-guard.sh"
[ -f "$HOOK" ] || { echo "FAIL: $HOOK missing"; exit 1; }
export CLAUDE_PROJECT_DIR="$ROOT"
unset HOOKS_OFF
P="$ROOT"
status=0

# expect <code> <description> <json>   (MultiEdit cases are jq-only)
run_case() {
  local want="$1" desc="$2" json="$3" modes="jq nojq" m rc
  case "$json" in *MultiEdit*) modes="jq";; esac
  for m in $modes; do
    [ "$m" = "jq" ] && ! command -v jq >/dev/null 2>&1 && continue
    if [ "$m" = "nojq" ]; then
      printf '%s' "$json" | HOOK_NO_JQ=1 "$HOOK" >/dev/null 2>&1; rc=$?
    else
      printf '%s' "$json" | "$HOOK" >/dev/null 2>&1; rc=$?
    fi
    [ "$rc" = "$want" ] || { echo "FAIL [$m]: expected exit $want, got $rc — $desc"; status=1; }
  done
}
e() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"%s","new_string":"%s"}}' "$1" "$2" "$3"; }

run_case 2 "Write over existing DECISIONS.md" "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$P/record/DECISIONS.md\",\"content\":\"x\"}}"
run_case 2 "Write over existing MISTAKES.md"  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$P/MISTAKES.md\",\"content\":\"x\"}}"
run_case 2 "Edit rewording a MISTAKES pattern" "$(e "$P/MISTAKES.md" '## P1 — Confirmed' '## P1 — Checked')"
run_case 2 "Edit deleting text in FACTS.md"    "$(e "$P/record/FACTS.md" '## Entries' '')"
run_case 2 "Edit via relative path"            "$(e "record/LESSONS.md" '## Entries' '## Stuff')"
run_case 2 "MultiEdit with one rewrite"        "{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"$P/record/FACTS.md\",\"edits\":[{\"old_string\":\"a\",\"new_string\":\"ab\"},{\"old_string\":\"c\",\"new_string\":\"d\"}]}}"
run_case 0 "Edit appending after an anchor"    "$(e "$P/record/FACTS.md" '<!-- Append new facts below this line. -->' '<!-- Append new facts below this line. -->\n### F-001 — x')"
run_case 0 "MultiEdit appends only"            "{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"$P/record/FACTS.md\",\"edits\":[{\"old_string\":\"a\",\"new_string\":\"ab\"}]}}"
run_case 0 "Edit filling a placeholder"        "$(e "$P/MISTAKES.md" '<!-- placeholder: x -->' 'filled')"
run_case 0 "Write a NEW record file"           "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$P/record/NEW-not-there.md\",\"content\":\"x\"}}"
run_case 0 "Edit a non-record file"            "$(e "$P/README.md" 'a' 'b')"
run_case 0 "Write a non-record file"           "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$P/docs/BRAKES.md\",\"content\":\"x\"}}"

# The block message must steer Claude to append instead.
msg="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/MISTAKES.md","content":"x"}}' "$P" | "$HOOK" 2>&1 >/dev/null)"
printf '%s' "$msg" | grep -q 'append-only' && printf '%s' "$msg" | grep -q 'NEW entry' \
  || { echo "FAIL: block message doesn't explain append-only + new entry"; status=1; }

[ $status -eq 0 ] && echo "ok: record-guard blocks rewrites, allows appends (jq + fallback)"
exit $status
