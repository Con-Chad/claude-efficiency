---
description: Append a decision (with rejected alternatives) to record/DECISIONS.md
argument-hint: <the decision in a sentence>
---
Record a decision in `record/DECISIONS.md`. Decision: $ARGUMENTS

1. Read `record/DECISIONS.md` (rules + template + the last entries). Find the highest `D-NNN` and use the next number.
2. If any of these are unknown, ASK the user before writing — do not invent them:
   - the alternatives that were considered and **why each was rejected** (at least one; "none considered" must be the user's words, not yours);
   - who decided;
   - whether this reverses or replaces an earlier decision (if so, which D-xxx).
3. Link supporting facts (F-xxx in `record/FACTS.md`). If the decision rests on a fact not yet logged, offer to run `/fact` first.
4. Append the entry at the **end** of the file using the template exactly, dated today (`date +%Y-%m-%d`). Status is `active`.
5. Never edit an earlier entry. If this supersedes D-xxx, the new entry says `Supersedes: D-xxx`; the old entry is left untouched.
6. Show the appended entry, then run `bash tests/run.sh append` and report its result.
