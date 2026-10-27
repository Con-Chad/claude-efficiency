---
description: Show-before-build — produce a cheap sketch of a big change, then STOP for reaction
argument-hint: <what the user wants built>
---
Produce a show-before-build sketch for: $ARGUMENTS

Do NOT write production code, install anything, or change project files in this step. (A throwaway mock-up file in a scratch location is fine if a picture helps.)

Output, briefly:
1. **What you'll get** — the thing as the user will experience it: a mock-up (ASCII/markdown layout, a quick HTML or diagram), an example of the output, or a plain-language walkthrough. Make it concrete enough to react to.
2. **What it costs** — effort (rough hours/sessions), money (services, parts, subscriptions — with sources if known), new dependencies, ongoing maintenance, and what's hard to undo.
3. **What it is NOT** — what's out of scope or deferred.
4. **Options** — if there's a meaningfully cheaper/simpler version, show it side by side.
5. **Open questions** — the decisions the user needs to make (each will become a D-xxx entry).
6. **How we'll know it works** — the output check (per `docs/VERIFICATION.md`).

Then STOP and ask for the user's reaction. Build only after they respond. Record the chosen option with `/decision`.
