#!/usr/bin/env bash
# adopt-into.sh is additive, idempotent, merges settings without losing the
# project's own entries, and refuses unsafe targets. Template-only test: it
# skips when scripts/adopt-into.sh isn't present (new/adopted projects don't
# get it). Everything runs in throwaway fixtures under mktemp -d.
#   1. empty git repo        -> full adoption; the process tests pass inside it
#   2. existing project      -> only CLAUDE.md/.gitignore appended and settings.json merged;
#                               its own hook/permission/keys kept; own tests/run.sh untouched,
#                               process tests in tests/process/ and they pass
#   3. --dry-run             -> changes nothing
#   4. second run            -> no-op ("Nothing to do")
#   5. realistic settings    -> every original hook command, permission and key survives the merge
#   6. stop-check            -> prefers tests/process/run.sh over the project's own runner
#   7. refusals              -> non-git dir and $HOME refused, nothing written
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
A="$ROOT/scripts/adopt-into.sh"
[ -f "$A" ] || { echo "skipped: scripts/adopt-into.sh not here (template-only test)"; exit 77; }
command -v jq >/dev/null 2>&1 || { echo "skipped: jq not installed (adopt-into.sh requires it)"; exit 77; }
W="$(mktemp -d "${TMPDIR:-/tmp}/adopt-test.XXXXXX")" || exit 1
trap 'rm -rf "$W"' EXIT
W="$(cd "$W" && pwd -P)"
unset STOP_CHECK_CMD HOOKS_OFF
status=0
fail() { echo "FAIL: $*"; status=1; }
g() { git -C "$1" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "${@:2}"; }
snap() { (cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r f; do
           printf '%s %s\n' "$(cksum < "$f")" "$f"; done); }

# ---------- 1. empty git repo ----------
E="$W/empty-proj"; mkdir -p "$E"; g "$E" init -q
out="$(bash "$A" "$E" 2>&1)" || fail "adopt into empty repo exited non-zero: $(printf '%s' "$out" | tail -3)"
for f in CLAUDE.md MISTAKES.md .gitignore .claude/settings.json record/DECISIONS.md record/FACTS.md record/LESSONS.md \
         tests/run.sh tests/BREAK-IT-ONCE.md docs/REVIEW.md .claude/commands/decision.md .claude/rules/record.md templates/handoff.md; do
  [ -f "$E/$f" ] || fail "empty repo: $f not created"
done
for s in brake-check record-guard stop-check session-start; do [ -x "$E/scripts/$s.sh" ] || fail "empty repo: scripts/$s.sh not executable"; done
for f in scripts/new-project.sh scripts/adopt-into.sh scripts/template-lib.sh tests/test_adopt.sh tests/test_global_install.sh global LICENSE README.md; do
  [ -e "$E/$f" ] && fail "empty repo: template-only file $f was copied"
done
grep -q '^# empty-proj — project instructions' "$E/CLAUDE.md" || fail "CLAUDE.md project name not substituted"
grep -q 'Adopted the Claude Process Template' "$E/record/DECISIONS.md" || fail "no adoption entry in DECISIONS.md"
grep -qE '^### D-00[12] — Adopt (five|the queue)' "$E/record/DECISIONS.md" && fail "template's own D-001/D-002 leaked into DECISIONS.md"
[ "$(awk 'FNR==1{on=0} /^## Entries/{on=1;next} on && /^### [DFL]-/' "$E"/record/*.md | wc -l | tr -d ' ')" = 1 ] || fail "record should hold exactly one real entry (the adoption)"
g "$E" add -A && g "$E" commit -qm adopt
pt="$(cd "$E" && bash tests/run.sh 2>&1)" || fail "process tests fail inside the adopted empty repo: $(printf '%s' "$pt" | grep -E 'FAIL|tests:' | head -5)"

# ---------- 2/3/4. existing project ----------
P="$W/existing-proj"; mkdir -p "$P/.claude" "$P/tests" "$P/docs"; g "$P" init -q
printf '# My App\n\nOur own rules. Keep them.\n' > "$P/CLAUDE.md"
cat > "$P/.claude/settings.json" <<'JSON'
{ "model": "keep-me",
  "permissions": { "allow": ["Bash(npm test)"], "deny": ["Bash(curl:*)"] },
  "hooks": { "PostToolUse": [ { "matcher": "Write", "hooks": [ { "type": "command", "command": "echo formatted" } ] } ] } }
