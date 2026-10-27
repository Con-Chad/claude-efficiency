#!/usr/bin/env bash
# Hard rule H2: record/*.md and MISTAKES.md are append-only.
# Fails if any non-blank line that exists in git HEAD has been changed or
# removed (staged or unstaged). Additions are fine. A deleted file fails.
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 1

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "skipped: not a git repo yet (run: git init && git add -A && git commit)"; exit 77
fi
if ! git rev-parse --verify -q HEAD >/dev/null; then
  echo "skipped: git repo has no commits yet — nothing to compare against"; exit 77
fi

status=0
files="MISTAKES.md $(cd "$ROOT" && ls record/*.md 2>/dev/null | tr '\n' ' ')"
# Also catch record files that existed at HEAD but are now deleted.
files="$files $(git ls-tree -r --name-only HEAD -- record/ MISTAKES.md 2>/dev/null | tr '\n' ' ')"
checked=""
for f in $files; do
  case " $checked " in *" $f "*) continue;; esac
  checked="$checked $f"
  git cat-file -e "HEAD:$f" 2>/dev/null || continue   # new file: nothing to protect yet
  removed="$(git diff --no-color -U0 HEAD -- "$f" | grep -E '^-' | grep -vE '^---( |$)' | grep -vE '^-[[:space:]]*$')"
  if [ -n "$removed" ]; then
    echo "FAIL: $f — existing entries were edited or removed (append-only, rule H2):"
    printf '%s\n' "$removed" | head -20 | sed 's/^/    /'
    echo "  Fix: restore with 'git checkout HEAD -- \"$f\"' and add a NEW entry that supersedes the old one."
    status=1
  fi
done
[ $status -eq 0 ] && echo "ok: record files and MISTAKES.md only have additions vs HEAD"
exit $status
