#!/usr/bin/env bash
# context-nudge.sh — Claude Code PostToolUse hook (all tools).
#
# Strategic compaction, adapted from ECC's suggest-compact hook. Auto-compact
# fires at an arbitrary moment, often mid-change; compacting at a logical
# boundary, after writing state to a file, loses much less. This hook counts
# tool calls per session and (with jq) reads the real context size from the
# transcript's latest usage record, and tells Claude when it's time to look
# for a boundary. It never blocks and never compacts by itself.
#
#   Tool calls: first nudge at CONTEXT_NUDGE_CALLS (default 60), then every 30.
#   Context:    first nudge at CONTEXT_NUDGE_TOKENS (default 140000; 700000 once
#               the session has been seen above 200k, i.e. a 1M window), then
#               every further 50000 tokens.
# Output: JSON hookSpecificOutput.additionalContext on stdout (exit 0).
# Off switch: HOOKS_OFF=context-nudge.
set -u
. "$(dirname "$0")/hook-lib.sh"
hook_disabled context-nudge && exit 0
hook_read
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
key="$(session_key)"
cfile="$STATE_DIR/calls-$key"
bfile="$STATE_DIR/ctx-$key"

# Sweep counters from old sessions (our own scratch files only).
find "$STATE_DIR" -maxdepth 1 -type f \( -name 'calls-*' -o -name 'ctx-*' \) -mtime +7 -exec rm -f {} + 2>/dev/null

n="$(cat "$cfile" 2>/dev/null)"; case "$n" in ''|*[!0-9]*) n=0;; esac
n=$((n + 1)); echo "$n" > "$cfile"

first="${CONTEXT_NUDGE_CALLS:-60}"; case "$first" in ''|*[!0-9]*|0) first=60;; esac
msg=""
if [ "$n" -eq "$first" ] || { [ "$n" -gt "$first" ] && [ $(( (n - first) % 30 )) -eq 0 ]; }; then
  msg="$n tool calls this session."
fi

# Context-size signal (jq only; checked every 5th call to stay cheap).
tp="$(json_get '.transcript_path' 'transcript_path')"
if [ $((n % 5)) -eq 0 ] && [ -n "$tp" ] && [ -f "$tp" ] && have_jq; then
  tok="$(tail -n 60 "$tp" | jq -rR 'fromjson? | .message.usage? // empty
          | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' 2>/dev/null | tail -1)"
  case "$tok" in ''|*[!0-9]*) tok=0;; esac
  prev="$(cat "$bfile" 2>/dev/null)"; prev_bucket="${prev%% *}"; big="${prev##* }"
  case "$prev_bucket" in ''|*[!0-9-]*) prev_bucket=-1;; esac
  [ "$tok" -gt 200000 ] && big=1
  [ "$big" = "1" ] || big=0
  if [ "$big" = "1" ]; then def=700000; else def=140000; fi
  thr="${CONTEXT_NUDGE_TOKENS:-$def}"; case "$thr" in ''|*[!0-9]*) thr=$def;; esac
  bucket=-1
  [ "$thr" -gt 0 ] && [ "$tok" -ge "$thr" ] && bucket=$(( (tok - thr) / 50000 ))
  if [ "$bucket" -gt "$prev_bucket" ]; then
    msg="${msg:+$msg }Context is ~$((tok / 1000))k tokens."
    prev_bucket=$bucket
  fi
  echo "$prev_bucket $big" > "$bfile"
fi

[ -z "$msg" ] && exit 0
text="CONTEXT NUDGE: $msg At the next logical boundary (not mid-change): write where you are to handoff.md (/handoff), log any decisions/lessons, then tell the user it's a good moment to run /compact. Until then prefer grep and line ranges over whole-file reads, and hand big searches to a subagent. See docs/CONTEXT.md."
printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$text"
exit 0