JSON
printf '#!/usr/bin/env bash\necho own-tests\n' > "$P/tests/run.sh"
printf 'node_modules/\n.DS_Store\n' > "$P/.gitignore"
printf '# Our review notes\n' > "$P/docs/REVIEW.md"
g "$P" add -A && g "$P" commit -qm base
cp "$P/.claude/settings.json" "$W/orig-settings.json"
before="$(snap "$P")"
dry="$(bash "$A" "$P" --dry-run 2>&1)" || fail "--dry-run exited non-zero"
[ "$(snap "$P")" = "$before" ] || fail "--dry-run changed files"
printf '%s' "$dry" | grep -q 'CONFLICT  docs/REVIEW.md' || fail "dry-run plan doesn't list docs/REVIEW.md as CONFLICT"
printf '%s' "$dry" | grep -q 'merge     .claude/settings.json' || fail "dry-run plan doesn't show the settings merge"
printf '%s' "$dry" | grep -q 'tests/process' || fail "dry-run plan doesn't explain the tests/process layout"
printf '%s' "$dry" | grep -q 'DRY RUN' || fail "dry-run didn't say nothing was changed"

bash "$A" "$P" >/dev/null 2>&1 || fail "adopt into existing project exited non-zero"
changed="$(g "$P" diff --name-only | LC_ALL=C sort | tr '\n' ' ')"
[ "$changed" = ".claude/settings.json .gitignore CLAUDE.md " ] || fail "tracked files modified other than CLAUDE.md/.gitignore/settings.json: $changed"
head -3 "$P/CLAUDE.md" | grep -q 'Our own rules' || fail "CLAUDE.md original text not kept at the top"
[ "$(grep -c 'BEGIN claude-process-template' "$P/CLAUDE.md")" = 1 ] || fail "CLAUDE.md block missing or duplicated"
[ "$(sed -n '/BEGIN claude-process-template/,/END claude-process-template/p' "$P/CLAUDE.md" | wc -l | tr -d ' ')" -le 60 ] || fail "CLAUDE.md block longer than 60 lines"
grep -q 'bash tests/process/run.sh' "$P/CLAUDE.md" || fail "CLAUDE.md block doesn't point at tests/process/run.sh"
S="$P/.claude/settings.json"
jq empty "$S" 2>/dev/null || fail "merged settings.json invalid"
[ "$(jq -r .model "$S")" = keep-me ] || fail "unrelated key 'model' lost"
jq -e '.permissions.deny == ["Bash(curl:*)"]' "$S" >/dev/null || fail "permissions.deny changed"
jq -e '.permissions.allow | index("Bash(npm test)") and index("Bash(bash tests/run.sh)")' "$S" >/dev/null || fail "permissions not unioned"
jq -e '[.hooks.PostToolUse[].hooks[].command] | index("echo formatted")' "$S" >/dev/null || fail "existing PostToolUse hook lost"
jq -e '[.hooks.PreToolUse[].hooks[].command] | any(contains("scripts/brake-check.sh"))' "$S" >/dev/null || fail "brake-check hook not added"
cmp -s "$P/.claude/settings.json.pre-adopt" "$W/orig-settings.json" || fail "settings.json.pre-adopt is not the original"
[ "$(grep -cxF '.DS_Store' "$P/.gitignore")" = 1 ] || fail ".DS_Store duplicated in .gitignore"
grep -qxF '.claude/state/' "$P/.gitignore" || fail ".gitignore missing template lines"
head -1 "$P/.gitignore" | grep -qxF 'node_modules/' || fail ".gitignore original lines not kept first"
[ -f "$P/tests/process/run.sh" ] && [ -f "$P/tests/process/test_hooks_installed.sh" ] || fail "process tests not in tests/process/"
[ -e "$P/tests/test_hooks_installed.sh" ] && fail "process tests leaked into the project's tests/"
grep -q 'tests/process/run.sh' "$P/.claude/commands/decision.md" || fail "commands not re-pointed at tests/process/run.sh"
g "$P" add -A && g "$P" commit -qm adopt
pt="$(cd "$P" && bash tests/process/run.sh 2>&1)" || fail "process tests fail in the existing project: $(printf '%s' "$pt" | grep -E 'FAIL|tests:' | head -5)"
before="$(snap "$P")"
again="$(bash "$A" "$P" 2>&1)" || fail "second run exited non-zero"
[ "$(snap "$P")" = "$before" ] || fail "second run changed files (not idempotent)"
printf '%s' "$again" | grep -q 'Nothing to do' || fail "second run didn't say 'Nothing to do'"
before="$(snap "$E")"; bash "$A" "$E" >/dev/null 2>&1; [ "$(snap "$E")" = "$before" ] || fail "second run on the empty-repo project changed files"

