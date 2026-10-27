---
paths:
  - "tests/**"
  - "scripts/**"
  - ".claude/settings.json"
---
# Changing tests, scripts or hooks (loads only when these files are touched)

- Bash only (bash 3.2 + standard tools; `jq` optional with a grep/sed fallback). No Node/Python.
- A new hook needs ALL of: a script in `scripts/` (executable, sourcing `hook-lib.sh` if it parses JSON), registration in `.claude/settings.json`, a check in `tests/test_hooks_installed.sh`, a behaviour test, and an entry in `tests/BREAK-IT-ONCE.md`.
- Every hook gets an off switch through `HOOKS_OFF=<name>` (see `hook-lib.sh`).
- Exercise it by hand before saying done: `printf '%s' '<sample JSON>' | scripts/<hook>.sh; echo $?` — check the exit code AND the stdout/stderr text.
- A new or rewritten test must be broken once on purpose (`tests/BREAK-IT-ONCE.md`) and seen to fail with the expected message, then restored.
- `bash -n` every script you touched; run `bash tests/run.sh` in the foreground.
- A test that runs the hooks must work in a `mktemp -d` copy, never mutate the real project state, and must not call `tests/run.sh` (the Stop hook runs the suite — recursion).
