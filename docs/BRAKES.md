# Brakes — irreversible actions

Anything that can't be undone needs an **explicit yes, every time**. The hook `scripts/brake-check.sh` catches the common shell forms; this document is the full policy and applies whether or not the hook catches it (web forms, MCP tools, browser actions, API calls from code).

## The list — always ask first
**Money**
- Any purchase, order, subscription, upgrade, paid API tier, ad spend, invoice payment, refund.
- Committing to a price or quantity in writing (quotes, POs, "go ahead" to a supplier).

**Deleting / destroying**
- `rm -rf`, deleting files outside the project's scratch area, emptying trash.
- `git reset --hard`, `git branch -D`, `git clean -f`, force-push, deleting tags/releases/repos.
- `DROP TABLE/DATABASE`, `TRUNCATE`, bulk `DELETE`/`UPDATE` without `WHERE` reviewed, deleting cloud resources (`aws … delete/terminate`, `gcloud … delete`, `kubectl delete`, `terraform destroy`).
- Overwriting the only copy of anything.

**Contacting real people**
- Sending email (`mail`, `sendmail`, SMTP, email APIs), SMS, Slack/Discord/WhatsApp messages, posting comments, filing issues on other people's repos, submitting web forms to companies.
- Anything sent "as" the user.

**Pushing live / publishing**
- `git push` to shared remotes, merging PRs, `npm publish` and other registries, deploys (`vercel --prod`, `firebase deploy`, etc.), `terraform apply`, DNS changes, app-store submissions, social posts.
- HTTP `POST/PUT/PATCH/DELETE` to any non-localhost system.

**Access**
- Changing permissions, sharing settings, API keys, passwords, billing details.

## Approval semantics — what "yes" covers
- Before acting, propose exactly: **what** (the command / recipient / amount / target), **effect**, **what can't be undone**, and **how we'll check it worked**.
- A plain "yes" approves **exactly that proposal, once**. It does not cover: a retry after it fails, a modified version, the "same thing" for another file/recipient, the remaining items in a batch, or anything in the future.
- If anything about the action changes after the yes (recipient, amount, wording, flags), ask again.
- "Yes to all N" is valid only if all N were listed in the proposal.
- Silence, "sounds good" about a plan, or "go ahead" earlier in the session is **not** approval for the irreversible step inside it — ask at the step.
- When the hook blocks: ask; on yes, re-run the **identical** command prefixed `BRAKE_APPROVED=1 `. Never use the prefix pre-emptively or on a command the user hasn't seen.
- Record approvals of consequence (orders, first contact, deploys) in `record/DECISIONS.md`.

## New-contact pre-check (before contacting any new company or person)
Run every time the recipient is new to this project:
1. **Verify the address on their own website.** Open the company's official site (typed from a known domain, not from a search ad or a link inside an email) and find the contact address/form there. Note the page URL. Reject addresses found only in directories, AI summaries, or forwarded emails (MISTAKES P3).
2. **Log it** in `record/FACTS.md`: "Contact address for X", source URL, date checked.
3. **Scan the draft for commitments.** Highlight every sentence that commits the user to anything: prices, quantities, dates, "we will", "we agree", "please proceed", order or payment language, sharing of personal or confidential info. List them for the user.
4. **Scan for prices and numbers.** Every price/quantity/spec in the draft is checked against `record/FACTS.md` (and its primary source).
5. **Show the user** the final recipient, subject, full body, attachments, and the commitment list. Send only on an explicit yes to that exact draft.

## The tired rule
If the user says they're tired, it's late at night (their local time), or they're clearly rushing: **irreversible actions wait until morning.** Prepare everything — the draft, the command, the checklist — and leave it ready in a handoff note (`templates/handoff.md`). Reversible work can continue. This applies even if the user says "just do it" while tired; offer to queue it instead, and do it only if they insist with a fresh, explicit yes.

## What the hook covers (and doesn't)
Covered (shell commands): git push/force-push/reset --hard/branch -D/clean -f, rm -rf, disk formatting, SQL DROP/TRUNCATE, mail/sendmail, package publishing, terraform apply/destroy, kubectl/helm delete, aws/gcloud destructive verbs and deploys, common deploy CLIs, curl/wget/httpie writes to non-localhost hosts.
Not covered: MCP/browser/web actions, API calls made from inside scripts or programs, commands obfuscated through variables or `eval`. For those, this policy is the brake. To extend the hook, add a pattern to `scripts/brake-check.sh`, add a sample to `tests/test_brake_check.sh`, and break-it-once.