# ---------- 5. realistic settings (self-contained fixture) ----------
# A settings.json shaped like a real, lived-in project: an unrelated hook on an
# event the template also uses, a statusLine, an env block, allow/deny/ask
# permissions. Every original hook command, permission and key must survive.
R="$W/realistic"; mkdir -p "$R/.claude"; g "$R" init -q
cat > "$R/orig.json" <<'JSON'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "model": "sonnet",
  "statusLine": { "type": "command", "command": "bash .claude/statusline.sh", "padding": 0 },
  "env": { "NODE_ENV": "development", "API_BASE_URL": "http://localhost:8080" },
  "permissions": {
    "allow": ["Bash(npm run lint)", "Bash(npm test:*)", "Bash(git status:*)", "Read(./src/**)"],
    "deny": ["Read(./.env)", "Bash(rm -rf:*)"],
    "ask": ["Bash(git push:*)"],
    "defaultMode": "acceptEdits"
  },
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "npx prettier --write \"$CLAUDE_FILE_PATHS\"", "timeout": 30 } ] }
    ],
    "Notification": [
      { "hooks": [ { "type": "command", "command": "osascript -e 'display notification \"Claude needs you\"'" } ] }
    ]
  },
  "enableAllProjectMcpServers": false
}
JSON
cp "$R/orig.json" "$R/.claude/settings.json"
if ! bash "$A" "$R" >/dev/null 2>&1; then fail "adopt into fixture with realistic settings failed"
else
  jq -e --slurpfile o "$R/orig.json" '
      . as $m | $o[0] as $o
      | ([$o.hooks // {} | to_entries[] | .key as $k | .value[] | (.hooks // [])[] | .command as $c
          | ($m.hooks[$k] // [] | [.[] | (.hooks // [])[] | .command] | index([$c]) != null)] | all)
      and (($o.permissions.allow // []) - ($m.permissions.allow // []) | length == 0)
      and ([$o | to_entries[] | select(.key != "hooks" and .key != "permissions") | $m[.key] == .value] | all)
      and ([$o.permissions // {} | to_entries[] | select(.key != "allow") | $m.permissions[.key] == .value] | all)' \
      "$R/.claude/settings.json" >/dev/null || fail "merge lost something from the realistic settings fixture"
fi

# ---------- 6. stop-check picks the process runner ----------
D="$W/stopcheck"; mkdir -p "$D/scripts" "$D/tests/process"
cp "$P/scripts/stop-check.sh" "$P/scripts/hook-lib.sh" "$D/scripts/"
printf 'exit 1\n' > "$D/tests/run.sh"; printf 'exit 0\n' > "$D/tests/process/run.sh"
echo '{}' | CLAUDE_PROJECT_DIR="$D" bash "$D/scripts/stop-check.sh" >/dev/null 2>&1 \
  || fail "stop-check ran the project's own tests/run.sh instead of tests/process/run.sh"

# ---------- 7. refusals ----------
N="$W/not-git"; mkdir -p "$N"
o="$(bash "$A" "$N" 2>&1)" && fail "non-git dir was not refused"
printf '%s' "$o" | grep -q 'git init' || fail "non-git refusal doesn't suggest git init"
[ -z "$(ls -A "$N")" ] || fail "something was written into the refused non-git dir"
o="$(bash "$A" "$HOME" --dry-run 2>&1)" && fail "\$HOME was not refused"
printf '%s' "$o" | grep -q 'home directory' || fail "\$HOME refusal message unclear"
bash "$A" / --dry-run >/dev/null 2>&1 && fail "/ was not refused"

[ $status -eq 0 ] && echo "ok: adopt-into is additive, idempotent, merges settings safely, dry-run is inert, refusals work"
exit $status
