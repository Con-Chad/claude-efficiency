---
description: Classify a mistake by pattern and append an instance to MISTAKES.md
argument-hint: <what went wrong>
---
Log a mistake in `MISTAKES.md`. What happened: $ARGUMENTS

1. Read every pattern in `MISTAKES.md` (`## P1…`, name, description, how to recognize).
2. Classify: which **kind** of wrong is this? Pick the best-fitting existing pattern and say why in one line. Only if it genuinely fits none, propose a new pattern (next `Pn` number, using the "Template — adding a new pattern" section) and show it to the user before adding.
3. Append one instance line under that pattern's `**Instances:**` list (below the comment line, after any existing instances):
   `- YYYY-MM-DD — what happened — how it was caught — what fixed it — L-xxx (if any)`
   Use today's date. Do not edit or reorder existing lines. A new pattern goes at the end of the file.
4. Check the countermeasure: was it followed? If the pattern now has 3+ instances, propose a hard rule + test in `CLAUDE.md`.
5. If there's a lesson others need to hear, offer `/lesson`.
6. Run `bash tests/run.sh append` and report the result.
