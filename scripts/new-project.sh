#!/usr/bin/env bash
# new-project.sh — start a new project from this template.
#
# Usage: bash scripts/new-project.sh "/path/to/My New Project" ["Display Name"]
#
# Copies the template (minus git history, backups, sync/OS junk) into the
# target directory, replaces {{PROJECT_NAME}} and {{CREATED_DATE}} in the
# project files, makes scripts executable, and prints next steps.
# Refuses to write into a non-empty directory. Template-only files
# (new-project.sh, adopt-into.sh, template-lib.sh, tests/test_adopt.sh,
# tests/test_global_install.sh, global/, LICENSE) and the
# template's own record entries are left out; the new DECISIONS.md starts with
# one "Created from the Claude Process Template" entry.

set -eu

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "usage: $0 <target-dir> [project display name]" >&2; exit 1
fi

SRC="$(cd "$(dirname "$0")/.." && pwd)"
. "$SRC/scripts/template-lib.sh"
TARGET="$1"
if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "ERROR: $TARGET exists and is not empty. Pick a new or empty directory." >&2; exit 1
fi
mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
case "$TARGET/" in "$SRC/"*) echo "ERROR: target is inside the template." >&2; exit 1;; esac

NAME="${2:-$(basename "$TARGET")}"
TODAY="$(date +%Y-%m-%d)"

# Copy everything except history, backups, and junk.
(cd "$SRC" && tar -cf - \
   --exclude './.git' --exclude './backups' --exclude './.stfolder' \
   --exclude './.stversions' --exclude './.stignore*' --exclude './.claude/state' --exclude '.DS_Store' \
   --exclude './scripts/new-project.sh' --exclude './scripts/adopt-into.sh' \
   --exclude './scripts/template-lib.sh' --exclude './tests/test_adopt.sh' \
   --exclude './tests/test_global_install.sh' --exclude './global' --exclude './LICENSE' .) | (cd "$TARGET" && tar -xf -)
# Per-session notes from the template's own work don't belong in a new project.
rm -f "$TARGET/progress.md" "$TARGET/handoff.md"

# The template's own decisions/facts/lessons are not this project's history:
# keep header + format + worked example, drop the entries, empty MISTAKES instances.
for r in DECISIONS FACTS LESSONS; do
  tl_strip_record "$SRC/record/$r.md" "$TARGET/record/$r.md"
done
tl_strip_mistakes "$SRC/MISTAKES.md" "$TARGET/MISTAKES.md"
cat >> "$TARGET/record/DECISIONS.md" <<ENTRY

### D-001 — Created this project from the Claude Process Template
- Date: {{CREATED_DATE}}
- Decision: Started {{PROJECT_NAME}} from the Claude Process Template (scripts/new-project.sh): hard rules with tests, append-only record, mistakes register, brake and lifecycle hooks, slash commands.
- Why: The process holds up even when tired or when the AI is confident and wrong; starting with it costs less than retrofitting.
- Alternatives rejected:
  - Start from an empty folder — the rules, hooks and tests would have to be rebuilt by hand.
- Decided by: owner  (proposed by: owner)
- Status: active
- Supersedes: none
ENTRY

# Substitute placeholders in the files that carry them.
esc_name="$(printf '%s' "$NAME" | sed -e 's/[\/&|]/\\&/g')"
for f in CLAUDE.md MISTAKES.md record/DECISIONS.md record/FACTS.md record/LESSONS.md templates/handoff.md; do
  [ -f "$TARGET/$f" ] || continue
  sed -i.bak -e "s|{{PROJECT_NAME}}|$esc_name|g" -e "s|{{CREATED_DATE}}|$TODAY|g" "$TARGET/$f"
  rm -f "$TARGET/$f.bak"
done
chmod +x "$TARGET"/scripts/*.sh "$TARGET"/tests/*.sh

# Output check: the substitution actually happened.
left="$(grep -l '{{PROJECT_NAME}}' "$TARGET/CLAUDE.md" "$TARGET/MISTAKES.md" "$TARGET"/record/*.md 2>/dev/null || true)"
if [ -n "$left" ]; then
  echo "WARNING: {{PROJECT_NAME}} still present in: $left" >&2
fi
for r in DECISIONS FACTS LESSONS; do
  n="$(tl_real_entries "$TARGET/record/$r.md" | grep -vc 'Created this project from the Claude Process Template' || true)"
  [ "$n" = 0 ] || echo "WARNING: record/$r.md still has $n template entr(y|ies)" >&2
done
files="$(find "$TARGET" -type f | wc -l | tr -d ' ')"

cat <<MSG
Created "$NAME" at $TARGET ($files files).

Next steps:
  1. cd "$TARGET"
  2. Fill in the placeholders:      grep -rn "placeholder" CLAUDE.md docs/ record/
  3. Start version control:         git init && git add -A && git commit -m "Start from Claude process template"
     (the append-only test needs a commit to compare against)
  4. Run the tests:                 bash tests/run.sh
  5. Prove each test can fail:      follow tests/BREAK-IT-ONCE.md and date the checklist
  6. Set backup destination 2:      edit scripts/backup.conf (cloud folder / NAS / external drive)
  7. Run one backup and LOOK:       bash scripts/backup-memory.sh   (check both archives exist)
  8. Schedule backups 08:00/20:00:  bash scripts/install-backup-schedule.sh
  9. Open Claude Code here:         claude   (the hooks in .claude/settings.json load automatically;
     run /hooks once to confirm brake-check, record-guard, session-start,
     context-nudge, save-state and stop-check are listed)
MSG
