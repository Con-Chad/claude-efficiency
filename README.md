# Claude Process Template (claude-efficiency)

A starting kit for building real products with Claude Code when you are not a developer. It turns nine working habits — hard rules with tests, a permanent record of decisions, a mistakes register, "check the output, not the mechanism", a second AI as reviewer, show-before-build, brakes on irreversible actions, backups of the AI's memory, and working as a queue — into files, hooks, scripts and tests, so the process holds up even when you're tired or the AI is confident and wrong. Everything is plain bash; nothing runs in the background except the hooks Claude Code calls.

It is based on a process described in a Reddit post by a non-developer founder who builds real products with Claude Code, with efficiency ideas adapted from [ECC](https://github.com/affaan-m/ECC) (see Credits).

## Quick start

**Requirements:** macOS or Linux, bash, git, [jq](https://jqlang.github.io/jq/) (`brew install jq`, or `sudo apt install jq`), and [Claude Code](https://docs.claude.com/en/docs/claude-code). The twice-daily backup schedule uses launchd and is macOS-only (on Linux the installer prints a crontab line instead).

**(a) Start a new project.** Click **Use this template** on GitHub (or `git clone` this repo), then from the clone:

```bash
bash scripts/new-project.sh ~/projects/my-thing
cd ~/projects/my-thing
git init && git add -A && git commit -m "Start from Claude process template"
bash tests/run.sh          # all pass
claude                     # then run /hooks once to see the six hooks listed
```

**(b) Add it to an existing project.** Install the global kit (path c), restart Claude Code, open it inside your project (a git repo) and run **`/adopt-process`**. It shows a dry-run plan, waits for your yes, then applies it additively — nothing of yours is overwritten. Details: "Adding this to an existing project" below.

**(c) Global kit only** — the brake hook for every project, short working rules in your global `CLAUDE.md`, and the `/adopt-process` command:

```bash
bash global/install.sh            # preview: prints the plan, changes nothing
bash global/install.sh --apply    # install
```

Then restart Claude Code, run `/hooks` (the brake should be listed under PreToolUse → Bash), and test it: `mkdir -p /tmp/brake-test`, then ask Claude to run `rm -rf /tmp/brake-test` — it should be blocked and Claude should ask you first.

**Backups rule:** every project's backups go in their own subfolder of `~/claude-backups/` (`~/claude-backups/<project-name>/`) — never a new top-level backup folder. The backup script defaults to this; the global rules tell Claude the same.

## The 9 principles

| # | Principle | Where it lives |
|---|-----------|----------------|
| 1 | **Hard rules, with reasons.** A short list of non-negotiables, each with WHY. The important ones have a test, and each test has been broken once on purpose to prove it can fail. | `CLAUDE.md` §1, `tests/`, `tests/BREAK-IT-ONCE.md` |
| 2 | **A permanent, searchable record, separate from chat.** Decisions (and what was turned down), facts (with source and date checked), lessons (and who was told). Never edited; a reversal is a new entry. | `record/`, `/decision` `/fact` `/lesson`, `tests/test_append_only.sh`, `scripts/record-guard.sh` |
| 3 | **A mistakes register, grouped by pattern.** Which *kind* of wrong, not just what went wrong. Read the patterns at the start of every session. | `MISTAKES.md`, `/mistake`, SessionStart hook |
| 4 | **Check the output, not the mechanism.** A green tick means it ran, not that it worked. | `docs/VERIFICATION.md`, `/verify`, `CLAUDE.md` §2, Stop hook `scripts/stop-check.sh` |
| 5 | **A second AI checks the first** against the original sources, not against the first AI's summary. | `docs/REVIEW.md`, `/review` |
| 6 | **Show me before you build.** Cheap sketch first, then build. | `CLAUDE.md` §3, `/sketch` |
| 7 | **Brakes.** Irreversible actions need an explicit yes, every time. "Yes" covers exactly what was proposed. New contacts get a pre-check. Tired means wait until morning. | `docs/BRAKES.md`, `.claude/settings.json` + `scripts/brake-check.sh` |
| 8 | **Backups of the AI's memory.** Twice a day, two places. Plus automatic state snapshots before every compact and at session end, and a bounded briefing at session start. | `scripts/backup-memory.sh`, `scripts/install-backup-schedule.sh`, `scripts/save-state.sh`, `scripts/session-start.sh`, `/handoff` |
| 9 | **Work as a queue, in one pass.** Requests and corrections join the end of the queue instead of jumping it; a paused item doesn't stop the run; stop only when the queue is clear. Read every file you need in one pass, edit, test once. | `CLAUDE.md` §9, `handoff.md` Queue, `/handoff` |

## Start a new project

```bash
cd /path/to/your/clone/of/this/repo
bash scripts/new-project.sh ~/projects/my-thing        # optional 2nd arg: display name
cd ~/projects/my-thing
grep -rn "placeholder" CLAUDE.md docs/ record/   # fill these in
git init && git add -A && git commit -m "Start from Claude process template"
bash tests/run.sh                                # all pass (append-only needs the commit)
# then: break each test once (tests/BREAK-IT-ONCE.md), set backup destination 2
# in scripts/backup.conf, run one backup and look at it, install the schedule.
```

`new-project.sh` copies everything except git history, backups, OS junk and sync-tool folders (synced folders such as Syncthing/Dropbox), and the template-only files (`new-project.sh`, `adopt-into.sh`, `template-lib.sh`, `tests/test_adopt.sh`, `tests/test_global_install.sh`, `global/`, `LICENSE`), strips the template's own record entries (the new `DECISIONS.md` starts with one "Created from the Claude Process Template" entry), replaces `{{PROJECT_NAME}}` / `{{CREATED_DATE}}`, and prints the next steps. It refuses to write into a non-empty directory.

**Placeholder convention:** project-specific sections are marked `<!-- placeholder: what goes here -->`. Search for `placeholder` to find them all. `{{PROJECT_NAME}}` is replaced automatically.

## Adding this to an existing project

In any git repo, open Claude Code and run **`/adopt-process`** (a global command installed by `bash global/install.sh --apply` into `~/.claude/commands/adopt-process.md`, pointing at wherever you cloned this repo). It shows the plan from a dry run, waits for your yes, applies it, runs the process tests and shows `git status`. It does not commit. By hand:

```bash
bash /path/to/your/clone/scripts/adopt-into.sh "$PWD" --dry-run   # read the plan
bash /path/to/your/clone/scripts/adopt-into.sh "$PWD"             # apply it
```

- **Additive only.** Missing files are created; an existing file is never overwritten. A same-named file that differs (e.g. your own `docs/REVIEW.md`) is kept and listed as a **CONFLICT** with a suggestion.
- `CLAUDE.md`: created if absent; otherwise a condensed process block is appended between `<!-- BEGIN/END claude-process-template -->` markers.
- `.claude/settings.json`: merged with `jq` — template hooks added unless the same command is already registered, `permissions.allow` unioned, everything else untouched; the original is saved as `.claude/settings.json.pre-adopt`. `.gitignore`: missing lines appended.
- `record/*.md`: created with the format only (no template entries) plus one "Adopted the Claude Process Template" decision; existing record files are left alone.
- **Your own tests:** if the project already has `tests/run.sh` (or `tests/test_*.sh`), the process tests go in `tests/process/` with their own runner `bash tests/process/run.sh`; your runner is untouched, the copied docs/commands point at the process runner, and the Stop hook runs it (set `STOP_CHECK_CMD` to also run your suite).
- Refuses `/`, your home folder, `~/Downloads`, and any folder that isn't the top of a git repo. Needs `jq`. Running it twice changes nothing.

## How a session runs
1. Claude Code starts → SessionStart hook briefs Claude: the MISTAKES.md patterns, the last 3 decisions, and the "Next" of `handoff.md` (capped at 3000 chars).
2. Big request → `/sketch` → you react → Claude builds.
3. As decisions/facts/lessons/mistakes happen → `/decision`, `/fact`, `/lesson`, `/mistake` append to the record. Trying to rewrite a record entry instead is blocked by `record-guard.sh`.
4. Task finished → `/verify` performs the output check. If files changed and the tests are red, the Stop hook won't let the reply end quietly.
5. Something irreversible → the hook blocks it → Claude asks → you say yes → Claude re-runs with `BRAKE_APPROVED=1`.
6. Long session → the context-nudge hook suggests a boundary → `/handoff` → you run `/compact`. A snapshot is saved before compaction and handed back afterwards.
7. Before shipping/ordering/sending → `/review` → paste the brief into a fresh session with the primary sources.
8. End of session → `/learn` (corrections → record; repeat patterns → rules + tests) and `/handoff` if work continues later.

## File map

| Path | Purpose |
|------|---------|
| `README.md` | This file. |
| `CLAUDE.md` | Project instructions Claude Code loads every session: hard rules (RULE/WHY/ENFORCED BY), output-check rule, show-before-build, brakes, record rules, review pointer, working method (queue, one pass). Kept short. |
| `MISTAKES.md` | Mistakes register grouped by pattern, pre-seeded with P1 (ran ≠ worked), P2 (one copy changed), P3 (summary over source). Append-only. |
| `record/DECISIONS.md` | Append-only decision log: decision, alternatives rejected and why, who decided, status. |
| `record/FACTS.md` | Append-only fact log: value, primary source, date checked, verified by, where copies live. |
| `record/LESSONS.md` | Append-only lessons: trigger, lesson, who was told and when. |
| `docs/VERIFICATION.md` | Playbook: for each common task, the misleading mechanism check vs the real output check. |
| `docs/REVIEW.md` | Independent-review protocol: how to run the second session, what to give it, checklist, report format. |
| `docs/BRAKES.md` | Full list of irreversible actions, approval semantics, new-contact pre-check, the tired rule, what the hook does and doesn't cover. |
| `docs/CONTEXT.md` | Context hygiene: what loads every session, reading without flooding, when to compact, what the lifecycle hooks do, hook settings and off switches (`HOOKS_OFF`). |
| `.claude/settings.json` | Hooks: PreToolUse(Bash) → `brake-check.sh`; PreToolUse(Edit\|Write\|MultiEdit) → `record-guard.sh`; SessionStart → `session-start.sh`; PostToolUse → `context-nudge.sh`; PreCompact + SessionEnd → `save-state.sh`; Stop → `stop-check.sh`. Plus a small permission allowlist for read-only commands (tests, `git status/diff/log/show`, `ls`, `wc`, `bash -n`) — hooks still run on them. |
| `.claude/rules/record.md` | Path-scoped rule (loads only when `record/` or `MISTAKES.md` is touched): how to append, IDs, dates. |
| `.claude/rules/tests-and-hooks.md` | Path-scoped rule (loads only when `tests/`, `scripts/` or settings are touched): the checklist for adding a hook or test. |
| `.claude/commands/*.md` | Slash commands: `/decision`, `/fact`, `/lesson`, `/mistake`, `/verify`, `/review`, `/sketch`, `/handoff` (writes `handoff.md`), `/learn` (end-of-session sweep + promotion of repeat patterns into rules/tests). |
| `scripts/brake-check.sh` | Hook script: blocks (exit 2) irreversible shell commands unless prefixed `BRAKE_APPROVED=1`. Uses `jq` if present, grep/sed otherwise. |
| `scripts/session-start.sh` | Hook script: prints the MISTAKES.md pattern reminder, then (capped) the last 3 decisions, handoff.md "Next", and after a compact/resume the saved snapshot. |
| `scripts/hook-lib.sh` | Shared helpers sourced by the newer hooks: JSON field reading (jq or grep/sed fallback), `HOOKS_OFF` switch, state dir. |
| `scripts/record-guard.sh` | Hook script: blocks (exit 2) Write over an existing record file and any Edit that changes existing record text; appends pass. |
| `scripts/save-state.sh` | Hook script (PreCompact, SessionEnd): writes `.claude/state/last-session.md` — last user requests, git state, newest record IDs. |
| `scripts/context-nudge.sh` | Hook script (PostToolUse): after 60 tool calls or ~140k context tokens, tells Claude to reach a boundary, `/handoff`, and suggest `/compact`. |
| `scripts/stop-check.sh` | Hook script (Stop): if files changed since the last green run, runs the tests; on failure blocks the stop once with the failures. |
| `scripts/backup-memory.sh` | Backs up continuity files (+ Claude's auto-memory for this project) to two destinations (default 1: `~/claude-backups/<project>/`) as timestamped tarballs, keeps the newest N, verifies each archive's contents. |
| `scripts/backup.conf` | Backup settings: destinations, retention, extra paths. |
| `scripts/install-backup-schedule.sh` | Installs a launchd job (08:00 and 20:00) for the backup — macOS only; on Linux it prints a crontab line and changes nothing; `--dry-run`, `--uninstall`. Prints how to check the archive actually landed. |
| `scripts/new-project.sh` | Creates a new project from this template. Template-only (not copied into projects). |
| `scripts/adopt-into.sh` | Adds the process to an existing git repo: additive, idempotent, `--dry-run`; merges `settings.json` with jq. Template-only. See "Adding this to an existing project". |
| `scripts/template-lib.sh` | Helpers shared by `new-project.sh` and `adopt-into.sh` (strip template record entries, placeholder substitution). Template-only. |
| `global/install.sh` | Installs the global kit into `~/.claude` (or `$CLAUDE_HOME`): preview by default, `--apply` to install. Additive, idempotent, backs up `settings.json`/`CLAUDE.md` as `*.pre-claude-efficiency-<timestamp>`, reports CONFLICTs instead of overwriting. Template-only. |
| `global/hooks/brake-check.sh` | Global variant of the brake: same patterns as `scripts/brake-check.sh` (a test keeps them identical), plus it defers to a project's own brake and honours a per-project `.claude/brake-allow` pre-approval file that only you write. |
| `global/CLAUDE-rules.md` | Short working rules (queue, one pass, output check, show-before-build, brakes, backups) appended to `~/.claude/CLAUDE.md` between `claude-efficiency` markers. |
| `global/commands/adopt-process.md` | The `/adopt-process` command: dry run → your yes → apply → run process tests → `git status`. `{{TEMPLATE_DIR}}` is filled in by the installer. |
| `tests/run.sh` | Runs every `tests/test_*.sh`; also works as `tests/process/run.sh` in adopted projects; pass/fail/skip counts; zero tests counts as failure. |
| `tests/test_append_only.sh` | Fails if any committed line in `record/*.md` or `MISTAKES.md` was changed or removed. Skips if not a git repo yet. |
| `tests/test_no_secrets.sh` | Fails on AWS keys, `sk-` keys, GitHub/Slack tokens, private key blocks, password assignments. |
| `tests/test_hooks_installed.sh` | Fails if any of the 6 hook scripts isn't registered on its event (with the right matcher) or isn't executable. |
| `tests/test_record_guard.sh` | Feeds rewrite and append payloads through `record-guard.sh` (jq and fallback): rewrites → exit 2, appends/placeholders/other files → exit 0. |
| `tests/test_lifecycle_hooks.sh` | In a throwaway copy: checks session-start's briefing and cap, save-state's snapshot, context-nudge's threshold + JSON, stop-check's block/pass/no-loop behaviour. |
| `tests/test_brake_check.sh` | Feeds ~60 sample commands through the hook (jq and fallback parsers): dangerous → exit 2, safe → exit 0, approval works. |
| `tests/test_adopt.sh` | In throwaway fixtures: adopt into an empty repo (process tests pass inside) and an existing project (only additive changes, settings merged without losing entries, own `tests/run.sh` kept), dry-run inert, second run a no-op, refusals. Template-only — skips where `adopt-into.sh` is absent. |
| `tests/test_global_install.sh` | Against a throwaway fake home: preview changes nothing, apply creates every piece, existing settings/CLAUDE.md are kept, second apply is a no-op, CONFLICT is respected, the installed brake blocks `git push`, and the two brake copies' pattern sections are identical. Template-only. |
| `tests/BREAK-IT-ONCE.md` | How to break each test on purpose, the expected failure, and the dated proven-to-fail checklist. |
| `templates/handoff.md` | Cross-session handoff note: the work queue, where we are, what's blocked, what's next. |
| `LICENSE` | MIT. Template-only (not copied into new projects). |
| `.gitignore` | macOS/sync-tool/editor junk, `backups/`, `.env*`, `.claude/state/` (hook scratch). |

## Requirements
macOS or Linux (the launchd backup scheduler is macOS-only), bash 3.2+, git, standard tools. `jq` is required by `adopt-into.sh` and `global/install.sh` (JSON merge); the hooks and tests fall back to grep/sed without it. No Node or Python.

## Removing it
- **From a project:** delete what the template added — the `scripts/` hook files, `tests/` (or `tests/process/`), `docs/`, `.claude/commands/`, `.claude/rules/`, `templates/`, and the `hooks` entries in `.claude/settings.json` that run `scripts/*.sh` (an adopted project kept its original as `.claude/settings.json.pre-adopt`). Remove the `<!-- BEGIN/END claude-process-template -->` block from `CLAUDE.md`. Keep `record/` and `MISTAKES.md` if you want the history. If you installed the backup schedule, run `bash scripts/install-backup-schedule.sh --uninstall` first.
- **The global kit:** there is no uninstaller; it is four things:
  1. `~/.claude/settings.json`: remove the `hooks.PreToolUse` entry with matcher `Bash` whose command is `~/.claude/hooks/brake-check.sh` (or restore the `settings.json.pre-claude-efficiency-<timestamp>` backup if you have changed nothing since).
  2. `~/.claude/hooks/brake-check.sh`: delete it.
  3. `~/.claude/CLAUDE.md`: delete everything from `<!-- BEGIN claude-efficiency rules -->` to `<!-- END claude-efficiency rules -->`, inclusive.
  4. `~/.claude/commands/adopt-process.md`: delete it.

  `~/claude-backups/` holds your backups — delete it only if you don't want them. Restart Claude Code and check that `/hooks` no longer lists the brake.

## Limits, honestly
- The brake hook is a seatbelt: it catches common shell forms of dangerous commands, not actions taken through browsers, MCP tools, or code that calls APIs internally. `docs/BRAKES.md` is the policy that covers everything.
- `record-guard.sh` sees Claude's Edit/Write tools only, not shell redirection (`>`, `sed -i`); the append-only test is the backstop. Its fallback without `jq` can't check MultiEdit and blocks it.
- `stop-check.sh` runs your whole test suite when files changed; if your project's tests get slow, set `STOP_CHECK_CMD` to a fast subset or `HOOKS_OFF=stop-check`.
- The append-only test only protects what has been committed. Commit often.
- Backups protect only if destination 2 is a different physical place. Point it at cloud/NAS/external storage in `scripts/backup.conf`.

## Credits
The process is based on one described in a Reddit post by a non-developer founder building real products with Claude Code. Several efficiency ideas — the PreCompact/SessionEnd state capture and bounded SessionStart loading, strategic-compact nudges, the stop-time test gate, path-scoped `.claude/rules/`, and a guard that blocks edits to protected files — were adapted (re-implemented in bash, no code copied) from [ECC](https://github.com/affaan-m/ECC) by Affaan Mustafa, MIT License. See `record/DECISIONS.md` D-001 for what was adopted and what was deliberately left out.

License: MIT — see `LICENSE`.
