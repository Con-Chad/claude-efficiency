#!/usr/bin/env bash
# brake-check.sh — Claude Code PreToolUse hook for the Bash tool.
#
# Principle 7 (Brakes): anything irreversible needs an explicit yes, every time.
# This script reads the hook payload (JSON on stdin), pulls out
# tool_input.command, and BLOCKS (exit 2, reason on stderr) when the command
# matches an irreversible pattern. Claude Code feeds the stderr text back to
# Claude, which must then ask the user.
#
# Letting an approved command through:
#   - The command itself starts with   BRAKE_APPROVED=1 <command>
#     (this is how Claude re-runs it after the user says yes), or
#   - the hook process has BRAKE_APPROVED=1 in its environment (manual/testing).
#
# Exit codes: 0 = allow, 2 = block. Anything else is a hook error (non-blocking).
#
# Testing/fallback: set BRAKE_NO_JQ=1 to force the grep/sed JSON parser.
# This is a seatbelt, not a lock: it catches the common forms of dangerous
# commands. docs/BRAKES.md is the full policy; the human yes is the real brake.

set -u

payload="$(cat)"

# ---------- 1. Extract tool_input.command ----------
cmd=""
if [ "${BRAKE_NO_JQ:-0}" != "1" ] && command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null)"
else
  # Fallback: flatten to one line, grab the "command":"..." string value,
  # then undo the common JSON escapes.
  flat="$(printf '%s' "$payload" | tr '\n' ' ')"
  cmd="$(printf '%s' "$flat" \
    | sed -nE 's/.*"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' \
    | sed -e 's/\\n/\
/g' -e 's/\\t/	/g' -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
fi

# Nothing to check (not a Bash call, or unparseable payload) -> allow.
[ -z "$cmd" ] && exit 0

# ---------- 2. Explicit approval ----------
if [ "${BRAKE_APPROVED:-0}" = "1" ]; then
  exit 0
fi
if printf '%s' "$cmd" | grep -qE '^[[:space:]]*BRAKE_APPROVED=1[[:space:]]'; then
  exit 0
fi

# ---------- 3. Pattern checks ----------
# S = "this word is in command position": start of line or after ; & | ( { `
# or $( — optionally preceded by sudo/env/nohup/time and VAR=value prefixes.
# This keeps `git commit -m "before git push"` from tripping the git-push rule.
S='(^|[;&|({`]|\$\()[[:space:]]*((sudo|env|command|exec|time|nohup)[[:space:]]+)*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*'
GITOPTS='([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
E='([[:space:]]|$)'
# rm counts in command position, or as the command run by xargs / find -exec.
RMPRE="(${S}|(xargs|-exec|-execdir)[[:space:]]+([^;&|]*[[:space:]])?)"

has()  { printf '%s' "$cmd" | grep -qE  -- "$1"; }
hasi() { printf '%s' "$cmd" | grep -qiE -- "$1"; }

label=""

# --- git ---
if has "${S}git${GITOPTS}[[:space:]]+push${E}"; then
  if has '[[:space:]](--force|--force-with-lease|--mirror|-f|--delete|-d)([[:space:]=]|$)' \
     || has "${S}git${GITOPTS}[[:space:]]+push[[:space:]].*[[:space:]]\+[^[:space:]]+"; then
    label="git force-push / remote delete (rewrites or destroys remote history)"
  else
    label="git push (publishes commits to a shared remote)"
  fi
elif has "${S}git${GITOPTS}[[:space:]]+reset[[:space:]]+([^;&|]*[[:space:]])?--hard${E}"; then
  label="git reset --hard (discards uncommitted work)"
elif has "${S}git${GITOPTS}[[:space:]]+branch[[:space:]]+([^;&|]*[[:space:]])?(-D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)${E}"; then
  label="git branch -D (force-deletes a branch)"
elif has "${S}git${GITOPTS}[[:space:]]+clean[[:space:]]+([^;&|]*[[:space:]])?-[a-zA-Z]*f"; then
  label="git clean -f (deletes untracked files)"

# --- filesystem ---
elif has "${RMPRE}"'rm[[:space:]]+([^;&|]*[[:space:]])?(-[[:alpha:]]*[rR][[:alpha:]]*f[[:alpha:]]*|-[[:alpha:]]*f[[:alpha:]]*[rR][[:alpha:]]*)([[:space:]]|$)' \
  || has "${RMPRE}"'rm[[:space:]]+([^;&|]*[[:space:]])?(-[rR]|--recursive)[[:space:]]+([^;&|]*[[:space:]])?(-f|--force)([[:space:]]|$)' \
  || has "${RMPRE}"'rm[[:space:]]+([^;&|]*[[:space:]])?(-f|--force)[[:space:]]+([^;&|]*[[:space:]])?(-[rR]|--recursive)([[:space:]]|$)'; then
  label="rm -rf (recursive forced delete)"
elif has "${S}(mkfs[.a-z0-9]*|diskutil[[:space:]]+(erase[a-zA-Z]*|zeroDisk|secureErase))${E}" \
  || has "${S}dd[[:space:]][^;&|]*of=/dev/"; then
  label="disk wipe / format"

