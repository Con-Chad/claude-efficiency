#!/usr/bin/env bash
# Hard rule H3: no secrets in the repo.
# Scans tracked + untracked-not-ignored text files (or every file outside
# .git/backups/node_modules if not a git repo) for common credential patterns.
# A line containing "secret-scan: allow" is ignored (use sparingly, explain why).
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 1

list_files() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    { git ls-files; git ls-files --others --exclude-standard; } | sort -u
  else
    find . -type f \
      -not -path './.git/*' -not -path './backups/*' -not -path '*/node_modules/*' \
      -not -path './.stversions/*' -not -path './.claude/state/*' -not -name '.DS_Store' | sed 's|^\./||'
  fi
}

# Each pattern: label|extended-regex
PATTERNS='AWS access key id|AKIA[0-9A-Z]{16}
OpenAI/Anthropic-style key|(^|[^A-Za-z0-9_-])sk-[A-Za-z0-9_-]{20,}
GitHub token|(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}
GitHub fine-grained token|github_pat_[A-Za-z0-9_]{22,}
Slack token|xox[abposr]-[A-Za-z0-9-]{10,}
Private key block|-----BEGIN ([A-Z]+ )*PRIVATE KEY-----
Password assignment|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][[:space:]]*[=:][[:space:]]*["'"'"']?[^[:space:]"'"'"'$<{(]{4,}'

hits=0
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
list_files > "$tmp"
nfiles="$(wc -l < "$tmp" | tr -d ' ')"

while IFS='|' read -r label regex; do
  [ -z "$label" ] && continue
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    m="$(grep -InE -- "$regex" "$f" 2>/dev/null | grep -v 'secret-scan: allow')"
    if [ -n "$m" ]; then
      printf '%s\n' "$m" | while IFS= read -r line; do
        lineno="${line%%:*}"
        echo "FAIL: $label in $f:$lineno (value not shown)"
      done
      hits=$((hits + 1))
    fi
  done < "$tmp"
done <<EOF_PATTERNS
$PATTERNS
EOF_PATTERNS

if [ "$hits" -gt 0 ]; then
  echo "Secrets found. Move them to .env (git-ignored), rotate any that were ever committed or synced."
  exit 1
fi
echo "ok: scanned $nfiles files, no secret patterns found"
