# {{PROJECT_NAME}} — project instructions

<!-- placeholder: one paragraph — what this project is, who it's for, what "done" looks like. -->

Loaded every session. Detail lives in `docs/`; this file is the short version.

## 0. Start of every session
The SessionStart hook prints the MISTAKES.md patterns, the last 3 decisions, and the "Next" of `handoff.md` (plus a state snapshot after `/compact`). Then:
1. Read the **patterns** in `MISTAKES.md` (headings `## P1…`) before touching anything. Patterns prevent more mistakes than any single fix.
2. Treat the decisions shown as settled; open `record/DECISIONS.md` only for the detail of one you need.
3. If a `handoff.md` exists, read it in full and start from its "Next".

## 1. Hard rules (non-negotiable)
Each rule: RULE / WHY / HOW IT'S ENFORCED. A rule enforced by a test must have had that test deliberately broken once (`tests/BREAK-IT-ONCE.md`) — a test that can't fail is decoration.

| # | Rule | Why | Enforced by |
|---|------|-----|-------------|
| H1 | Never take an irreversible action (spend, delete, email/message a real person, push/deploy live) without an explicit yes for that exact action. | One wrong send/delete can't be undone; a pause costs minutes. | Hook `scripts/brake-check.sh` (blocks risky Bash) + `tests/test_brake_check.sh` + `tests/test_hooks_installed.sh`; manual for non-Bash actions. |
| H2 | `record/*.md` and `MISTAKES.md` are append-only. Never edit or delete an entry; a correction or reversal is a NEW entry that references the old one. | The record must answer "why is it like that?" months later; edited history can't. | Hook `scripts/record-guard.sh` (blocks rewrites at edit time) + `tests/test_record_guard.sh` + `tests/test_append_only.sh` (fails on any removed/changed line vs git HEAD). |
| H3 | No secrets in the repo (API keys, tokens, private keys, passwords). Use `.env` (git-ignored). | Committed secrets leak via sync, backups and history. | `tests/test_no_secrets.sh`. |
| H4 | Never report a task "done" on the strength of the mechanism (exit 0, green tick, "loaded"). Report the output check you performed. | A green tick means it ran, not that it worked. | Manual — `/verify`; reviewer checks it (`docs/REVIEW.md`). Backstop: Stop hook `scripts/stop-check.sh` re-runs tests when files changed and won't let a reply end on red. |
| H5 | Facts (prices, specs, part numbers, addresses, limits) come from a primary source and get logged in `record/FACTS.md` with source + date checked. | Tool summaries and memory drift; the maker's own doc doesn't. | Manual — `/fact`; reviewer checks values against sources. |
<!-- placeholder: project-specific hard rules. Same three columns. Add a test where possible, then break it once. -->

Run all tests: `bash tests/run.sh` (foreground). Run before declaring any change done. Path-scoped rules in `.claude/rules/` load automatically when you touch record, test or script files.

## 2. Check the output, not the mechanism
"It ran" is not "it worked". Prove every result by looking at the result itself:
- Scheduled job → the file/row/email it produces exists, with today's timestamp and plausible content — not "launchctl shows loaded".
- Email/message → it is in the recipient's inbox (or the provider's delivery log for that message ID) — not "send returned 200".
- File write/backup → open the file (or `tar -tzf` the archive) and count/inspect the contents — not "no errors".
- Deploy → load the live URL and see the new change — not "pipeline green".
- Data import/migration → row counts and 2–3 spot-checked values match the source — not "migration applied".
- Tests → the test has been seen to FAIL when the thing it guards is broken — not "all passed".
- Number in a doc → matches the primary source, re-read today — not "matches what we wrote last time".
Full table: `docs/VERIFICATION.md`. Use `/verify` after every task. When reporting, say what you checked and what you saw.

## 3. Show before you build
For anything **big**, produce a cheap sketch first (`/sketch`) and STOP for the user's reaction. "Big" means any of:
- more than ~1 hour of work, or more than ~3 files / ~200 lines changed;
- anything user-visible (UI, wording customers see, emails, documents sent out);
- new dependency, service, subscription, or anything that costs money;
- architecture/data-model changes, or anything hard to undo.
The sketch = what you'll get (mock-up, diagram, or example output), what it costs (time, money, complexity), what you're NOT doing, open questions. No building until the user reacts.

