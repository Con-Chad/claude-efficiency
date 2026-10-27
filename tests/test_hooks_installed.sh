#!/usr/bin/env bash
# Hard rules H1/H2/H4 (enforcement exists): .claude/settings.json must register
# every hook script on the right event, and every hook script must be
# executable. A hook that isn't registered silently does nothing.
#   PreToolUse(Bash)            -> brake-check.sh   (H1)
#   PreToolUse(Edit|Write|...)  -> record-guard.sh  (H2)
#   SessionStart                -> session-start.sh
#   PostToolUse                 -> context-nudge.sh
#   PreCompact + SessionEnd     -> save-state.sh
#   Stop                        -> stop-check.sh    (H4 backstop)
set -u
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 1
S=".claude/settings.json"
status=0

if [ ! -f "$S" ]; then echo "FAIL: $S missing"; exit 1; fi

# event | matcher regex the entry's matcher must satisfy ("" = any) | script
CHECKS='PreToolUse|(^|\|)Bash(\||$)|^\*$|^$|brake-check.sh
PreToolUse|(^|\|)Edit(\||$)|^\*$|^$|record-guard.sh
PreToolUse|(^|\|)Write(\||$)|^\*$|^$|record-guard.sh
SessionStart||session-start.sh
PostToolUse|^\*$|^$|^\.\*$|context-nudge.sh
PreCompact||save-state.sh
SessionEnd||save-state.sh
Stop||stop-check.sh'

if command -v jq >/dev/null 2>&1; then
  jq empty "$S" 2>/dev/null || { echo "FAIL: $S is not valid JSON"; exit 1; }
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ev="${line%%|*}"; rest="${line#*|}"; script="${rest##*|}"; mre="${rest%|*}"
    n="$(jq --arg ev "$ev" --arg re "$mre" --arg sc "scripts/$script" '[.hooks[$ev][]?
          | select($re == "" or ((.matcher // "") | test($re)))
          | .hooks[]? | select(.type == "command" and ((.command // "") | contains($sc)))] | length' "$S")"
    [ "${n:-0}" -ge 1 ] || { echo "FAIL: no $ev hook${mre:+ (matcher must match /$mre/)} runs scripts/$script"; status=1; }
  done <<CHECKS_EOF
$CHECKS
CHECKS_EOF
else
  # Fallback without jq: structural grep on the flattened file.
  flat="$(tr -d '\n' < "$S")"
  printf '%s' "$flat" | grep -qE '"PreToolUse"[^]]*"matcher"[[:space:]]*:[[:space:]]*"Bash"[^]]*brake-check\.sh' \
    || { echo "FAIL: no PreToolUse/Bash hook running brake-check.sh (grep fallback)"; status=1; }
  printf '%s' "$flat" | grep -qE '"matcher"[[:space:]]*:[[:space:]]*"[^"]*Edit[^"]*"[^]]*record-guard\.sh' \
    || { echo "FAIL: no Edit/Write hook running record-guard.sh (grep fallback)"; status=1; }
  for pair in SessionStart:session-start PostToolUse:context-nudge PreCompact:save-state SessionEnd:save-state Stop:stop-check; do
    printf '%s' "$flat" | grep -qE "\"${pair%%:*}\".*${pair#*:}\\.sh" \
      || { echo "FAIL: ${pair%%:*} hook for ${pair#*:}.sh not registered (grep fallback)"; status=1; }
  done
fi

for s in brake-check record-guard session-start context-nudge save-state stop-check; do
  f="scripts/$s.sh"
  if [ ! -f "$f" ]; then echo "FAIL: $f missing"; status=1
  elif [ ! -x "$f" ]; then echo "FAIL: $f is not executable (chmod +x $f)"; status=1
  fi
done
[ -f scripts/hook-lib.sh ] || { echo "FAIL: scripts/hook-lib.sh missing (sourced by the hooks)"; status=1; }

[ $status -eq 0 ] && echo "ok: all 6 hook scripts registered on their events and executable"
exit $status
