---
description: Append a lesson (trigger + who was told) to record/LESSONS.md
argument-hint: <the lesson in one sentence>
---
Record a lesson in `record/LESSONS.md`. Lesson: $ARGUMENTS

1. Read `record/LESSONS.md` (rules + template). Next ID = highest `L-NNN` + 1.
2. Fill in: the trigger (link the MISTAKES.md instance or D-xxx if there is one), the concrete change in behaviour, and **who was told, when, and how**. If nobody has been told yet, ask the user who should be, and record "not yet told — <who>" rather than leaving it blank.
3. If the lesson should change every future session, propose the exact edit to `CLAUDE.md` (a hard rule with RULE / WHY / ENFORCED BY, plus a test if it can be tested). Make it only after the user agrees; then record "Told: AI via CLAUDE.md <section>".
4. Append at the **end** of the file, dated today. Never edit earlier entries.
5. Show the entry and run `bash tests/run.sh append`.
