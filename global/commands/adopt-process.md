---
description: Add the Claude Process Template (record, mistakes register, hooks, tests, rules) to the current project — dry run first, then only on an explicit yes
---

Add the Claude Process Template's process to the project in the current directory. This is a show-before-build moment: nothing changes until the owner says yes.

1. **Check the folder.** If the current directory is `/`, the home directory, `~/Downloads`, or not the top level of a git repo, stop and say so (for a non-git folder suggest `git init && git add -A && git commit -m "Before adopting process"` first). The script refuses these too.

2. **Dry run.** Run, in the foreground:
   `bash "{{TEMPLATE_DIR}}/scripts/adopt-into.sh" "$PWD" --dry-run`
   Then explain the plan to the owner in plain English:
   - what will be created, what will be merged (`.claude/settings.json` — say which hooks/permissions get added and that existing ones stay), what gets appended (`CLAUDE.md` block, `.gitignore` lines);
   - the test layout (standard `tests/` or separate `tests/process/` because the project has its own tests);
   - every CONFLICT (an existing file that is kept and NOT replaced) with its suggestion;
   - that nothing is overwritten or deleted, and the original settings are saved as `.claude/settings.json.pre-adopt`.
   If it says "Nothing to do", report that and stop.

3. **Wait for an explicit yes.** Ask: "Apply this?" Do not proceed on anything other than a clear yes to this plan. If the owner asks for changes, explain what is possible and re-run the dry run.

4. **Apply.** On yes, run the same command without `--dry-run`, in the foreground.

5. **Verify by output, not by exit code.**
   - Run the process test runner the script reported (`bash tests/run.sh`, or `bash tests/process/run.sh` in the separate layout) in the foreground, and report the pass/fail/skip counts and any failures. `test_append_only` skipping before the first commit is expected.
   - Show `git status --short` and summarise what was added/modified. Confirm the project's own files were not changed except the appended `CLAUDE.md` block, `.gitignore` lines and merged `settings.json` (`git diff --stat`).
   - Spot-check `jq '.hooks | keys' .claude/settings.json` shows the template hooks alongside any the project had.

6. **Do not commit** unless the owner asks. Finish with next steps: review `git diff`, commit, break each test once per `BREAK-IT-ONCE.md`, fill in the `placeholder` comments, resolve any CONFLICTs.
