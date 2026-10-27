#!/usr/bin/env bash
# global/install.sh installs the global kit safely. Template-only test: skips
# where global/install.sh is absent (new/adopted projects don't get it).
# Everything runs against a fake HOME + CLAUDE_HOME under mktemp -d — the real
# ~/.claude is never touched.
#   1. preview (default) on an empty home  -> changes nothing
#   2. --apply on an empty home            -> hook, settings, CLAUDE.md, command, ~/claude-backups
#   3. --apply on a home with existing settings.json + CLAUDE.md
#                                          -> every existing key/hook/permission/line kept,
#                                             only the new parts added, backups made
#   4. second --apply                      -> no-op ("Nothing to do")
#   5. home that already has the rules heading -> CLAUDE.md untouched
#   6. a different hooks/brake-check.sh    -> CONFLICT, kept, not registered
#   7. the installed brake blocks git push (exit 2), allows ls; command has no {{TEMPLATE_DIR}}
#   8. the pattern section of global/hooks/brake-check.sh == scripts/brake-check.sh (no drift)
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
I="$ROOT/global/install.sh"
[ -f "$I" ] || { echo "skipped: global/install.sh not here (template-only test)"; exit 77; }
command -v jq >/dev/null 2>&1 || { echo "skipped: jq not installed (global/install.sh requires it)"; exit 77; }
W="$(mktemp -d "${TMPDIR:-/tmp}/global-test.XXXXXX")" || exit 1
trap 'rm -rf "$W"' EXIT
W="$(cd "$W" && pwd -P)"
unset BRAKE_APPROVED BRAKE_NO_JQ
status=0
fail() { echo "FAIL: $*"; status=1; }
snap() { (cd "$1" && find . -print | LC_ALL=C sort | while IFS= read -r f; do
           if [ -f "$f" ]; then printf '%s %s\n' "$(cksum < "$f")" "$f"; else printf 'dir %s\n' "$f"; fi; done); }
# run <home> [args]: install with a fake HOME and CLAUDE_HOME
run() { local h="$1"; shift; HOME="$h" CLAUDE_HOME="$h/.claude" bash "$I" "$@" 2>&1; }
REAL_CH="$(cd ~ && pwd -P)/.claude"

# ---------- 1. preview changes nothing ----------
H1="$W/empty"; mkdir -p "$H1"
before="$(snap "$H1")"
out="$(run "$H1")" || fail "preview exited non-zero: $(printf '%s' "$out" | tail -3)"
[ "$(snap "$H1")" = "$before" ] || fail "preview changed files"
printf '%s' "$out" | grep -q 'PREVIEW — nothing was changed' || fail "preview didn't say nothing was changed"
printf '%s' "$out" | grep -q 'create' || fail "preview plan lists no creates on an empty home"
out="$(run "$H1" --dry-run)"; [ "$(snap "$H1")" = "$before" ] || fail "--dry-run changed files"

# ---------- 2. apply on an empty home ----------
out="$(run "$H1" --apply)" || fail "apply on empty home exited non-zero: $(printf '%s' "$out" | tail -3)"
C="$H1/.claude"
[ -x "$C/hooks/brake-check.sh" ] || fail "brake hook not installed/executable"
cmp -s "$C/hooks/brake-check.sh" "$ROOT/global/hooks/brake-check.sh" || fail "installed brake differs from global/hooks/brake-check.sh"
jq empty "$C/settings.json" 2>/dev/null || fail "settings.json missing or invalid"
jq -e '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[].command] | any(contains("hooks/brake-check.sh"))' "$C/settings.json" >/dev/null \
  || fail "brake not registered under PreToolUse/Bash"
grep -qF '<!-- BEGIN claude-efficiency rules -->' "$C/CLAUDE.md" && grep -qF '<!-- END claude-efficiency rules -->' "$C/CLAUDE.md" \
  || fail "CLAUDE.md missing the BEGIN/END markers"
grep -qxF '# Working rules (all projects)' "$C/CLAUDE.md" || fail "CLAUDE.md missing the rules heading"
grep -q 'claude-backups' "$C/CLAUDE.md" || fail "CLAUDE.md missing the Backups rule"
[ -f "$C/commands/adopt-process.md" ] || fail "adopt-process command not installed"
grep -q '{{TEMPLATE_DIR}}' "$C/commands/adopt-process.md" && fail "command still contains {{TEMPLATE_DIR}}"
grep -qF "\"$(cd "$ROOT" && pwd -P)/scripts/adopt-into.sh\"" "$C/commands/adopt-process.md" || fail "command doesn't point at this repo's adopt-into.sh"
[ -d "$H1/claude-backups" ] || fail "~/claude-backups not created"
printf '%s' "$out" | grep -q '/hooks' || fail "next steps don't mention /hooks"

# ---------- 4. second apply is a no-op ----------
before="$(snap "$H1")"
again="$(run "$H1" --apply)" || fail "second apply exited non-zero"
[ "$(snap "$H1")" = "$before" ] || fail "second apply changed files (not idempotent)"
printf '%s' "$again" | grep -q 'Nothing to do' || fail "second apply didn't say 'Nothing to do'"

# ---------- 3. existing settings.json + CLAUDE.md ----------
H3="$W/existing"; mkdir -p "$H3/.claude"
cat > "$H3/.claude/settings.json" <<'JSON'
{ "model": "keep-me",
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" },
  "env": { "FOO": "bar" },
  "permissions": { "allow": ["Bash(npm test)"], "deny": ["Bash(curl:*)"] },
  "hooks": {
    "PreToolUse": [ { "matcher": "*", "hooks": [ { "type": "command", "command": "~/.claude/usage-guard.sh" } ] } ],
    "Stop": [ { "hooks": [ { "type": "command", "command": "afplay /System/Library/Sounds/Glass.aiff" } ] } ] } }
