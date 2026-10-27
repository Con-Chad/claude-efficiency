# Break it once — prove each test can fail

A test that can't fail is decoration. Before trusting any test, break the thing it guards **on purpose**, watch the test go red with the expected message, then undo the break and watch it go green. Record the date below. Redo this whenever a test is rewritten.

Do this in a throwaway branch or with uncommitted changes you will revert. Every step below is reversible.

## test_append_only.sh — rule H2 (record is append-only)
Needs a git repo with at least one commit.
1. Break: change one word in an existing committed line, e.g. the `Decision:` line of `D-000` in `record/DECISIONS.md`.
2. Run: `bash tests/run.sh append`
3. Expected:
   ```
   FAIL  test_append_only
         FAIL: record/DECISIONS.md — existing entries were edited or removed (append-only, rule H2):
             -- Decision: Use one SQLite file ...
   ```
4. Undo: `git checkout HEAD -- record/DECISIONS.md`, re-run, expect `PASS  test_append_only`.
5. Also confirm additions are allowed: append a new entry at the bottom, run, expect PASS; then remove it again.

## test_no_secrets.sh — rule H3 (no secrets)
1. Break: create a file with a fake AWS-style key (built with printf so this doc doesn't contain one):
   `printf 'key = AKIA%s\n' ABCDEFGHIJKLMNOP > break-test.txt`
2. Run: `bash tests/run.sh secrets`
3. Expected:
   ```
   FAIL  test_no_secrets
         FAIL: AWS access key id in break-test.txt:1 (value not shown)
   ```
4. Undo: `rm break-test.txt`, re-run, expect PASS.
5. Optional second break: `printf 'pass''word=%s\n' hunter2hunter > break-test.txt` → expect `Password assignment`.

## test_hooks_installed.sh — rule H1 (brake hook is wired up)
1. Break: `chmod -x scripts/brake-check.sh`
2. Run: `bash tests/run.sh hooks`
3. Expected:
   ```
   FAIL  test_hooks_installed
         FAIL: scripts/brake-check.sh is not executable (chmod +x scripts/brake-check.sh)
   ```
4. Undo: `chmod +x scripts/brake-check.sh`, re-run, expect PASS.
5. Second break: in `.claude/settings.json` change `"matcher": "Bash"` to `"matcher": "Bashx"` → expect `FAIL: no PreToolUse hook with a Bash matcher runs scripts/brake-check.sh`. Undo.

## test_brake_check.sh — rule H1 (brake hook actually blocks)
1. Break: in `scripts/brake-check.sh`, change the git push line `push${E}` to `pushx${E}` (so the git-push rule never matches).
2. Run: `bash tests/run.sh brake`
3. Expected (several lines, one per mode):
   ```
   FAIL  test_brake_check
         FAIL [jq]: expected exit 2, got 0 for: git push origin main
         ...
         FAIL: block message doesn't explain explicit yes + BRAKE_APPROVED=1 re-run
   ```
4. Undo the edit (or `git checkout HEAD -- scripts/brake-check.sh`), re-run, expect PASS.
5. Second break: change `exit 2` at the bottom of the script to `exit 1` → every dangerous sample fails with `got 1`. Undo.

## test_record_guard.sh — rule H2 at edit time (record-guard hook blocks rewrites)
1. Break: in `scripts/record-guard.sh`, change the final `exit 2` to `exit 0` (the guard now lets everything through).
2. Run: `bash tests/run.sh guard`
3. Expected:
   ```
   FAIL  test_record_guard
         FAIL [jq]: expected exit 2, got 0 — Write over existing DECISIONS.md
         FAIL [nojq]: expected exit 2, got 0 — Write over existing DECISIONS.md
         ...
   ```
4. Undo the edit, re-run, expect `PASS  test_record_guard`.
5. Second break: delete the line `[ -z "$reason" ] && exit 0` → the "MultiEdit appends only" case fails with `expected exit 0, got 2` (this exact bug was caught by the test while writing the hook). Undo.

## test_lifecycle_hooks.sh — session-start briefing, save-state snapshot, context nudge, stop gate
1. Break: in `scripts/stop-check.sh`, change the final `exit 2` to `exit 0`.
2. Run: `bash tests/run.sh lifecycle`
3. Expected:
   ```
   FAIL  test_lifecycle_hooks
         FAIL: stop-check didn't block on failing tests after a change
   ```
4. Undo, re-run, expect PASS.
5. More breaks (one at a time, undo each): in `scripts/session-start.sh` change `tail -3` to `tail -0` → `session-start doesn't show recent decisions`; in `scripts/context-nudge.sh` change `-eq "$first"` to `-eq 999` and `% 30` to `% 30000` → `context-nudge silent at threshold`.

## test_hooks_installed.sh — the new hooks are wired up
- Break: in `.claude/settings.json` delete the whole `"Stop"` block (or `chmod -x scripts/context-nudge.sh`) → expect `FAIL: no Stop hook runs scripts/stop-check.sh` (or `... is not executable`). Undo.

## test_adopt.sh — adopt-into.sh is additive and idempotent (template-only; skips where adopt-into.sh is absent)
1. Break: in `scripts/adopt-into.sh`, change the CLAUDE.md idempotency check `grep -q '<!-- BEGIN claude-process-template -->'` to `grep -q 'NEVER-MATCHES'` (a re-run now appends the block again).
2. Run: `bash tests/run.sh adopt`
3. Expected:
   ```
   FAIL  test_adopt
         FAIL: second run changed files (not idempotent)
         FAIL: second run didn't say 'Nothing to do'
   ```
4. Undo the edit, re-run, expect `PASS  test_adopt`.
5. Second break: in the settings merge, replace the jq program's input `"$T/.claude/settings.json"` with `"$TS"` (template overwrites the project's settings) → expect `FAIL: unrelated key 'model' lost` and `existing PostToolUse hook lost`. Undo.

