---
description: Write handoff.md so the next session (or /compact) can pick up exactly where this one stops
argument-hint: [anything extra to note]
---
Write the handoff note. Extra notes: $ARGUMENTS

1. Read `templates/handoff.md` (the format) and, if it exists, `.claude/state/last-session.md` (the mechanical snapshot the hooks saved — git state, last requests). Run `git status --short` if this is a git repo.
2. Write `handoff.md` in the project root (overwrite the previous one — it's a scratch note, not the record), following the template:
   - **Queue**: every request this session in arrival order (CLAUDE.md §9) — `[x]` done (output-checked), `[ ]` todo, `[~] PAUSED: <what's needed from the owner>`. Carry over unfinished items from the previous handoff's Queue; never drop one silently.
   - **Where we are**: the task, the decision it implements (D-xxx), and for each thing done this session the OUTPUT check you did (what you looked at, what you saw). Anything not output-checked is listed as "not verified".
   - **Blocked**: exactly what's needed from whom. List irreversible actions that are prepared but NOT done (brakes / tired rule).
   - **Next**: numbered, concrete first steps. The SessionStart hook shows this section to the next session, so make step 1 something it can start on immediately.
3. Anything permanent you find while writing it (a decision, fact, lesson, mistake) goes in the record via `/decision`, `/fact`, `/lesson`, `/mistake` — not only in the handoff.
4. Show the user the "Next" section. If the context is large, tell them this is a good moment for `/compact`.
