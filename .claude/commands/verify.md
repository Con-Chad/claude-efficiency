---
description: Prove the last task worked by checking its OUTPUT, not its mechanism
argument-hint: [task to verify — defaults to the last one]
---
Verify: $ARGUMENTS (if blank: the last task you completed in this session)

Follow `docs/VERIFICATION.md`.
1. State the task in one line.
2. State the **mechanism check** you might be tempted to rely on (exit code, "loaded", "sent", green tick) — and set it aside.
3. State the **output check**: the specific result that would exist only if the task actually worked (file at path with today's timestamp and expected contents; email in an inbox; row counts matching the source; live URL showing the change; a test seen to fail when broken; a number matching the primary source).
4. **Perform** the output check now with real commands/reads. Show what you saw (counts, timestamps, the actual value), not a paraphrase.
5. Verdict: VERIFIED / NOT VERIFIED / CAN'T VERIFY FROM HERE. For the last one, tell the user exactly what to look at themselves.
6. If it failed, or you had earlier reported it done without this check, log a MISTAKES P1 instance (`/mistake`).
