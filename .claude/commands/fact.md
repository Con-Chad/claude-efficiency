---
description: Append a fact with its primary source and today's date to record/FACTS.md
argument-hint: <the fact, e.g. "max VIN is 28 V">
---
Record a fact in `record/FACTS.md`. Fact: $ARGUMENTS

1. Read `record/FACTS.md` (rules + template). Next ID = highest `F-NNN` + 1.
2. Identify the **primary source** — maker's datasheet/manual (with page/table), official docs URL, the live system, or the person who owns the fact. If the only source is a summary, search snippet, distributor listing, or an earlier AI answer, STOP: open the primary source and read the value yourself, or tell the user it's unverified (MISTAKES P3).
3. Copy the value exactly, with units, as the source states it.
4. Search the repo for other copies of this value (and of any old value it replaces): `grep -rn "<value>" .` — list them in "Copies of this value live in" (MISTAKES P2). If an old value exists elsewhere, list the files to update and ask before changing them.
5. Append the entry at the **end** of the file using the template, `Date checked:` today (`date +%Y-%m-%d`), `Verified by:` who actually read the source. If it corrects an earlier fact, add `Supersedes: F-xxx` — do not edit the old entry.
6. Show the entry and run `bash tests/run.sh append`.
