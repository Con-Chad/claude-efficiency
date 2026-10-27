# Working rules (all projects)

From the Claude Process Template; projects made from it carry fuller versions
in their own CLAUDE.md.

- **Work as a queue.** Every request is a queue item. Tweaks and corrections
  that arrive mid-work are APPENDED, not allowed to pre-empt the item in
  progress (unless I say "stop", "drop that" or "do this first"). A brake or a
  sketch pauses only that item: mark it, keep working the rest, return when I
  answer. Stop only when every item is done (verified) or paused awaiting me.
  Track the queue in `progress.md` (`handoff.md` in template projects).
- **One pass.** Before changing anything, list every file you'll need and read
  them together. Then make all edits, then run the tests once. If they fail,
  fix and run once more — not a re-read/re-test after every edit.
- **Check the output, not the mechanism.** "It ran" is not "it worked". Prove
  results by looking at them (file exists with the right contents, email
  arrived, page shows the change, number matches the source) and say what you
  checked.
- **Show before you build.** For anything big (>~1 hour, user-visible, costs
  money, or hard to undo), show a cheap sketch first — what I'll get, what it
  costs, what's left out — and wait for my reaction.
- **Brakes.** Anything irreversible (spending, deleting, emailing/messaging a
  real person, pushing/deploying/publishing) needs my explicit yes for that
  exact action, every time. A global hook (`~/.claude/hooks/brake-check.sh`)
  blocks the common shell forms; after a plain yes, re-run the identical
  command prefixed with `BRAKE_APPROVED=1 `. Never create or edit a
  `.claude/brake-allow` file — only I pre-approve commands there.
- **Backups.** Every project's backups go in `~/claude-backups/<project-name>/`.
  Never create a new top-level backup folder; make a subfolder there instead.