JSON
printf '# My global notes\n\nKeep this line.\n' > "$H3/.claude/CLAUDE.md"
cp "$H3/.claude/settings.json" "$W/orig-settings.json"; cp "$H3/.claude/CLAUDE.md" "$W/orig-claude.md"
run "$H3" >/dev/null; cmp -s "$H3/.claude/settings.json" "$W/orig-settings.json" || fail "preview modified existing settings.json"
out="$(run "$H3" --apply)" || fail "apply on existing home exited non-zero: $(printf '%s' "$out" | tail -3)"
S="$H3/.claude/settings.json"
jq -e --slurpfile o "$W/orig-settings.json" '
    . as $m | $o[0] as $o
    | ($m.model == $o.model) and ($m.statusLine == $o.statusLine) and ($m.env == $o.env)
      and ($m.permissions == $o.permissions) and ($m.hooks.Stop == $o.hooks.Stop)
      and ($m.hooks.PreToolUse[0] == $o.hooks.PreToolUse[0])
      and ($m.hooks.PreToolUse | length == 2)
      and ($m.hooks.PreToolUse[1].matcher == "Bash")
      and ($m | keys == ($o | keys))' "$S" >/dev/null || fail "settings merge lost or changed existing entries (or added more than one hook)"
bk="$(ls "$H3/.claude/" | grep -c '^settings\.json\.pre-claude-efficiency-')"
[ "$bk" = 1 ] || fail "expected one settings.json.pre-claude-efficiency-* backup, found $bk"
cmp -s "$H3/.claude/"settings.json.pre-claude-efficiency-* "$W/orig-settings.json" || fail "settings backup is not the original"
head -3 "$H3/.claude/CLAUDE.md" | cmp -s - "$W/orig-claude.md" || fail "CLAUDE.md original text not kept at the top"
[ "$(grep -c 'BEGIN claude-efficiency rules' "$H3/.claude/CLAUDE.md")" = 1 ] || fail "rules block missing or duplicated"
ls "$H3/.claude/" | grep -q '^CLAUDE\.md\.pre-claude-efficiency-' || fail "no CLAUDE.md backup"
before="$(snap "$H3")"; again="$(run "$H3" --apply)"
[ "$(snap "$H3")" = "$before" ] || fail "second apply on existing home changed files"

# ---------- 5. rules heading already present (installed by hand) ----------
H5="$W/has-rules"; mkdir -p "$H5/.claude"
printf '# Mine\n\n# Working rules (all projects)\n- my version\n' > "$H5/.claude/CLAUDE.md"; cp "$H5/.claude/CLAUDE.md" "$W/h5.md"
run "$H5" --apply >/dev/null || fail "apply on home with rules heading exited non-zero"
cmp -s "$H5/.claude/CLAUDE.md" "$W/h5.md" || fail "CLAUDE.md changed although the rules heading was already there"

# ---------- 6. a different brake-check.sh is a CONFLICT ----------
H6="$W/conflict"; mkdir -p "$H6/.claude/hooks"; printf '#!/bin/sh\nexit 0\n' > "$H6/.claude/hooks/brake-check.sh"
out="$(run "$H6" --apply)" || fail "apply with conflicting hook exited non-zero"
printf '%s' "$out" | grep -q 'CONFLICT' || fail "conflicting brake-check.sh not reported as CONFLICT"
[ "$(cat "$H6/.claude/hooks/brake-check.sh")" = "$(printf '#!/bin/sh\nexit 0')" ] || fail "conflicting brake-check.sh was overwritten"
[ -e "$H6/.claude/settings.json" ] && jq -e '[.hooks.PreToolUse[]?.hooks[]?.command] | any(contains("brake-check"))' "$H6/.claude/settings.json" >/dev/null \
  && fail "a brake-check.sh that isn't ours was registered"

# ---------- 7. the installed brake works ----------
B="$H1/.claude/hooks/brake-check.sh"; P="$W/plain-project"; mkdir -p "$P"
brake() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | CLAUDE_PROJECT_DIR="$P" bash "$B" >/dev/null 2>&1; echo $?; }
[ "$(brake 'git push origin main')" = 2 ] || fail "installed brake didn't block git push (expected exit 2)"
[ "$(brake 'ls -la')" = 0 ] || fail "installed brake blocked ls"
[ "$(brake 'BRAKE_APPROVED=1 git push origin main')" = 0 ] || fail "installed brake ignored BRAKE_APPROVED=1"

# ---------- 8. no drift between the two brake copies ----------
patterns() { sed -n '/^# ---------- 3\. Pattern checks/,/^\[ -z "\$label" \] && exit 0$/p' "$1"; }
[ -n "$(patterns "$ROOT/scripts/brake-check.sh")" ] || fail "pattern section markers not found in scripts/brake-check.sh"
[ "$(patterns "$ROOT/scripts/brake-check.sh")" = "$(patterns "$ROOT/global/hooks/brake-check.sh")" ] \
  || fail "pattern section differs between scripts/brake-check.sh and global/hooks/brake-check.sh — change both"

# The real ~/.claude was never the target.
case "$W" in "$REAL_CH"*) fail "test workspace is inside the real ~/.claude" ;; esac

[ $status -eq 0 ] && echo "ok: global install previews by default, is additive and idempotent, keeps existing settings, brake works, copies in sync"
exit $status
