# Decisions — {{PROJECT_NAME}}

Append-only log of every decision **and what was turned down**. It exists to answer "why is it like that?" six weeks from now.

## Rules
1. **Never edit or delete an entry** — not the wording, not the status. `tests/test_append_only.sh` fails if any committed line changes.
2. **A reversal is a new entry.** Give it a new ID, set `Supersedes: D-xxx`, and explain what changed. The old entry stays as it was.
3. Always record the alternatives rejected and why — the rejected options are what people ask about later.
4. Newest at the bottom. IDs are sequential: D-001, D-002, …
5. Add with `/decision`. Use today's date (YYYY-MM-DD).

## Entry template
```
### D-NNN — <one-line decision>
- Date: YYYY-MM-DD
- Decision: <what we will do, specifically>
- Why: <the reason, and the facts it rests on (link F-xxx in FACTS.md)>
- Alternatives rejected:
  - <option> — <why not>
  - <option> — <why not>
- Decided by: <person/role>  (proposed by: <person/AI>)
- Status: active | superseded by D-xxx (status written once, at creation)
- Supersedes: <D-xxx or none>
```

## Worked example (illustrative — shows the format)
### D-000 — Store order data in a single SQLite file, not a hosted database
- Date: 2026-01-15
- Decision: Use one SQLite file in `data/orders.db`, backed up with the memory backups.
- Why: Under 1,000 orders/year; one user writes at a time; no hosting bill (see F-000 for the volume estimate).
- Alternatives rejected:
  - Hosted Postgres — monthly cost and an account to manage, for load we don't have.
  - Spreadsheet — no validation; two copies of the same customer drifted apart in the old process (MISTAKES P2).
- Decided by: owner  (proposed by: AI)
- Status: active
- Supersedes: none

## Entries
<!-- Append new decisions below this line. -->

