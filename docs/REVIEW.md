# Independent review protocol — a second AI checks the first

Bugs get caught by an **independent look at the primary source**, not by a smarter model. The reviewer must not inherit the first session's understanding — that's where the errors live.

## When
Before anything is shipped, ordered, sent, or published; after any change touching facts in `record/FACTS.md`; whenever the first session says "I'm confident".

## How to run the second session
1. Open a **fresh** Claude Code session (new terminal, `claude`), or a different AI tool. Not a subagent of the working session, not `--continue`.
2. Paste the brief produced by `/review` in the first session. The brief lists *where* to look, not *what was concluded*.
3. Give it the **primary sources**: datasheet PDFs, official doc URLs, the live system / URL, the actual files and code, `record/DECISIONS.md`, `record/FACTS.md`.
4. **Do NOT give it** the first session's summary, chat transcript, or "here's what I did". If the brief contains conclusions ("X is correct because…"), strip them.
5. The reviewer reports findings only. It does not fix. Fixes happen in the working session, then the reviewer re-checks the specific items.
6. Log the outcome: each confirmed issue → `MISTAKES.md` instance (classified by pattern); each decision prompted by it → `record/DECISIONS.md`.

## Reviewer checklist
Answer each with evidence (file + line, source + page/URL):
- [ ] **Build matches decisions:** for each active entry in `record/DECISIONS.md`, is it actually implemented the way it says? Superseded decisions not still implemented?
- [ ] **Values match the maker's own doc:** every part number, pin, voltage, price, limit, API field, version — compared against the primary source itself, not against FACTS.md alone.
- [ ] **Recorded but not built:** decisions or facts in the record that the build ignores.
- [ ] **Built but not recorded:** behaviour, parts, dependencies, settings in the build with no decision or fact behind them.
- [ ] **Stale copies:** grep each important value — any place still holding an old value (MISTAKES P2)?
- [ ] **Output evidence:** for each "done" item, is there an output check (per `docs/VERIFICATION.md`), or only a mechanism check (MISTAKES P1)?
- [ ] **Secondary-source facts:** any fact whose source is a summary, snippet, or another AI (MISTAKES P3)?
- [ ] **Brakes:** anything irreversible queued or done without a recorded explicit yes?
- [ ] **Queue:** every request in `handoff.md`'s Queue is `[x]` with an output check or `[~] PAUSED` with what's needed; nothing dropped or silently skipped (CLAUDE.md §9)?
- [ ] **Tests:** do the tests guard what the hard rules say? Has each been proven to fail (`tests/BREAK-IT-ONCE.md` checklist dated)?

## Report format
```
# Independent review — <scope> — YYYY-MM-DD
Reviewer: <tool/session>   Sources used: <list of primary sources actually opened>
Sources NOT available: <anything that couldn't be checked — be explicit>

## Findings
| # | Severity (blocker/major/minor) | Finding | Evidence (file:line / source p.N / URL) | Pattern (P1/P2/P3/new) |
|---|---|---|---|---|

## Checklist results
- Build matches decisions: pass/fail — notes
- Values match maker docs: pass/fail — notes
- Recorded but not built: … 
- Built but not recorded: …
- Stale copies: …
- Output evidence: …
- Secondary-source facts: …
- Brakes: …
- Queue: …
- Tests: …

## Verdict
Ship / fix first (list blockers) / can't tell (what's missing)
```
