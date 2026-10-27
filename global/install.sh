#!/usr/bin/env bash
# install.sh — install the global kit (brake hook, working rules, /adopt-process
# command) into your Claude Code user folder (~/.claude).
#
# Usage:
#   bash global/install.sh            preview: print the plan, change NOTHING
#   bash global/install.sh --dry-run  same as above
#   bash global/install.sh --apply    install
#
# What it does (additive and idempotent — running it twice changes nothing):
#   - hooks/brake-check.sh            copied from global/hooks/ (a different
#                                     existing file is a CONFLICT: kept, reported)
#   - settings.json                   brake registered under hooks.PreToolUse
#                                     (matcher Bash) unless already registered;
#                                     every other key kept; created if absent
#   - CLAUDE.md                       global/CLAUDE-rules.md appended between
#                                     BEGIN/END claude-efficiency markers, unless
#                                     the marker or the rules heading is there
#   - commands/adopt-process.md       with {{TEMPLATE_DIR}} = this repo's path
#   - ~/claude-backups/               created (every project's backups go in a
#                                     subfolder here)
# settings.json and CLAUDE.md are backed up as <file>.pre-claude-efficiency-<ts>
# before they are changed. Requires jq.
#
# Environment: CLAUDE_HOME overrides the target folder (default $HOME/.claude);
# the backups folder is always $HOME/claude-backups.

set -eu

usage() { echo "usage: $0 [--dry-run | --apply]" >&2; exit 1; }
APPLY=0
for a in "$@"; do
  case "$a" in
    --apply) APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    -h|--help) usage ;;
    *) echo "ERROR: unknown argument $a" >&2; usage ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required (to edit settings.json safely)." >&2
  echo "       Install it:  brew install jq   (macOS)   or   sudo apt install jq   (Debian/Ubuntu)" >&2
  exit 1
}

KIT="$(cd "$(dirname "$0")" && pwd -P)"
REPO="$(cd "$KIT/.." && pwd -P)"
CH="${CLAUDE_HOME:-$HOME/.claude}"
BACKUPS="$HOME/claude-backups"
TS="$(date +%Y%m%d-%H%M%S)"
SUFFIX=".pre-claude-efficiency-$TS"
BEGIN='<!-- BEGIN claude-efficiency rules -->'
END='<!-- END claude-efficiency rules -->'
HEADING='# Working rules (all projects)'

for f in hooks/brake-check.sh CLAUDE-rules.md commands/adopt-process.md; do
  [ -f "$KIT/$f" ] || { echo "ERROR: $KIT/$f is missing — is this a complete copy of the repo?" >&2; exit 1; }
done

HOOK_DEST="$CH/hooks/brake-check.sh"
# The command string written to settings.json. For the normal location use the
# portable ~ form; for a custom CLAUDE_HOME use the quoted absolute path.
if [ "$CH" = "$HOME/.claude" ]; then HOOK_CMD='~/.claude/hooks/brake-check.sh'
else HOOK_CMD="\"$HOOK_DEST\""; fi
# Any of these already registered counts as "already installed".
HOOK_CMDS_JSON="$(jq -cn --arg a "$HOOK_CMD" --arg b "$HOOK_DEST" --arg c "\"$HOOK_DEST\"" \
  --arg d '$HOME/.claude/hooks/brake-check.sh' --arg e '"$HOME"/.claude/hooks/brake-check.sh' \
  --arg f '~/.claude/hooks/brake-check.sh' \
  'if $a == $f then [$a,$b,$c,$d,$e] else [$a,$b,$c] end')"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/claude-efficiency.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
PLAN="$STAGE/.plan"; : > "$PLAN"
plan() { printf '%s|%s|%s\n' "$1" "$2" "${3:-}" >> "$PLAN"; }   # action|key|note

# ---------- 1. brake hook file ----------
HOOK_STATE=create
if [ ! -e "$HOOK_DEST" ]; then plan create hook "$HOOK_DEST"
elif cmp -s "$KIT/hooks/brake-check.sh" "$HOOK_DEST"; then
  HOOK_STATE=same
  if [ -x "$HOOK_DEST" ]; then plan same hook "$HOOK_DEST"; else plan chmod hook "$HOOK_DEST (identical, make executable)"; fi
