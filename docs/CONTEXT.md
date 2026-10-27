# Context hygiene — keeping sessions sharp and cheap

Claude's working memory (the context window) is finite. As it fills, answers get slower, costlier and sloppier, and eventually Claude Code compacts it automatically — at an arbitrary moment, often mid-change. These habits, and the hooks that back them, keep that from biting. (Several ideas adapted from ECC's strategic-compact and memory-persistence work — see README attribution.)

## What loads every session (keep it small)
| Always loaded | Loaded only when needed |
|---|---|
| `CLAUDE.md` (keep under ~150 lines) | `.claude/rules/*.md` with `paths:` — only when matching files are touched |
| SessionStart hook output (capped at 3000 chars) | `docs/*.md` — read on demand |
| Every enabled MCP server's tool list | Slash commands — only when invoked |

Detail belongs in `docs/` or a path-scoped rule, not in `CLAUDE.md`. Disable MCP servers a project doesn't use — each one's tool list costs context every turn. Check live usage with `/context`.

## Reading without flooding
- **Search, then read the part you need**: `grep -n` to find the line, then read that range — not the whole file.
- **Big logs, data dumps, screenshots, long command output**: `tail`/`head`/`grep` them, or hand the job to a subagent and take back only its conclusion.
- **Broad searches across many files**: delegate to a subagent (it reads; you get the answer).
- **Don't re-read** a file you just wrote or edited to "check" it — the tool would have errored. Do run the output check (principle 4) on what the change *produces*.

## When to compact
The `context-nudge.sh` hook tells Claude when the session is getting large (60 tool calls, or ~140k tokens of context). It never compacts by itself; the user runs `/compact`.

| Moment | Compact? | Why |
|---|---|---|
| Research done → about to plan | Yes | The plan is the distilled output; the research bulk isn't needed |
| Plan written to a file → about to build | Yes | Free room for the build |
| Mid-change (files half-edited) | **No** | You'd lose the file paths, names and partial state |
| Bug fixed → next feature | Yes | Debug traces pollute unrelated work |
| A failed approach abandoned | Yes | Clear the dead-end reasoning |

**Always write before compacting.** Run `/handoff` (writes `handoff.md`) and log any decisions/lessons first. Files survive compaction; the conversation does not. `/compact <focus>` lets you tell it what to keep.

## What the hooks do automatically
1. **PreCompact / SessionEnd** → `save-state.sh` writes `.claude/state/last-session.md`: last few user requests, git branch + uncommitted files, newest record IDs, handoff age. Mechanical, not a summary.
2. **SessionStart** → `session-start.sh` prints the MISTAKES patterns, the last 3 decisions, the "Next" of `handoff.md`, and — after a compact or resume — that snapshot. So the new context starts oriented without spending tool calls.
3. **PostToolUse** → `context-nudge.sh` suggests a boundary + `/handoff` + `/compact` when the session is large.
4. **Stop** → `stop-check.sh` re-runs the tests if files changed since the last green run, so a long session can't drift into "done" on red tests.

## Settings
| Variable | Default | Effect |
|---|---|---|
| `HOOKS_OFF` | (empty) | Comma list of hooks to switch off: `record-guard`, `session-context`, `save-state`, `context-nudge`, `stop-check`, or `all` (brake-check has its own approval path and is not affected) |
| `SESSION_START_MAX_CHARS` | 3000 | Cap on the extra SessionStart context |
| `CONTEXT_NUDGE_CALLS` | 60 | Tool calls before the first nudge (then every 30) |
| `CONTEXT_NUDGE_TOKENS` | 140000 (700000 on 1M-window sessions) | Context size before the first size nudge (then every +50k); `0` disables |
| `STOP_CHECK_CMD` | `bash tests/run.sh` | What the Stop hook runs |

Set them in your shell before starting `claude`, or in `.claude/settings.local.json` under `"env"` (git-ignored, per-user).
