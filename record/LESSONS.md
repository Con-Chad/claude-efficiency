# Lessons — {{PROJECT_NAME}}

Append-only log of lessons learned **and who was told**. A lesson nobody was told about gets learned again.

## Rules
1. **Never edit or delete an entry.** If a lesson turns out wrong, append a new entry with `Supersedes: L-xxx`.
2. Record what triggered the lesson (link the MISTAKES instance or decision if there is one).
3. Record who was told, when, and how — including "CLAUDE.md updated" when the lesson became a rule for the AI.
4. If the lesson should change behaviour every session, also add/adjust a hard rule in `CLAUDE.md` (and a test if possible).
5. Add with `/lesson`.

## Entry template
```
### L-NNN — <the lesson in one sentence>
- Date: YYYY-MM-DD
- Trigger: <what happened that taught this; link MISTAKES Pn instance / D-xxx>
- Lesson: <what we now do differently, concretely>
- Told: <who / role> on YYYY-MM-DD via <chat/email/meeting/CLAUDE.md>
- Changed: <files, rules, tests added because of it, or "none">
- Supersedes: <L-xxx or none>
```

## Worked example (illustrative — shows the format)
### L-000 — A scheduled job "running" told us nothing about whether the backup existed
- Date: 2026-01-20
- Trigger: MISTAKES P1 instance 2026-01-20 — nightly backup reported loaded for 9 days while writing empty archives.
- Lesson: Every scheduled job gets an output check: newest file's timestamp and contents, not the scheduler's status.
- Told: owner on 2026-01-20 via chat; AI via CLAUDE.md §2 example.
- Changed: `docs/VERIFICATION.md` row for launchd jobs; backup script now lists archive contents after writing.
- Supersedes: none

## Entries
<!-- Append new lessons below this line. -->
