---
paths:
  - "record/**"
  - "MISTAKES.md"
---
# Writing to the record (loads only when record files are touched)

- Append only (rule H2). Add with **Edit**: `old_string` = the file's current last line(s), `new_string` = those same lines + the new entry. Never use Write on an existing record file — `scripts/record-guard.sh` blocks it, and blocks any Edit that drops or rewords existing text.
- Corrections, reversals and status changes are NEW entries that reference the old ID (`Supersedes: D-xxx`). Never touch the old one, not even a typo.
- IDs are sequential per file (D-, F-, L-); find the highest with `grep -oE '^### [DFL]-[0-9]+' <file> | tail -1`, not by reading the whole file.
- Use today's date (`date +%Y-%m-%d`), not one you remember.
- After appending: `bash tests/run.sh append`, and show the entry you added.
