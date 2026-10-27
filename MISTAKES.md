# Mistakes register — {{PROJECT_NAME}}

Grouped by **pattern** — not just what went wrong, but which *kind* of wrong. Read the pattern headings at the start of every session (the SessionStart hook reminds you). Knowing the patterns prevents more mistakes than any single fix.

## Rules
- Append-only (same as `record/`). Never edit or delete an instance; add a new dated line.
- New mistake → first try to classify it into an existing pattern. Only create a new pattern when it genuinely doesn't fit (`/mistake` does this).
- Each instance: date, what happened, how it was caught, what fixed it, link to lesson (L-xxx) if one was logged.
- When a pattern collects 3+ instances, consider a hard rule + test in `CLAUDE.md`.

---

## P1 — Confirmed the job ran instead of checking its output
**Description:** Treating evidence that a mechanism executed (exit code 0, "loaded", "sent", green CI, "migration applied") as evidence that the intended result exists.
**How to recognize it:** The "proof" you're about to report is a status, a log line saying it started, or the absence of an error. You haven't opened the file, seen the email in an inbox, loaded the page, or compared the number.
**Countermeasure:** Before saying "done", name the output and inspect it directly — see `docs/VERIFICATION.md`. Report what you saw ("archive has 214 files, newest 08:00 today"), not what ran.
**Instances:**
<!-- Append dated instances below: - YYYY-MM-DD — what happened — how caught — fix — L-xxx -->

## P2 — Changed one copy of a fact without searching for the others
**Description:** A value (price, pin number, address, version, limit, name) lives in several places; one was updated and the rest silently went stale.
**How to recognize it:** You are editing a number, name or setting that could plausibly appear elsewhere (docs, config, BOM, emails, tests, README). You haven't grepped for the old value.
**Countermeasure:** Before changing a fact, `grep -rn "<old value>" .` (and variants: with/without units, formatted differently). Update every copy in the same change, then grep again for the old value — zero hits is the output check. Log the new value in `record/FACTS.md` with "Copies of this value live in".
**Instances:**
<!-- Append dated instances below: - YYYY-MM-DD — what happened — how caught — fix — L-xxx -->

## P3 — Trusted a tool's summary over the primary source
**Description:** Relying on a summary (search snippet, AI recap, another session's report, a distributor's listing, a tool's "success" message) instead of reading the original: the maker's datasheet, official docs, the live system.
**How to recognize it:** The fact you're using came from something that *describes* the source rather than the source itself. Or you can't say which page/table/URL the value is on.
**Countermeasure:** Open the primary source and read the value yourself; cite page/section in `record/FACTS.md`. For anything that matters, have an independent session check it against the same primary source (`docs/REVIEW.md`) — never against your summary.
**Instances:**
<!-- Append dated instances below: - YYYY-MM-DD — what happened — how caught — fix — L-xxx -->

---

## Template — adding a new pattern
Only when a mistake doesn't fit P1–P3 (or later patterns). Use the next number. Append at the end of the file.
```
## Pn — <name: the kind of wrong, phrased as what was done>
**Description:** <the general shape of the mistake, not the single incident>
**How to recognize it:** <the signal, in the moment, that you're about to make it>
**Countermeasure:** <the concrete check or habit that prevents it; a test if possible>
**Instances:**
<!-- Append dated instances below: - YYYY-MM-DD — what happened — how caught — fix — L-xxx -->
- YYYY-MM-DD — <first instance>
```
