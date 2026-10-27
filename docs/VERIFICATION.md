# Verification playbook — check the output, not the mechanism

A green tick means it **ran**. It does not mean it **worked**. Every task is proven by its result: the email arrived, the file landed, the number matches the source.

**The test:** could the thing I'm about to call "proof" look exactly the same if the result were wrong or missing? If yes, it's a mechanism check. Keep going.

## Common tasks

| Task | Mechanism check (misleading) | Output check (real) |
|------|------------------------------|---------------------|
| Scheduled job (cron / launchd) | `launchctl list` shows the label; `crontab -l` shows the line; exit status 0 in the log | The file/row/report the job produces exists **with a timestamp from the expected run** and real content: `ls -lt <dest> \| head`, open the newest one. For launchd also check `StandardErrorPath` is empty. |
| Backup | Script printed "done"; no errors | `tar -tzf <newest>.tar.gz \| wc -l` gives the expected file count; extract one file to a temp dir and `diff` it against the original; the second destination has the same archive. |
| Email / message send | API returned 200 / "queued"; `sendmail` exit 0 | Message is in the recipient's inbox (or a test inbox you control), or the provider's delivery log shows *delivered* for that message ID. Read the received copy: subject, body, links, attachments. |
| File write / export | Function returned; no exception | File exists at the exact path, size > 0, opens in the target app, contents spot-checked (first/last lines, a known value). |
| Database migration | "Migration applied"; schema version bumped | Query the real DB: new column/table exists, row counts before vs after match expectations, 2–3 known records read back correctly. |
| Deploy | CI pipeline green; "deployed" message | Load the live URL (hard refresh / curl with cache-buster) and see the specific new change; check the version/commit string the live app reports. |
| Test run | "All tests passed" | Each test has been **seen to fail** when the thing it guards is broken (`tests/BREAK-IT-ONCE.md`); count of tests run is what you expect (not 0). |
| Data import | "Imported N rows" | Row count in destination = row count in source (counted independently); 3 random records compared field-by-field with the source; totals (sums) match. |
| Config change | File saved; service restarted | The running system shows the new behaviour (feature on/off, new value visible in its status/output). |
| Fact in a document | "Matches what we had before" | Matches the **primary source**, re-opened today; logged in `record/FACTS.md` with source and date; grep finds no stale copies of the old value (MISTAKES P2). |
| Order / purchase | Checkout page said "success" | Order confirmation received with the correct items, quantities, prices and address; recorded in `record/DECISIONS.md`. |
| Hook / guard installed | Settings file contains the hook | Trigger it on purpose with a harmless sample and see it block (`tests/test_brake_check.sh`). |

## How to report
Bad: "Backup script ran successfully."
Good: "Backup ran 08:00. Newest archive `…-20260115-0800.tar.gz` in both destinations, 214 files, `CLAUDE.md` extracted and identical to the live file."

If the output can't be checked from here (e.g. needs the user's inbox or phone), say so plainly and tell the user exactly what to look at. Never fill the gap with "should be working".

Use `/verify` after every task.