else
  HOOK_STATE=conflict
  plan CONFLICT hook "$HOOK_DEST exists with different content — kept. Compare it with global/hooks/brake-check.sh, then move yours aside and re-run if you want this one."
fi

# ---------- 2. settings.json ----------
SET="$CH/settings.json"
registered() {   # is any of our command strings already a PreToolUse hook?
  jq -e --argjson want "$HOOK_CMDS_JSON" \
    '[.hooks.PreToolUse // [] | .[] | (.hooks // [])[] | .command] | any(. as $c | $want | index([$c]) != null)' "$1" >/dev/null 2>&1
}
ENTRY="$(jq -cn --arg c "$HOOK_CMD" '{matcher: "Bash", hooks: [{type: "command", command: $c, timeout: 10}]}')"
if [ ! -e "$SET" ]; then
  if [ "$HOOK_STATE" = conflict ]; then plan skip settings "$SET — not created: the existing hooks/brake-check.sh is not ours (see CONFLICT)"
  else
    jq -n --argjson e "$ENTRY" '{hooks: {PreToolUse: [$e]}}' > "$STAGE/settings.json"
    plan create settings "$SET (registers the brake hook for Bash)"
  fi
else
  jq empty "$SET" 2>/dev/null || { echo "ERROR: $SET is not valid JSON — fix it first; nothing was changed." >&2; exit 1; }
  if registered "$SET"; then plan same settings "$SET (brake hook already registered)"
  elif [ "$HOOK_STATE" = conflict ]; then plan skip settings "$SET — brake NOT registered: the existing hooks/brake-check.sh is not ours (see CONFLICT)"
  else
    jq --argjson e "$ENTRY" '.hooks = (.hooks // {}) | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [$e])' "$SET" > "$STAGE/settings.json"
    jq empty "$STAGE/settings.json" || { echo "ERROR: merged settings are not valid JSON — nothing was changed." >&2; exit 1; }
    plan merge settings "$SET (+1 PreToolUse hook for Bash; everything else kept; backup ${SET##*/}$SUFFIX)"
  fi
fi

# ---------- 3. CLAUDE.md ----------
MD="$CH/CLAUDE.md"
{ echo "$BEGIN"; cat "$KIT/CLAUDE-rules.md"; echo "$END"; } > "$STAGE/rules.block"
if [ ! -e "$MD" ]; then plan create claude "$MD (working rules)"
elif grep -qF "$BEGIN" "$MD" || grep -qxF "$HEADING" "$MD"; then plan same claude "$MD (working rules already there)"
else plan append claude "$MD (working rules between BEGIN/END claude-efficiency markers; backup CLAUDE.md$SUFFIX)"
fi

# ---------- 4. /adopt-process command ----------
CMD_DEST="$CH/commands/adopt-process.md"
esc="$(printf '%s' "$REPO" | sed -e 's/[\\|&]/\\&/g')"
sed "s|{{TEMPLATE_DIR}}|$esc|g" "$KIT/commands/adopt-process.md" > "$STAGE/adopt-process.md"
if [ ! -e "$CMD_DEST" ]; then plan create command "$CMD_DEST (points at $REPO)"
elif cmp -s "$STAGE/adopt-process.md" "$CMD_DEST"; then plan same command "$CMD_DEST"
else plan CONFLICT command "$CMD_DEST exists with different content — kept. If it points at an old copy of this repo, delete it and re-run."
fi

# ---------- 5. backups folder ----------
if [ -d "$BACKUPS" ]; then plan same backups "$BACKUPS"
else plan create backups "$BACKUPS (every project's backups go in a subfolder here)"; fi