# --- databases ---
elif hasi 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)([[:space:]]|$)' \
  || hasi 'TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?[A-Za-z_"`]' \
  || hasi "${S}(dropdb|dropuser)${E}"; then
  label="database drop / truncate (destroys data)"

# --- email ---
elif has "${S}(mail|mailx|sendmail|msmtp|mutt|swaks)${E}"; then
  label="sending email"

# --- packages / releases / deploys (pushing live) ---
elif has "${S}(npm|yarn|pnpm|bun)[[:space:]]+([^;&|]*[[:space:]])?publish${E}" \
  || has "${S}(cargo[[:space:]]+publish|twine[[:space:]]+upload|gem[[:space:]]+push|docker[[:space:]]+push|pod[[:space:]]+trunk[[:space:]]+push)${E}"; then
  label="publishing a package/image to a public registry"
elif has "${S}(terraform|tofu)[[:space:]]+([^;&|]*[[:space:]])?(apply|destroy)${E}"; then
  label="terraform apply/destroy (changes real infrastructure)"
elif has "${S}kubectl[[:space:]]+([^;&|]*[[:space:]])?(delete|drain)${E}" \
  || has "${S}helm[[:space:]]+([^;&|]*[[:space:]])?(uninstall|delete)${E}"; then
  label="kubectl/helm delete (removes live cluster resources)"
elif has "${S}aws[[:space:]]+[^;&|]*[[:space:]](rm|rb|[a-z0-9-]*(delete|terminate|remove|purge|destroy|deregister|revoke)[a-z0-9-]*)${E}"; then
  label="aws destructive operation"
elif has "${S}gcloud[[:space:]]+[^;&|]*[[:space:]]([a-z0-9-]*(delete|remove|destroy|purge)[a-z0-9-]*|reset|deploy)${E}" \
  || has "${S}gsutil[[:space:]]+([^;&|]*[[:space:]])?(rm|rb)${E}"; then
  label="gcloud destructive operation / deploy"
elif has "${S}(vercel|netlify)[[:space:]][^;&|]*--prod" \
  || has "${S}(firebase|flyctl|fly|wrangler)[[:space:]]+([^;&|]*[[:space:]])?(deploy|publish)${E}" \
  || has "${S}gh[[:space:]]+(pr[[:space:]]+merge|release[[:space:]]+create|repo[[:space:]]+delete)${E}"; then
  label="deploy / merge / release (pushing live)"
fi

# --- outbound HTTP writes (only if nothing above matched) ---
if [ -z "$label" ]; then
  http_write=0
  if has "${S}curl${E}"; then
    if hasi '(-X|--request)[[:space:]]*=?["'"'"']?(POST|PUT|DELETE|PATCH)' \
       || has '[[:space:]](-d|--data|--data-raw|--data-binary|--data-urlencode|--json|-F|--form|-T|--upload-file)([[:space:]=]|$)'; then
      http_write=1
    fi
  fi
  if has "${S}wget${E}" && hasi '(--method[[:space:]=]*(POST|PUT|DELETE|PATCH)|--post-data|--post-file)'; then
    http_write=1
  fi
  if hasi "${S}(http|https|xh)[[:space:]]+(-[^[:space:]]+[[:space:]]+)*(POST|PUT|DELETE|PATCH)[[:space:]]"; then
    http_write=1
  fi

  if [ "$http_write" = "1" ]; then
    nonlocal=0
    hosts="$(printf '%s' "$cmd" | grep -oE 'https?://[^/[:space:]"'"'"'?#]+' | sed -E 's#^https?://##; s#^[^@]*@##; s#:[0-9]+$##')"
    if [ -n "$hosts" ]; then
      while IFS= read -r h; do
        case "$h" in
          localhost|127.0.0.1|0.0.0.0|'[::1]'|*.localhost) ;;
          *) nonlocal=1 ;;
        esac
      done <<HOSTS
$hosts
HOSTS
    else
      # No scheme URL found (e.g. httpie `http POST :3000/x`): local only if a
      # local marker is present, otherwise assume it goes out.
      if ! has '(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0|[[:space:]]:[0-9]+)'; then
        nonlocal=1
      fi
    fi
    [ "$nonlocal" = "1" ] && label="HTTP POST/PUT/PATCH/DELETE to a non-localhost host (changes a real external system)"
  fi
fi

[ -z "$label" ] && exit 0

# ---------- 4. Block ----------
{
  echo "BRAKE: blocked — $label."
  echo "Command: $cmd"
  echo "This is irreversible (see docs/BRAKES.md). Do NOT retry, rephrase, or work around it."
  echo "Stop and ask the user for an explicit yes for EXACTLY this command: say what it does, what it touches, and what cannot be undone."
  echo "A yes covers only this exact command, this once. After a plain yes, re-run it prefixed with:  BRAKE_APPROVED=1 "
  echo "If the user is tired or it is late, propose doing it in the morning instead."
} >&2
exit 2