## test_global_install.sh — global/install.sh is preview-by-default, additive and idempotent (template-only; skips where global/install.sh is absent)
1. Break: in `global/install.sh`, change the CLAUDE.md check `elif grep -qF "$BEGIN" "$MD" || grep -qxF "$HEADING" "$MD"; then` to `elif grep -qF "NEVER-MATCHES" "$MD"; then` (a re-run now appends the rules again).
2. Run: `bash tests/run.sh global`
3. Expected:
   ```
   FAIL  test_global_install
         FAIL: second apply changed files (not idempotent)
         FAIL: second apply didn't say 'Nothing to do'
         FAIL: second apply on existing home changed files
         FAIL: CLAUDE.md changed although the rules heading was already there
   ```
4. Undo the edit, re-run, expect `PASS  test_global_install`.
5. Second break (drift guard): in `global/hooks/brake-check.sh` change `label="sending email"` to `label="sending an email"` → expect `FAIL: pattern section differs between scripts/brake-check.sh and global/hooks/brake-check.sh — change both`. Undo.

## tests/run.sh itself
- Break: run it with a filter that matches no test: `bash tests/run.sh nomatch` → the runner must print `ERROR: no tests ran — that is not a pass.` and exit 1.

## Proven-to-fail checklist
Fill in each row the first time. When you redo a test later, add a new row below rather than overwriting the old one.

| Test | Date proven to fail | By | Failure message seen |
|------|---------------------|----|----------------------|
| test_append_only.sh | | | |
| test_no_secrets.sh | | | |
| test_hooks_installed.sh | | | |
| test_brake_check.sh | | | |
| test_record_guard.sh | | | |
| test_lifecycle_hooks.sh | | | |
| run.sh (zero tests) | | | |
| test_adopt.sh | 2026-10-27 | AI session (building adopt-into) | `FAIL: second run changed files (not idempotent)` + `second run didn't say 'Nothing to do'` |
| test_global_install.sh | 2026-10-27 | AI session (building global/install.sh) | `FAIL: second apply changed files (not idempotent)` + `CLAUDE.md changed although the rules heading was already there`; drift break: `pattern section differs ...` |
<!-- placeholder: add a row for every project-specific test you add, and break it once. -->
