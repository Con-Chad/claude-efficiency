---
description: Write the brief for an independent second-AI review against primary sources
argument-hint: <scope to review, e.g. "power board v2" or "launch emails">
---
Prepare an independent-review brief for: $ARGUMENTS

Follow `docs/REVIEW.md`. The reviewer must look at the PRIMARY sources fresh. Your job is to point at sources, not to share conclusions.

Produce a single markdown block the user can paste into a fresh session, containing:
1. **Scope:** what is being reviewed (files, features, parts, messages) — one paragraph, no claims about correctness.
2. **Primary sources to open** — a concrete list: datasheet/manual paths or URLs (with the relevant sections), official doc URLs, the live system URL / command to inspect it, the actual code/config files, `record/DECISIONS.md`, `record/FACTS.md`.
3. **Do not use:** this session's summary, transcript, or any "here's what I did" notes. Say this explicitly in the brief.
4. **The reviewer checklist** copied from `docs/REVIEW.md` (build matches decisions; values match maker's docs; recorded-but-not-built; built-but-not-recorded; stale copies; output evidence; secondary-source facts; brakes; queue; tests).
5. **Report format** copied from `docs/REVIEW.md`.
6. Instruction: report findings only, do not fix.

Before outputting, re-read the brief and delete any sentence that tells the reviewer what the answer is ("X is correct", "we confirmed Y"). Then tell the user how to start the second session (fresh terminal → `claude` in this directory, or another AI tool) and to bring its report back here.
