#!/usr/bin/env bash
# Session-lifecycle hooks produce the output they promise (principle 4):
#   session-start.sh  -> names the MISTAKES patterns, recent decisions, handoff "Next",
#                        and the saved snapshot after a compact; respects the size cap
#   save-state.sh     -> writes .claude/state/last-session.md with the user's requests
#   context-nudge.sh  -> silent until the threshold, then valid additionalContext JSON
#   stop-check.sh     -> blocks (2) when files changed and tests fail; passes when green;
#                        never blocks twice in a row (stop_hook_active)
# Runs in a throwaway copy so the real project state isn't touched.
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
W="$(mktemp -d "${TMPDIR:-/tmp}/lifecycle-test.XXXXXX")" || exit 1
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/p/record" "$W/p/scripts" "$W/p/tests"
cp "$ROOT"/scripts/*.sh "$W/p/scripts/"
cp "$ROOT/MISTAKES.md" "$W/p/"
cp "$ROOT"/record/*.md "$W/p/record/"
export CLAUDE_PROJECT_DIR="$W/p"
unset HOOKS_OFF SESSION_START_MAX_CHARS CONTEXT_NUDGE_CALLS CONTEXT_NUDGE_TOKENS STOP_CHECK_CMD
cd "$W/p" || exit 1
status=0
fail() { echo "FAIL: $*"; status=1; }

# --- session-start ---
printf '\n### D-901 — Test decision one\n### D-902 — Test decision two\n' >> record/DECISIONS.md
printf '# Handoff\n## Next\n1. Wire the pump relay\n## Blocked\nnothing\n' > handoff.md
out="$(echo '{"source":"startup"}' | scripts/session-start.sh)"
printf '%s' "$out" | head -1 | grep -q 'SESSION START.*P1' || fail "session-start line 1 doesn't name the MISTAKES patterns"
printf '%s' "$out" | grep -q 'D-902 — Test decision two' || fail "session-start doesn't show recent decisions"
printf '%s' "$out" | grep -q 'Wire the pump relay' || fail "session-start doesn't show handoff Next"
printf '%s' "$out" | grep -q 'State snapshot' && fail "session-start showed the snapshot on a plain startup"
[ -f .claude/state/session-started ] || fail "session-start didn't write the stop-check baseline marker"
n="$(echo '{"source":"startup"}' | SESSION_START_MAX_CHARS=40 scripts/session-start.sh | sed 1d | wc -c | tr -d ' ')"
[ "$n" -le 41 ] || fail "SESSION_START_MAX_CHARS=40 not respected ($n chars of extras)"

# --- save-state + session-start after compact ---
T="$W/transcript.jsonl"
{ echo '{"type":"user","message":{"content":"please calibrate sensor B"}}'
  echo '{"type":"user","message":{"content":[{"type":"tool_result","content":"noise"}]}}'
  echo '{"type":"assistant","message":{"usage":{"input_tokens":10,"cache_read_input_tokens":150000,"cache_creation_input_tokens":0}}}'
} > "$T"
echo "{\"hook_event_name\":\"PreCompact\",\"trigger\":\"auto\",\"transcript_path\":\"$T\"}" | scripts/save-state.sh; rc=$?
[ $rc -eq 0 ] || fail "save-state exited $rc"
S=.claude/state/last-session.md
[ -f "$S" ] || fail "save-state wrote no $S"
grep -q 'PreCompact (auto)' "$S" 2>/dev/null || fail "snapshot header missing event/trigger"
grep -q 'D-902' "$S" 2>/dev/null || fail "snapshot missing newest decision"
if command -v jq >/dev/null 2>&1; then
  grep -q 'calibrate sensor B' "$S" || fail "snapshot missing the user's request from the transcript"
  grep -q 'noise' "$S" && fail "snapshot included a tool_result as a user request"
fi
echo '{"source":"compact"}' | scripts/session-start.sh | grep -q 'State snapshot saved before the compact' \
  || fail "session-start doesn't re-inject the snapshot after compact"

# --- context-nudge ---
quiet=1
for i in 1 2; do o="$(echo '{"session_id":"t1"}' | CONTEXT_NUDGE_CALLS=3 scripts/context-nudge.sh)"; [ -n "$o" ] && quiet=0; done
[ $quiet -eq 1 ] || fail "context-nudge spoke before the threshold"
o="$(echo '{"session_id":"t1"}' | CONTEXT_NUDGE_CALLS=3 scripts/context-nudge.sh)"
printf '%s' "$o" | grep -q '"additionalContext":"CONTEXT NUDGE: 3 tool calls' || fail "context-nudge silent at threshold (got: $o)"
if command -v jq >/dev/null 2>&1; then
  printf '%s' "$o" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null || fail "context-nudge output is not valid hook JSON"
  for i in 1 2 3 4 5; do o="$(echo "{\"session_id\":\"t2\",\"transcript_path\":\"$T\"}" | scripts/context-nudge.sh)"; done
  printf '%s' "$o" | grep -q 'Context is ~150k tokens' || fail "context-nudge didn't report context size from the transcript"
fi

# --- stop-check ---
sc() { printf '%s' "$1" | STOP_CHECK_CMD="$2" scripts/stop-check.sh >/dev/null 2>&1; echo $?; }
rm -f .claude/state/tests-green; touch -t 202001010000 .claude/state/session-started
touch record/FACTS.md
[ "$(sc '{"stop_hook_active":false}' 'echo "FAIL  x"; exit 1')" = 2 ] || fail "stop-check didn't block on failing tests after a change"
[ "$(sc '{"stop_hook_active":true}'  'exit 1')" = 0 ] || fail "stop-check blocked twice in a row (stop_hook_active)"
[ "$(sc '{}' 'true')" = 0 ] || fail "stop-check blocked when tests pass"
[ -f .claude/state/tests-green ] || fail "stop-check didn't record the green run"
[ "$(sc '{}' 'exit 1')" = 0 ] || fail "stop-check re-ran tests when nothing changed since green"

[ $status -eq 0 ] && echo "ok: session-start, save-state, context-nudge, stop-check produce their promised output"
exit $status
