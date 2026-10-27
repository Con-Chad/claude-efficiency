---
description: End-of-session sweep — turn this session's corrections into record entries, and promote repeat patterns into rules + tests
argument-hint: [focus, optional]
---
Learning sweep for this session. Focus: $ARGUMENTS

Our version of "continuous learning": nothing is learned unless it lands in the record or in a rule with a test. No hidden memory, no confidence scores.

1. Scan this session for: places the user **corrected** you; errors you hit and how they were resolved; things you had to look up twice; workarounds; anything you'd do differently. List them (one line each) — don't write anything yet.
2. Classify each, and show the user the list with your proposed destination:
   - went wrong → `/mistake` (classify into a MISTAKES pattern first)
   - something to tell people or change behaviour → `/lesson`
   - a value established from a primary source → `/fact`
   - a choice made, with alternatives rejected → `/decision`
   - nothing durable → drop it, say so
3. After the user agrees, append the entries (each via its command's steps).
4. **Promotion check:** for every MISTAKES pattern with 3+ instances, and every lesson that has now come up twice, propose ONE of: a hard rule row in `CLAUDE.md` §1 (RULE / WHY / ENFORCED BY) + a test that can fail; a path-scoped rule in `.claude/rules/` (if it only matters for certain files); or a line in `docs/`. Prefer the cheapest thing that will actually be enforced. Treat it as a `/sketch` — build only after a yes, then break the new test once.
5. Report: entries added (IDs), promotions proposed/done, and `bash tests/run.sh append` result.
