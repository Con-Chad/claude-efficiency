#!/usr/bin/env bash
# adopt-into.sh — add this template's process (record, mistakes register,
# hooks, tests, rules, slash commands) to an EXISTING project.
#
# Usage: bash scripts/adopt-into.sh <target-dir> [--dry-run]
#
# Additive only: never overwrites or deletes a file in the target. It prints
# the plan first (create / merge / append / keep / CONFLICT); --dry-run stops
# there. Running it twice changes nothing the second time.
#
#   - Missing template files are copied. A same-named file that differs is
#     left alone and reported as a CONFLICT with a suggestion.
#   - Tests: if the project already has its own test runner (tests/run.sh or
#     tests/test_*.sh), the template's tests go to tests/process/ with their
#     own runner (tests/process/run.sh); stop-check.sh prefers that runner,
#     and copied docs/commands/rules are rewritten to point at it.
#   - record/*.md are created with header/format only (template entries
#     stripped) plus one "Adopted the Claude Process Template" decision.
#   - CLAUDE.md: created if absent, else a condensed block is appended
#     between <!-- BEGIN/END claude-process-template --> markers.
#   - .claude/settings.json: merged with jq (hooks appended unless the same
#     command is already registered; permissions.allow unioned); the original
#     is kept as .claude/settings.json.pre-adopt.
#   - .gitignore: missing lines appended under "# claude-process-template".
# Requires jq. Refuses /, $HOME, ~/Downloads, the template itself, and any
# directory that isn't the top level of a git repo.

set -eu

usage() { echo "usage: $0 <target-dir> [--dry-run]" >&2; exit 1; }
TARGET=""; DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help) usage ;;
    -*) echo "ERROR: unknown option $a" >&2; usage ;;
    *) [ -z "$TARGET" ] || usage; TARGET="$a" ;;
  esac
done
[ -n "$TARGET" ] || usage

SRC="$(cd "$(dirname "$0")/.." && pwd -P)"
. "$SRC/scripts/template-lib.sh"

# ---------- refusals (before anything else) ----------
[ -d "$TARGET" ] || { echo "ERROR: $TARGET is not a directory." >&2; exit 1; }
T="$(cd "$TARGET" && pwd -P)"
H="$(cd "$HOME" && pwd -P)"
case "$T" in
  /) echo "REFUSED: will not adopt into / (the filesystem root)." >&2; exit 3 ;;
  "$H") echo "REFUSED: will not adopt into your home directory. cd into a project folder first." >&2; exit 3 ;;
  "$H/Downloads") echo "REFUSED: will not adopt into ~/Downloads. Use a real project folder." >&2; exit 3 ;;
esac
case "$T/" in "$SRC/"*) echo "REFUSED: target is the template itself (or inside it)." >&2; exit 3 ;; esac
top="$(git -C "$T" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$top" ] && top="$(cd "$top" && pwd -P)"
if [ "$top" != "$T" ]; then
  if [ -z "$top" ]; then
    echo "REFUSED: $T is not a git repository. The append-only test and 'review git diff' need git." >&2
    echo "         Run:  git init && git add -A && git commit -m 'Before adopting process'   then re-run." >&2
  else
    echo "REFUSED: $T is inside the git repo $top but not its top level. Run it at the repo root." >&2
  fi
  exit 3
fi
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (to merge .claude/settings.json). Install it: brew install jq" >&2; exit 1; }

NAME="$(basename "$T")"
TODAY="$(date +%Y-%m-%d)"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/adopt.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
PLAN="$STAGE/.plan"; : > "$PLAN"
plan() { printf '%s|%s|%s\n' "$1" "$2" "${3:-}" >> "$PLAN"; }   # action|path|note

# ---------- test layout ----------
if [ -f "$T/tests/process/run.sh" ]; then MODE=process
elif [ -f "$T/tests/test_hooks_installed.sh" ]; then MODE=standard
elif [ -f "$T/tests/run.sh" ] || ls "$T"/tests/test_*.sh >/dev/null 2>&1; then MODE=process
else MODE=standard; fi
if [ $MODE = process ]; then TDIR=tests/process; else TDIR=tests; fi
RUNNER="bash $TDIR/run.sh"