### D-001 — Adopt five efficiency ideas from ECC (re-implemented in bash); reject its runtime-heavy machinery
- Date: 2026-10-27
- Decision: After reviewing github.com/affaan-m/ECC (MIT; read only, nothing executed), adopt, in bash + optional jq: (1) PreCompact/SessionEnd state snapshot (`scripts/save-state.sh`) re-injected by a bounded SessionStart briefing (`scripts/session-start.sh`: patterns + last 3 decisions + handoff "Next", 3000-char cap); (2) strategic-compact nudge on tool-call count and real context tokens (`scripts/context-nudge.sh`, PostToolUse); (3) a stop-time gate that re-runs the tests when files changed and blocks once on red (`scripts/stop-check.sh`); (4) an edit-time guard for the append-only record, modelled on ECC's config-protection (`scripts/record-guard.sh`); (5) path-scoped `.claude/rules/` (record, tests-and-hooks). Also: `/handoff` and `/learn` commands (our take on ECC's session summaries and "instincts", feeding LESSONS/MISTAKES instead of a parallel store), `docs/CONTEXT.md`, a `HOOKS_OFF` kill switch, and a small read-only permission allowlist (our idea, not ECC's).
- Why: Compaction and session ends were losing working state; the start-of-session reading cost tool calls every time; H2 was only caught after the fact; H4 had no mechanical backstop. Each change is enforced by a test (`test_record_guard.sh`, `test_lifecycle_hooks.sh`, extended `test_hooks_installed.sh`) that was broken once while building.
- Alternatives rejected:
  - Import ECC's Node hook runtime / installer / dashboard — violates the bash-only, no-runtime constraint.
  - LLM-written summaries inside the PreCompact hook — needs a runtime/API call from a hook; Claude writes the judgement part itself via `/handoff`.
  - Instinct observer (log every tool call, background model scoring confidence, evolve/promote CLI) — heavy and opaque, duplicates LESSONS/MISTAKES; `/learn` with human-approved promotion fits the record.
  - Hundreds of skills/agents/commands and per-language rule packs — context and maintenance cost only pays off at scale.
  - Per-edit formatters/typecheckers, GateGuard fact-forcing on every first edit, prompt routing, cost tracker, desktop notifications, tmux/dev-server blockers — stack-specific or friction without matching benefit here.
- Decided by: owner asked for the ECC upgrade; the adopt/reject list was chosen by AI — owner to confirm  (proposed by: AI)
- Status: active
- Supersedes: none

### D-002 — Adopt the queue rule and the one-pass rule (CLAUDE.md §9)
- Date: 2026-10-27
- Decision: (1) Work as a queue: every request is a queue item; new requests, tweaks and corrections are appended, not allowed to pre-empt the item in progress (unless the owner says stop / drop that / do this first); a brake or sketch pauses only that item while the rest of the queue continues; done = output-verified; stop only when every item is done or paused awaiting the owner; the queue lives in `handoff.md` "Queue" (`[ ]` / `[x]` / `[~] PAUSED:`). (2) One pass: list every file needed, read them together, make all edits, run `bash tests/run.sh` once (fix and re-run once if red). Manual rules — enforced by the handoff Queue section and a Queue item in the `docs/REVIEW.md` checklist.
- Why: Owner's words — "Treat all work as a queue of todo… do not break the queue to suddenly prioritize my correction. Only stop when 100% of your queue is truly clear." and "list every file you'll need and read them in one pass. Then make all edits, then run the tests once." Jumping to each correction left work half-done; per-edit re-reading and re-testing burns context and time (§8).
- Alternatives rejected:
  - Cheap-model fresh-eyes reviewer subagent on every change — dropped, redundant with §6 independent review.
- Decided by: owner  (proposed by: owner)
- Status: active
- Supersedes: none

### D-003 — Add the process to existing projects with an opt-in global /adopt-process command; strip template entries from new projects
- Date: 2026-10-27
- Decision: (1) `scripts/adopt-into.sh <dir> [--dry-run]` adds the process to an existing git repo — additive only (never overwrites; differing same-named files are CONFLICTs left alone), idempotent, plan printed first; `.claude/settings.json` merged with jq (hooks appended unless the same command is registered, `permissions.allow` unioned, original kept as `.pre-adopt`); CLAUDE.md gets a condensed block between BEGIN/END markers when it already exists; record files start with format only plus one "Adopted" decision. If the project already has its own `tests/run.sh` (or `tests/test_*.sh`), the process tests go to `tests/process/` with their own runner; `stop-check.sh` prefers `tests/process/run.sh`, and copied docs/commands/rules are re-pointed at it. Refuses `/`, `$HOME`, `~/Downloads`, the template, and non-git folders. (2) A global slash command `~/.claude/commands/adopt-process.md` runs the dry run, shows the plan, waits for an explicit yes, applies, runs the process tests, shows `git status`, never commits unless asked. (3) `new-project.sh` no longer gives new projects the template's own D-001/D-002 (it strips record entries via the shared `scripts/template-lib.sh`, empties MISTAKES instances, and adds a "Created from the Claude Process Template" entry); it also no longer copies template-only files (`new-project.sh`, `adopt-into.sh`, `template-lib.sh`, `tests/test_adopt.sh`). Worked examples D-000/F-000/L-000 are kept: they sit above "## Entries", never appear in the briefing, and BREAK-IT-ONCE uses D-000. Enforced by `tests/test_adopt.sh` (broken once).
- Why: The owner wants the process in existing projects without restarting them, and without risking their files or settings. New projects inheriting the template's own decisions made their record start with someone else's history.
- Alternatives rejected:
  - SessionStart hook that auto-scaffolds the process in every folder Claude Code opens — litters non-project folders (home, Downloads, scratch dirs) and changes repos without a yes.
  - Overwrite/replace files in the target (e.g. a fresh settings.json) — loses the project's own hooks, permissions and docs.
  - Put the process tests in the project's own `tests/` next to its runner — the template's runner would run (or clash with) the project's tests and vice versa.
- Decided by: owner  (proposed by: owner; layout details by AI)
- Status: active
- Supersedes: none

### D-004 — Publish the template publicly as `claude-efficiency`, with a global kit, generic backup location and MIT license
- Date: 2026-10-27
- Decision: (1) Publish this repo publicly on GitHub as `claude-efficiency` so friends can install it on their own machines; remove every machine-specific path and personal reference (`tests/test_adopt.sh` now uses a self-contained realistic settings fixture instead of reading real project settings). (2) Backup destination 1 default moves to `~/claude-backups/<project>/`; rule: every project's backups go in their own subfolder there, never a new top-level backup folder (`backup-memory.sh`, `backup.conf`, `install-backup-schedule.sh`, README, CLAUDE.md §7, global rules). (3) Add a `global/` kit — the global brake hook variant (defers to a project's own brake, honours a user-written `.claude/brake-allow`), the "Working rules (all projects)" section plus a Backups rule, and the `/adopt-process` command with `{{TEMPLATE_DIR}}` — installed by `global/install.sh` (preview by default, `--apply` to install; additive, idempotent, timestamped `.pre-claude-efficiency-<ts>` backups, CONFLICTs reported not overwritten). Enforced by `tests/test_global_install.sh` (fake `CLAUDE_HOME`, never the real one; also fails if the two brake copies' pattern sections drift), broken once. `global/`, the test and `LICENSE` are template-only (not copied into projects). (4) MIT license (copyright line names the owner's public GitHub handle, in `LICENSE` only). `install-backup-schedule.sh` explains the macOS-only launchd limit and prints a crontab line elsewhere.
- Why: Friends should get the same process without the owner's paths, folders or private config; the global pieces were hand-installed on one machine and could not be reproduced. A preview-by-default installer means nobody's `~/.claude` changes without a deliberate second command.
- Alternatives rejected:
  - Keep a backup default under a personal folder name — meaningless on anyone else's machine.
  - An uninstall script — four small, documented manual steps ("Removing it" in README) are safer than a script that edits `settings.json` and `CLAUDE.md` again.
  - Installer that applies by default — changes a user's global Claude config on first run without them seeing the plan.
  - One shared brake script for both uses — the global copy needs the defer/brake-allow extras that projects don't; a drift test keeps the shared pattern section identical instead.
- Decided by: owner  (proposed by: owner; installer details by AI)
- Status: active
- Supersedes: none