## 4. Brakes (irreversible actions)
Needs an explicit yes **every time**: spending money; deleting data/files/branches; emailing or messaging any real person or company; pushing, deploying, publishing or merging to anything live/shared; changing real infrastructure, DNS, billing, or permissions.
- A plain "yes" approves **exactly what was proposed** — that command, that recipient, that amount, once. Not similar actions, not a retry with changes, not "the rest of them".
- When the hook blocks a command: ask, wait for a yes, then re-run the identical command prefixed with `BRAKE_APPROVED=1 `.
- Before contacting a NEW company/person: run the pre-check in `docs/BRAKES.md` (address verified on their own website; draft scanned for commitments and prices).
- If the user says they're tired, or it's late: irreversible actions wait until morning. Prepare them; don't do them.
Full list: `docs/BRAKES.md`.

## 5. The record (append-only)
Write it as you go, not at the end:
- Decision made (incl. what was rejected) → `/decision` → `record/DECISIONS.md`
- Fact established → `/fact` → `record/FACTS.md`
- Lesson learned / someone told something → `/lesson` → `record/LESSONS.md`
- Something went wrong → `/mistake` → `MISTAKES.md` (classify by pattern first)
Append at the end of the file. Never edit an existing entry, including its status — supersede it with a new entry.

## 6. Independent review
For anything that matters (before shipping, before ordering parts, before sending), run a second, independent session per `docs/REVIEW.md`. Give it the PRIMARY sources (datasheets, official docs, the live system) — never this session's summary. `/review` writes the brief.

## 7. Continuity
`scripts/backup-memory.sh` backs up this file, `record/`, `MISTAKES.md`, `docs/`, `.claude/` to two places (destination 1: `~/claude-backups/<project>/` — every project gets its own subfolder there, never a new top-level backup folder); `scripts/install-backup-schedule.sh` runs it at 08:00 and 20:00 (macOS). Cross-session notes: `/handoff` writes `handoff.md` (format: `templates/handoff.md`); hooks also save a mechanical snapshot before every compact and at session end. At the end of a working session run `/learn` to turn corrections into record entries and promote repeat patterns into rules + tests.

## 8. Context hygiene
Context is finite; a bloated one gets slow, costly and sloppy. Full guide: `docs/CONTEXT.md`.
- `grep -n` first, then read the line range you need — not whole files. Big logs/dumps/broad searches → a subagent, take back the conclusion.
- When the context-nudge hook fires: finish the current change, `/handoff`, log decisions/lessons, then suggest `/compact` to the user. Never compact mid-change; never rely on the conversation surviving — files do.
- Keep this file short: detail goes in `docs/` or `.claude/rules/` (path-scoped).

## 9. Working method
Manual rules — enforced by the "Queue" section of `handoff.md` and the reviewer checklist (`docs/REVIEW.md`).
- **Work as a queue.** Every request is a queue item. New requests, tweaks and corrections that arrive mid-work are APPENDED to the end — they don't pre-empt the item in progress (unless the owner says "stop", "drop that" or "do this first"). A brake (§4) or a sketch (§3) PAUSES only that item: mark it, keep working the rest, return when the owner answers. Done = verified by output (§2), not attempted. Stop only when every item is `[x]` done or `[~] PAUSED` awaiting the owner. Keep the queue in `handoff.md` (`[ ]` todo, `[x]` done, `[~] PAUSED: <what's needed>`). WHY: jumping to each correction leaves half-finished work behind and loses items; a paused item shouldn't idle the whole run.
- **One pass.** Before changing anything, list every file you'll need and read them together (`grep -n` + line ranges for big ones, §8). Then make all the edits, then run `bash tests/run.sh` ONCE. If it fails, fix and run once more — not a re-read/re-test after every edit. WHY: per-edit re-reading and re-running burns context and time.

## Project specifics
<!-- placeholder: stack, how to run/build, key commands, where primary sources live (datasheet folder, official doc URLs, live system URL). -->
<!-- placeholder: people and roles (who decides what) — no personal contact details here. -->
