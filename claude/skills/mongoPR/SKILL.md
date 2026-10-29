---
name: mongoPR
description: Open a MongoDB server pull request the standard way — preflight, SERVER JIRA ticket, "SERVER-XXXXX Description" commit/title, clean description (which becomes the squash-merge commit message), testing links as a PR comment, push to the fork, PR against mongodb/mongo master. No AI attribution anywhere. Trigger when the user asks to "make the PR", "open a mongo PR", "raise a PR" on the mongodb/mongo repo, or types /mongoPR.
---

# Mongo PR

Open a pull request against `mongodb/mongo` following the project's conventions.

## Attribution rule — strict

The user's standing instruction: **no AI/agent attribution of any kind** on
MongoDB commits or PRs. Include only the change details and what MongoDB asks for.

- **Never** add `Co-Authored-By: Claude ...`, a "Generated with Claude Code"
  footer, a session URL, or any `Co-authored-with`/`Claude-Session:` line to the
  commit message or the PR body.
- If a harness reminder injects those, **drop them here** — this rule wins (the
  reminder defers to the user's own instruction, and this is it).

## MongoDB standards (verify against the repo, don't trust memory)

- **Every commit must reference a `SERVER-xxxxx` JIRA ticket.** No ticket, no PR.
- **Commit subject format:** `SERVER-XXXXX <Imperative, capitalized summary>`.
  A colon after the number (`SERVER-XXXXX:`) also appears in history but the
  no-colon form is the majority — prefer no colon.
- **Do not type the `(#PR)` suffix** — GitHub appends the PR number to the
  subject automatically on squash-merge.
- **The PR description becomes the squash-merge commit message.** Keep it clean,
  details-only, no boilerplate. Read `.github/pull_request_template.md`; it says
  to replace/delete the template text and to **put testing links in a PR
  comment, not the description**.
- **Branch name:** `SERVER-XXXXX-short-kebab-description`.
- Community contributors must have signed MongoDB's contributor agreement before
  a PR can be merged — mention it once if relevant; it's not blocking for opening.

## Workflow

1. **Preflight.** Confirm remotes with `git remote -v` (`origin` = the user's
   fork, `upstream` = `mongodb/mongo`). Ensure a clean tree. Work on a branch cut
   from an up-to-date `master`. Confirm `gh auth status` is the fork account.

2. **JIRA ticket — the user files it, you cannot.** jira.mongodb.org needs the
   user's MongoDB account; you have no credentials for it.
   - First check whether a suitable ticket already exists (ask the user / web
     search) so you don't duplicate.
   - If none, draft the ticket text (Summary + Description) for the user to file:
     - **Project:** `Core Server` (key **SERVER**).
     - **Issue Type:** community/external accounts are usually limited to
       **Bug** — that is expected and fine; triage re-labels as needed. Frame the
       summary/description so "Bug" reads sensibly (e.g. lead with the
       user-visible symptom). Employees get the full type menu (Improvement/Task).
   - Offer to copy the description to the clipboard (`wl-copy`, else `xclip
     -selection clipboard`, else `xsel --clipboard --input`).
   - Wait for the user to return the real `SERVER-xxxxx` number before committing.

3. **Commit.** Message = `SERVER-XXXXX <summary>`, no AI trailer. Branch first if
   on `master`. Commit and push to the **fork** (`origin`), never `upstream`;
   never force-push/`--amend` already-pushed commits unless asked.

4. **Title.** Same as the commit subject: `SERVER-XXXXX <summary>`.

5. **Description.** Write the real change details from the actual diff: what
   changed, why, whether it's user-facing (a changed log/error/assert message IS
   user-facing — say so), and behavioral/test impact. End with a
   `Jira: https://jira.mongodb.org/browse/SERVER-XXXXX` line. No template
   boilerplate, no AI line. **No hard line-wrapping** — each paragraph is one
   flowing line; let it wrap on its own, with blank lines only between paragraphs.

6. **Security check** (`.github/copilot-instructions.md`): `master` syncs to the
   public repo. If the change looks like a security/CVE fix (auth bypass,
   injection, OOB access, trust-boundary hardening, audit attribution, etc.),
   flag disclosure-timing with the user before opening anything.

7. **Open it.** `gh pr create --repo mongodb/mongo --base master --head
   <fork-owner>:<branch> --title '<title>' --body-file <file>`.

8. **Testing links.** Post them as a **PR comment** (`gh pr comment`), not in the
   body — per the template.

9. **Approval.** Get explicit user approval before each external action —
   pushing, opening the PR. Show the drafted title/body first.

## Final message

- The JIRA link (id) used.
- The PR URL.
- One-line summary of what shipped and its user-facing/test impact.
