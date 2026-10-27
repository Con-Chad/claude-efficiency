#!/usr/bin/env bash
# stop-check.sh — Claude Code Stop hook (runs when Claude finishes a reply).
#
# Principle 4 as a backstop (idea adapted from ECC's Stop-time format/typecheck
# gate): if any project file changed since the last green test run (or since
# the session started), run the test suite. If it fails, block the stop
# (exit 2): the failure goes back to Claude, which must fix it or tell the
# user plainly that tests are red — it can't quietly report "done".
#
#   - Only runs when something changed (mtime newer than the last green run),
#     so ordinary chat turns cost nothing.
#   - Blocks at most once in a row: when Claude Code says stop_hook_active,
#     we let it stop (no loops).
#   - Test command: STOP_CHECK_CMD if set; else "bash tests/process/run.sh" when
#     the project keeps the process tests separately (adopt-into.sh does that
#     when the project already had its own tests/run.sh); else "bash tests/run.sh".
#     To also run your own suite: STOP_CHECK_CMD="bash tests/process/run.sh && bash tests/run.sh"
#     (export it, or put it under "env" in .claude/settings.json).
# Off switch: HOOKS_OFF=stop-check (e.g. if your project's tests are slow).
set -u
. "$(dirname "$0")/hook-lib.sh"
hook_disabled stop-check && exit 0
hook_read
json_true '.stop_hook_active' 'stop_hook_active' && exit 0
dir="$PROJECT_DIR"
if [ -n "${STOP_CHECK_CMD:-}" ]; then cmd="$STOP_CHECK_CMD"
elif [ -f "$dir/tests/process/run.sh" ]; then cmd="bash tests/process/run.sh"
elif [ -f "$dir/tests/run.sh" ]; then cmd="bash tests/run.sh"
else exit 0; fi
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
green="$STATE_DIR/tests-green"

ref=""
if [ -f "$green" ]; then ref="$green"; elif [ -f "$STATE_DIR/session-started" ]; then ref="$STATE_DIR/session-started"; fi
if [ -n "$ref" ]; then
  changed="$(cd "$dir" && find . \( -name .git -o -name node_modules -o -name .venv -o -name backups -o -path ./.claude/state \) -prune \
             -o -type f -newer "$ref" -not -name '.DS_Store' -print 2>/dev/null | head -1)"
  [ -z "$changed" ] && exit 0
fi

mark="$STATE_DIR/tests-run.$$"; touch "$mark"
out="$(cd "$dir" && eval "$cmd" 2>&1)"; rc=$?
if [ $rc -eq 0 ]; then
  mv -f "$mark" "$green"   # timestamp = when this run STARTED
  exit 0
fi
rm -f "$mark"
{
  echo "STOP CHECK: files changed since the last green test run and \`$cmd\` now FAILS (exit $rc):"
  printf '%s\n' "$out" | grep -E '^(FAIL|  +FAIL|[0-9]+ tests:|ERROR)' | head -30
  echo "Fix it before finishing, or tell the user plainly that the tests are red and why. Do not report the task as done (rule H4)."
} >&2
exit 2
