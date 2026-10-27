# Facts — {{PROJECT_NAME}}

Append-only log of every fact the project relies on: prices, specs, part numbers, limits, addresses, dates, rules. Each one has a **source** and **the date it was checked**.

## Rules
1. **Primary source only.** The maker's datasheet, the official docs, the live system, the person who owns the fact. Not a tool's summary, not a forum post, not an earlier AI answer (see MISTAKES P3).
2. **Never edit or delete an entry.** If a fact changes or was wrong, append a new entry with `Supersedes: F-xxx` and say what changed. Then search the repo for every other copy of the old value and update those (MISTAKES P2).
3. A fact older than its "recheck by" date must be re-checked before anything depends on it.
4. Add with `/fact`.

## Entry template
```
### F-NNN — <short name of the fact>
- Fact: <the value, exactly, with units>
- Source: <URL / document + page/section / person + role>
- Date checked: YYYY-MM-DD
- Verified by: <who opened the source and read the value — person or "AI session, primary source">
- Recheck by: <date, or "stable">
- Copies of this value live in: <files/places, so they can all be updated together>
- Supersedes: <F-xxx or none>
```

## Worked example (illustrative — shows the format)
### F-000 — Max input voltage of the example regulator
- Fact: 28 V absolute maximum on VIN (recommended operating max 24 V)
- Source: Manufacturer datasheet for the part, Rev C, Table 7.1 "Absolute Maximum Ratings" (PDF in `sources/`)
- Date checked: 2026-01-15
- Verified by: AI session reading the datasheet PDF directly; confirmed by owner
- Recheck by: stable (datasheet revision change only)
- Copies of this value live in: `docs/power.md`, `bom.csv` notes column
- Supersedes: none

## Entries
<!-- Append new facts below this line. -->