# Rewrite template paths to the process layout (docs/commands/rules/CLAUDE.md).
relayout() {
  [ $MODE = process ] || return 0
  sed -E -i.rl 's#tests/(run\.sh|BREAK-IT-ONCE\.md|test_[a-z_]+\.sh)#tests/process/\1#g' "$1" && rm -f "$1.rl"
}

# stage_file <dest-rel> <staged-file> <conflict-suggestion>
stage_file() {
  local dest="$1" staged="$2" hint="$3"
  if [ ! -e "$T/$dest" ]; then
    mkdir -p "$(dirname "$STAGE/$dest")"; mv "$staged" "$STAGE/$dest"; plan create "$dest"
  elif cmp -s "$staged" "$T/$dest"; then
    plan same "$dest"
  else
    plan CONFLICT "$dest" "$hint"
  fi
  rm -f "$staged"
}

TMPF="$STAGE/.tmp"
# ---------- plain copies ----------
list_copies() {
  ( cd "$SRC"
    for f in scripts/*.sh scripts/backup.conf tests/* docs/* .claude/commands/* .claude/rules/* templates/handoff.md; do
      [ -f "$f" ] || continue
      case " $TL_TEMPLATE_ONLY " in *" $f "*) continue ;; esac
      echo "$f"
    done )
}
for f in $(list_copies); do
  dest="$f"; case "$f" in tests/*) dest="$TDIR/${f#tests/}" ;; esac
  cp -p "$SRC/$f" "$TMPF"
  case "$f" in templates/*) tl_subst "$TMPF" "$NAME" "$TODAY" ;; esac
  case "$f" in docs/*|.claude/*|tests/*.md) relayout "$TMPF" ;; esac
  case "$f" in
    scripts/*) hint="compare with the template's $f; the hooks in settings.json call this path, so make sure yours does the same job (or rename yours and re-run)" ;;
    tests/*) hint="your file was kept; diff it against the template's $f and merge by hand if you want the template's version" ;;
    *) hint="your file was kept; merge in what you want from the template's $f by hand" ;;
  esac
  stage_file "$dest" "$TMPF" "$hint"
done

# ---------- MISTAKES.md ----------
tl_strip_mistakes "$SRC/MISTAKES.md" "$TMPF"; tl_subst "$TMPF" "$NAME" "$TODAY"
stage_file MISTAKES.md "$TMPF" "your MISTAKES.md was kept; copy the P1-P3 patterns from the template's MISTAKES.md if it lacks them"

# ---------- record/ (header only; DECISIONS gets the adoption entry later) ----------
for r in FACTS LESSONS DECISIONS; do
  dest="record/$r.md"
  if [ -e "$T/$dest" ]; then
    if [ $r = DECISIONS ] && grep -q 'Adopted the Claude Process Template' "$T/$dest"; then plan same "$dest"
    elif [ $r != DECISIONS ] && { tl_strip_record "$SRC/$dest" "$TMPF"; tl_subst "$TMPF" "$NAME" "$TODAY"; cmp -s "$TMPF" "$T/$dest"; }; then plan same "$dest"
    else plan keep "$dest" "exists — left untouched (append-only record)"; fi
    continue
  fi
  mkdir -p "$STAGE/record"
  tl_strip_record "$SRC/$dest" "$STAGE/$dest"; tl_subst "$STAGE/$dest" "$NAME" "$TODAY"
  plan create "$dest" "$( [ $r = DECISIONS ] && echo 'header only + one "Adopted the Claude Process Template" entry' || echo 'header/format only')"
done

# ---------- CLAUDE.md ----------
if [ ! -e "$T/CLAUDE.md" ]; then
  cp "$SRC/CLAUDE.md" "$STAGE/CLAUDE.md"; tl_subst "$STAGE/CLAUDE.md" "$NAME" "$TODAY"; relayout "$STAGE/CLAUDE.md"
  plan create CLAUDE.md "from the template, project name \"$NAME\""
elif grep -q '<!-- BEGIN claude-process-template -->' "$T/CLAUDE.md" || grep -q '^## 1\. Hard rules (non-negotiable)' "$T/CLAUDE.md"; then
  plan same CLAUDE.md
else
  BIO="$TDIR/BREAK-IT-ONCE.md"
  cat > "$STAGE/CLAUDE.md.block" <<BLOCK

<!-- BEGIN claude-process-template -->
## Process (from the Claude Process Template — adopted $TODAY)
Detail lives in \`docs/\` (VERIFICATION, REVIEW, BRAKES, CONTEXT). At session start the hook prints the \`MISTAKES.md\` patterns, the last 3 decisions and \`handoff.md\` "Next": read the patterns first, treat those decisions as settled, start from "Next".

### Hard rules
| # | Rule | Enforced by |
|---|------|-------------|
| H1 | No irreversible action (spend, delete, message a real person, push/deploy live) without an explicit yes for that exact action. | \`scripts/brake-check.sh\` hook + tests |
| H2 | \`record/*.md\` and \`MISTAKES.md\` are append-only; a correction is a NEW entry. | \`scripts/record-guard.sh\` hook + \`test_append_only.sh\` |
| H3 | No secrets in the repo; use \`.env\` (git-ignored). | \`test_no_secrets.sh\` |
| H4 | Never report "done" on the mechanism (exit 0, green tick). Report the output check you did. | \`/verify\`; Stop hook \`scripts/stop-check.sh\` |
| H5 | Facts come from a primary source and go in \`record/FACTS.md\` with source + date checked. | \`/fact\`; review |
Process tests: \`$RUNNER\` (foreground) before declaring a change done. Every test must have been broken once on purpose (\`$BIO\`).

### Check the output, not the mechanism
"It ran" is not "it worked": open the file, see the email in the inbox, load the live page, compare the numbers, see the test fail when broken. Say what you checked and what you saw. Table: \`docs/VERIFICATION.md\`; use \`/verify\`.

### Show before you build
Anything big (>1 h, >3 files/~200 lines, user-visible, costs money, new dependency, architecture, hard to undo) → \`/sketch\` first and STOP for the owner's reaction.

### Brakes
Explicit yes **every time** for: spending, deleting, messaging real people/companies, pushing/deploying/publishing/merging to anything live, changing infra/DNS/billing/permissions. "Yes" covers exactly what was proposed, once. Hook blocked it → ask → on yes re-run the identical command prefixed \`BRAKE_APPROVED=1 \`. New contact → pre-check in \`docs/BRAKES.md\`. Owner tired or it's late → prepare, don't do.

### The record (append-only, write as you go)
Decision (+ what was rejected) → \`/decision\` · fact → \`/fact\` · lesson / who was told → \`/lesson\` · something went wrong → \`/mistake\` (classify by pattern). Append at the end; never edit an entry or its status — supersede it.

### Independent review
Before shipping, ordering or sending anything that matters: a second, independent session checks against the PRIMARY sources, never this session's summary. \`docs/REVIEW.md\`, \`/review\`.

### Context hygiene
\`grep -n\` then read line ranges, not whole files; big logs/dumps → a subagent. When the context-nudge hook fires: finish the change, \`/handoff\`, log decisions, suggest \`/compact\`. Files survive, the conversation doesn't. Guide: \`docs/CONTEXT.md\`.

### Working method
- **Queue:** every request is a queue item; new requests and corrections join the END (unless the owner says stop / do this first). A brake or sketch pauses only that item. Stop only when all items are done (verified) or paused awaiting the owner. Queue lives in \`handoff.md\`.
- **One pass:** list every file you need and read them together, make all edits, run \`$RUNNER\` once.
- End of session: \`/learn\`, then \`/handoff\` if work continues.
<!-- END claude-process-template -->
BLOCK
  plan append CLAUDE.md "condensed process block ($(wc -l < "$STAGE/CLAUDE.md.block" | tr -d ' ') lines) between BEGIN/END markers"
fi

# ---------- .claude/settings.json ----------
TS="$STAGE/.template-settings.json"
if [ $MODE = process ]; then
  jq '.permissions.allow += ["Bash(bash tests/process/run.sh)", "Bash(bash tests/process/run.sh:*)"]' "$SRC/.claude/settings.json" > "$TS"
else cp "$SRC/.claude/settings.json" "$TS"; fi
if [ ! -e "$T/.claude/settings.json" ]; then
  mkdir -p "$STAGE/.claude"; cp "$TS" "$STAGE/.claude/settings.json"; plan create .claude/settings.json "template hooks + permissions"
else
  jq empty "$T/.claude/settings.json" 2>/dev/null || { echo "ERROR: $T/.claude/settings.json is not valid JSON — fix it first; nothing was changed." >&2; exit 1; }
  jq --slurpfile tpl "$TS" '
    def uniq_keep_order: reduce .[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);
    def cmds($ev): [ (.hooks[$ev] // [])[] | (.hooks // [])[] | .command ];
    $tpl[0] as $t
    | reduce ($t.hooks // {} | to_entries[]) as $e (.;
        reduce $e.value[] as $entry (.;
          cmds($e.key) as $have
          | [ $entry.hooks[] | select(.command as $c | ($have | any(.[]; . == $c)) | not) ] as $new
          | if ($new | length) > 0
            then .hooks[$e.key] = ((.hooks[$e.key] // []) + [ $entry + {hooks: $new} ])
            else . end))
    | if ($t.permissions.allow // []) | length > 0
      then .permissions.allow = (((.permissions.allow // []) + $t.permissions.allow) | uniq_keep_order)
      else . end' "$T/.claude/settings.json" > "$STAGE/settings.merged"
  jq empty "$STAGE/settings.merged" || { echo "ERROR: merged settings are not valid JSON — nothing was changed." >&2; exit 1; }
  if [ "$(jq -S . "$STAGE/settings.merged")" = "$(jq -S . "$T/.claude/settings.json")" ]; then
    plan same .claude/settings.json
  else
    nh=$(( $(jq '[.hooks[]?[]?.hooks[]?] | length' "$STAGE/settings.merged") - $(jq '[.hooks[]?[]?.hooks[]?] | length' "$T/.claude/settings.json") ))
    np=$(( $(jq '.permissions.allow // [] | length' "$STAGE/settings.merged") - $(jq '.permissions.allow // [] | length' "$T/.claude/settings.json") ))
    plan merge .claude/settings.json "+$nh hook(s), +$np permission(s); existing entries untouched; original saved as .claude/settings.json.pre-adopt"
  fi
fi

# ---------- .gitignore ----------
if [ ! -e "$T/.gitignore" ]; then
  cp "$SRC/.gitignore" "$STAGE/.gitignore"; plan create .gitignore
else
  : > "$STAGE/gitignore.add"
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    grep -qxF -- "$line" "$T/.gitignore" || printf '%s\n' "$line" >> "$STAGE/gitignore.add"
  done < "$SRC/.gitignore"
  if [ -s "$STAGE/gitignore.add" ]; then plan append .gitignore "+$(wc -l < "$STAGE/gitignore.add" | tr -d ' ') line(s) under '# claude-process-template'"
  else plan same .gitignore; fi
fi

# ---------- print the plan ----------
count() { grep -c "^$1|" "$PLAN" || true; }
n_create=$(count create); n_merge=$(count merge); n_append=$(count append)
n_keep=$(count keep); n_conf=$(count CONFLICT); n_same=$(count same)
echo "Adopt Claude Process Template -> $T"
if [ $MODE = process ]; then
  echo "Test layout: SEPARATE — the project already has its own tests, so the process tests go in tests/process/"
  echo "             with their own runner (bash tests/process/run.sh). Your tests/run.sh is not touched."
else
  echo "Test layout: standard — process tests in tests/, runner: bash tests/run.sh"
fi
echo
while IFS='|' read -r act path note; do
  case "$act" in
    create)   printf '  create    %s%s\n' "$path" "${note:+  ($note)}" ;;
    merge)    printf '  merge     %s  (%s)\n' "$path" "$note" ;;
    append)   printf '  append    %s  (%s)\n' "$path" "$note" ;;
    keep)     printf '  keep      %s  (%s)\n' "$path" "$note" ;;
    CONFLICT) printf '  CONFLICT  %s — exists with different content; NOT copied.\n            Suggestion: %s\n' "$path" "$note" ;;
  esac
done < "$PLAN"
[ "$n_same" -gt 0 ] && echo "  ($n_same item(s) already in place, identical — nothing to do)"
echo
echo "Summary: $n_create create, $n_merge merge, $n_append append, $n_keep keep, $n_conf conflict, $n_same already in place."

if [ $((n_create + n_merge + n_append)) -eq 0 ]; then
  echo "Nothing to do — this project has already adopted the process (or everything is in conflict, see above)."
  exit 0
fi
if [ $DRY -eq 1 ]; then echo "DRY RUN — nothing was changed."; exit 0; fi

# ---------- adoption decision (needs the final plan) ----------
if grep -q '^create|record/DECISIONS.md|' "$PLAN"; then
  added="$(grep -E '^(create|merge|append)\|' "$PLAN" | cut -d'|' -f2 | sed -E 's#^(scripts|tests/process|tests|docs|\.claude/commands|\.claude/rules)/.*#\1/#' | sort -u | tr '\n' ' ' | sed 's/ $//; s/ /, /g')"
  conflicts="$(grep '^CONFLICT|' "$PLAN" | cut -d'|' -f2 | tr '\n' ' ' | sed 's/ $//; s/ /, /g')"
  cat >> "$STAGE/record/DECISIONS.md" <<ENTRY

### D-001 — Adopted the Claude Process Template
- Date: $TODAY
- Decision: Added the Claude Process Template's process to this existing project with scripts/adopt-into.sh (additive only — no existing file overwritten). Added/merged: $added. Process tests run with \`$RUNNER\`.
- Why: Hard rules with tests, an append-only record, a mistakes register, brakes on irreversible actions, and output-checked work, without restarting the project.
- Alternatives rejected:
  - Copy the whole template over the project — would overwrite existing files.
  - Keep working without the process — decisions and mistakes stay in chat and get lost.
- Conflicts skipped (project's own file kept): ${conflicts:-none}
- Decided by: owner  (proposed by: AI via /adopt-process)
- Status: active
- Supersedes: none
ENTRY
fi

# ---------- apply (never overwrite: re-check existence at write time) ----------
while IFS='|' read -r act path note; do
  case "$act" in
    create)
      if [ -e "$T/$path" ]; then echo "  skipped $path — appeared while running"; continue; fi
      mkdir -p "$(dirname "$T/$path")"
      cp -p "$STAGE/$path" "$T/$path"
      case "$path" in *.sh) chmod +x "$T/$path" ;; esac ;;
    merge)
      [ -e "$T/.claude/settings.json.pre-adopt" ] || cp -p "$T/.claude/settings.json" "$T/.claude/settings.json.pre-adopt"
      cp "$STAGE/settings.merged" "$T/.claude/settings.json.adopt-tmp"
      mv -f "$T/.claude/settings.json.adopt-tmp" "$T/.claude/settings.json" ;;
    append)
      case "$path" in
        CLAUDE.md) cat "$STAGE/CLAUDE.md.block" >> "$T/CLAUDE.md" ;;
        .gitignore)
          { [ -n "$(tail -c1 "$T/.gitignore")" ] && echo; echo; echo "# claude-process-template"; cat "$STAGE/gitignore.add"; } >> "$T/.gitignore" ;;
      esac ;;
  esac
done < "$PLAN"

# Output check: what we promised is actually there.
bad=0
for s in brake-check record-guard session-start context-nudge save-state stop-check; do
  [ -x "$T/scripts/$s.sh" ] || { echo "WARNING: scripts/$s.sh missing or not executable"; bad=1; }
done
jq empty "$T/.claude/settings.json" || { echo "WARNING: .claude/settings.json is not valid JSON"; bad=1; }
[ -f "$T/$TDIR/run.sh" ] || { echo "WARNING: $TDIR/run.sh missing"; bad=1; }
[ $bad -eq 0 ] && echo "Applied. Hook scripts present and executable; settings.json valid JSON."

cat <<NEXT

Next steps:
  1. Review what changed:   git -C "$T" status && git -C "$T" diff
  2. Run the process tests: cd "$T" && $RUNNER
     (test_append_only skips until there is a commit)
  3. Commit:                git add -A && git commit -m "Adopt Claude process template"
  4. Break each test once:  follow $TDIR/BREAK-IT-ONCE.md and date the checklist
  5. Fill in placeholders:  grep -rn "placeholder" CLAUDE.md docs/ record/
NEXT
[ "$n_conf" -gt 0 ] && echo "  6. Resolve the $n_conf CONFLICT(s) listed above by hand."
[ $MODE = process ] && echo "  Note: the Stop hook runs '$RUNNER'. To include your own suite too, set STOP_CHECK_CMD (see scripts/stop-check.sh)."
exit 0