# ---------- print the plan ----------
echo "claude-efficiency global kit -> $CH"
echo
while IFS='|' read -r act key note; do
  case "$act" in
    same) printf '  ok        %s\n' "$note" ;;
    CONFLICT) printf '  CONFLICT  %s\n' "$note" ;;
    *) printf '  %-9s %s\n' "$act" "$note" ;;
  esac
done < "$PLAN"
n_do="$(grep -cE '^(create|merge|append|chmod)\|' "$PLAN" || true)"
n_conf="$(grep -c '^CONFLICT|' "$PLAN" || true)"
echo
echo "Summary: $n_do change(s), $n_conf conflict(s)."
if [ "$n_do" -eq 0 ]; then echo "Nothing to do — the global kit is already installed."; exit 0; fi
if [ $APPLY -eq 0 ]; then
  echo "PREVIEW — nothing was changed. To install:  bash \"$KIT/install.sh\" --apply"
  exit 0
fi

# ---------- apply ----------
has() { grep -q "^$1|$2|" "$PLAN"; }
mkdir -p "$CH"
if has create hook; then mkdir -p "$CH/hooks"; cp "$KIT/hooks/brake-check.sh" "$HOOK_DEST"; chmod +x "$HOOK_DEST"; fi
has chmod hook && chmod +x "$HOOK_DEST"
if has create settings; then
  cp "$STAGE/settings.json" "$SET.tmp.$$" && mv -f "$SET.tmp.$$" "$SET"
elif has merge settings; then
  cp -p "$SET" "$SET$SUFFIX"
  cp "$STAGE/settings.json" "$SET.tmp.$$" && mv -f "$SET.tmp.$$" "$SET"
fi
if has create claude; then cp "$STAGE/rules.block" "$MD"
elif has append claude; then
  cp -p "$MD" "$MD$SUFFIX"
  { [ -n "$(tail -c1 "$MD")" ] && echo; echo; cat "$STAGE/rules.block"; } >> "$MD"
fi
if has create command; then mkdir -p "$CH/commands"; cp "$STAGE/adopt-process.md" "$CMD_DEST"; fi
has create backups && mkdir -p "$BACKUPS"

# Output check: what we promised is actually there.
bad=0
[ "$HOOK_STATE" = conflict ] || [ -x "$HOOK_DEST" ] || { echo "WARNING: $HOOK_DEST missing or not executable"; bad=1; }
if [ -e "$SET" ]; then
  jq empty "$SET" || { echo "WARNING: $SET is not valid JSON"; bad=1; }
  [ "$HOOK_STATE" = conflict ] || registered "$SET" || { echo "WARNING: brake hook not registered in $SET"; bad=1; }
fi
grep -qF "$BEGIN" "$MD" || grep -qxF "$HEADING" "$MD" || { echo "WARNING: working rules not found in $MD"; bad=1; }
grep -q '{{TEMPLATE_DIR}}' "$CMD_DEST" 2>/dev/null && { echo "WARNING: $CMD_DEST still contains {{TEMPLATE_DIR}}"; bad=1; }
[ -d "$BACKUPS" ] || { echo "WARNING: $BACKUPS not created"; bad=1; }
echo
[ $bad -eq 0 ] && echo "Installed. Checked: brake hook executable and registered, settings.json valid JSON, rules in CLAUDE.md, command path filled in."

cat <<NEXT

Next steps:
  1. Restart Claude Code (hooks and CLAUDE.md are read at startup).
  2. Run /hooks — the PreToolUse (Bash) list should show $HOOK_CMD
  3. Test the brake, in a scratch folder that is NOT a template project:
       mkdir -p /tmp/brake-test     then ask Claude to run:   rm -rf /tmp/brake-test
     It should be BLOCKED and Claude should ask you first. Say yes and it re-runs
     with BRAKE_APPROVED=1. If it just runs, the hook is not active — see step 2.
  4. In an existing git project, run /adopt-process to add the full process.
To undo: see "Removing it" in $REPO/README.md (backups end in $SUFFIX).
NEXT
[ "$n_conf" -gt 0 ] && echo "Note: $n_conf CONFLICT(s) above were left alone — resolve them by hand."
exit 0
