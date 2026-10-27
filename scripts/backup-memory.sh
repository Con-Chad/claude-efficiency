#!/usr/bin/env bash
# backup-memory.sh — Principle 8: back up the AI's memory to TWO places.
#
# Backs up the continuity files (CLAUDE.md, record/, MISTAKES.md, docs/,
# .claude/, templates/, plus BACKUP_EXTRA_PATHS and Claude's auto-memory) as a
# timestamped .tar.gz into two destinations, keeps the newest BACKUP_KEEP in
# each, then VERIFIES each archive by listing it (principle 4: check the
# output, not the mechanism). Exits non-zero if either copy fails.
#
# Usage: bash scripts/backup-memory.sh            (from anywhere)
# Config: scripts/backup.conf, or env vars BACKUP_DEST_1 / BACKUP_DEST_2 /
#         BACKUP_KEEP / BACKUP_EXTRA_PATHS / BACKUP_INCLUDE_CLAUDE_MEMORY.

set -u
umask 077

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NAME="$(basename "$PROJECT_DIR")"
SAFE_NAME="$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-*$//')"

# Env values win over config file values.
_env_d1="${BACKUP_DEST_1:-}"; _env_d2="${BACKUP_DEST_2:-}"; _env_keep="${BACKUP_KEEP:-}"
_env_extra="${BACKUP_EXTRA_PATHS:-}"; _env_mem="${BACKUP_INCLUDE_CLAUDE_MEMORY:-}"
CONF="$PROJECT_DIR/scripts/backup.conf"
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "$CONF"

DEST1="${_env_d1:-${BACKUP_DEST_1:-$HOME/claude-backups/$SAFE_NAME}}"
DEST2="${_env_d2:-${BACKUP_DEST_2:-$PROJECT_DIR/backups}}"
KEEP="${_env_keep:-${BACKUP_KEEP:-30}}"
EXTRA="${_env_extra:-${BACKUP_EXTRA_PATHS:-}}"
INCLUDE_MEM="${_env_mem:-${BACKUP_INCLUDE_CLAUDE_MEMORY:-1}}"
DEST1="${DEST1//<name>/$SAFE_NAME}"; DEST2="${DEST2//<name>/$SAFE_NAME}"

case "$KEEP" in ''|*[!0-9]*) echo "BACKUP_KEEP must be a number, got '$KEEP'" >&2; exit 1;; esac
[ "$KEEP" -lt 1 ] && KEEP=1

STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE="${SAFE_NAME}-${STAMP}.tar.gz"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/claude-backup.XXXXXX")" || exit 1
trap 'rm -rf -- "$STAGE"' EXIT
mkdir -p "$STAGE/$SAFE_NAME"

# ---- 1. Collect ----
included=0
for p in CLAUDE.md record MISTAKES.md docs .claude templates $EXTRA; do
  if [ -e "$PROJECT_DIR/$p" ]; then
    mkdir -p "$STAGE/$SAFE_NAME/$(dirname "$p")"
    cp -R "$PROJECT_DIR/$p" "$STAGE/$SAFE_NAME/$p"
    included=$((included + 1))
  else
    echo "note: $p not found, skipped"
  fi
done

if [ "$INCLUDE_MEM" = "1" ]; then
  slug="$(printf '%s' "$PROJECT_DIR" | sed 's/[^A-Za-z0-9]/-/g')"
  mem="$HOME/.claude/projects/$slug/memory"
  if [ -d "$mem" ]; then
    mkdir -p "$STAGE/$SAFE_NAME/_claude-auto-memory"
    cp -R "$mem/." "$STAGE/$SAFE_NAME/_claude-auto-memory/"
    included=$((included + 1))
  fi
fi

if [ "$included" -eq 0 ]; then
  echo "ERROR: nothing to back up in $PROJECT_DIR" >&2; exit 1
fi

expected="$(find "$STAGE/$SAFE_NAME" -type f | wc -l | tr -d ' ')"
tar -czf "$STAGE/$ARCHIVE" -C "$STAGE" "$SAFE_NAME" || { echo "ERROR: tar failed" >&2; exit 1; }

# ---- 2. Copy to both destinations, verify, rotate ----
r1="$(cd "$DEST1" 2>/dev/null && pwd -P || echo "$DEST1")"
r2="$(cd "$DEST2" 2>/dev/null && pwd -P || echo "$DEST2")"
if [ "$r1" = "$r2" ]; then
  echo "ERROR: both destinations are the same place ($r1) — that's one backup, not two." >&2; exit 1
fi

failures=0
for dest in "$DEST1" "$DEST2"; do
  if ! mkdir -p "$dest" 2>/dev/null || ! cp "$STAGE/$ARCHIVE" "$dest/$ARCHIVE"; then
    echo "FAIL  $dest — could not write archive" >&2; failures=$((failures + 1)); continue
  fi
  # Output check: the archive at the destination lists the expected file count.
  got="$(tar -tzf "$dest/$ARCHIVE" 2>/dev/null | grep -v '/$' | wc -l | tr -d ' ')"
  if [ "$got" != "$expected" ] || [ "$got" = "0" ]; then
    echo "FAIL  $dest/$ARCHIVE — lists $got files, expected $expected" >&2; failures=$((failures + 1)); continue
  fi
  size="$(du -h "$dest/$ARCHIVE" | cut -f1 | tr -d ' ')"
  echo "OK    $dest/$ARCHIVE  ($got files, $size)"
  # Rotate: keep newest $KEEP archives for this project.
  ls -1t "$dest/${SAFE_NAME}-"*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | while IFS= read -r old; do
    rm -f -- "$old"
  done
done

if [ "$failures" -gt 0 ]; then
  echo "BACKUP INCOMPLETE: $failures destination(s) failed." >&2; exit 1
fi
echo "Backup complete: 2/2 destinations verified ($expected files each)."
