---
name: fix-pr
description: Make a PR merge-ready — fix every reviewer suggestion (code, tests, and PR metadata like the description and title), and draft short action-only replies. Trigger when the user asks to "fix the suggestions", "fix PR comments", "address the review", "fix the PR", or types /fix-pr.
---

# Fix PR

Make the current branch's PR merge-ready. Resolve everything a reviewer raised,
not just code: also the PR description, title, and any other metadata they
flagged. Cover each code fix with a test and draft short action-only replies.

## Workflow

1. **Gather the full picture.**
   - `gh pr view --json number,title,url,state,body` for the current branch.
   - `gh api repos/{owner}/{repo}/pulls/{n}/comments --paginate` for inline
     comments; `gh api .../pulls/{n}/reviews` for review-level bodies.
   - Read review bodies fully, not just inline threads. Reviewers often raise
     non-code items there ("PR metadata suggestions", "correct the description",
     "title should be ...", "add a test", "update the JIRA"). These count.
   - Skip comments already resolved, outdated, or replied to.
   - Check the working tree first (`git diff`): a fix may already be started;
     verify it is correct and complete before treating the item as open.
   - Enumerate CI status too, not just human review. A failing CI run is an item
     to fix like any comment (see step 5).

2. **Understand before editing.** For each item, read the file and enough
   surrounding code (base classes, callers, siblings, registrations) to confirm
   what the reviewer wants and that the fix is safe. If an item is wrong or
   ambiguous, do NOT guess: flag it and draft a reply that pushes back or asks
   for clarification.

3. **Fix the code.** Smallest change that fully addresses the comment. Match
   surrounding style. Grep for other call sites and dangling references so the
   fix is complete across the codebase, not just at the commented line.

4. **Add or update tests.** Update tests that pin the old behavior; add a test
   for changed lines that have none, in the module's existing suite following
   its naming and structure. Run the affected suites and report results
   honestly. If the build/test is expensive or the user may have more changes,
   ASK before running; state exactly which suites are affected and any blocker.

5. **Fix CI failures.** A red PR is not merge-ready even with no human comments.
   Enumerate the *complete* failure set, don't assume one cause — a PR can fail
   tests, linters, and the build at once, surfaced through different check runs.
   - Follow the repo's own CI-investigation guide if it has one (e.g. Spark's
     "Investigating PR CI Failures" in CLAUDE.md): get the fork owner + head
     SHA, list every failing check run on that commit, then drill in by kind —
     test jobs via failure annotations, non-test jobs (lint/license/build/MiMa/
     docs) via the failed step's log. A green "Report test results" does NOT
     mean CI passed; those other checks are separate.
   - Reproduce each failure locally where feasible, fix it at the source (code,
     test, lint, or generated file), and re-run the relevant check locally.
   - After pushing fixes (step 7), the same checks re-run; report the new status
     rather than assuming green.

6. **Fix PR metadata — the part beyond the code.** Handle anything about the PR
   itself that a reviewer raised or that the changes now make wrong:
   - **Description**: correct statements that no longer match the diff, fill in
     template sections, add missing context. Read the repo's PR template if
     there is one and keep the section structure. Regenerate the "what changed"
     summary from the actual diff, not the old text.
   - **Title**: fix it if the reviewer asked or if it misstates the change.
     Follow the repo's title convention (e.g. Spark's
     `[SPARK-xxxx][COMPONENT] Title`); infer the component/scope from the diff.
   - **Other**: JIRA/issue fields, labels, linked tickets, changelog entries —
     whatever the review flagged as part of landing this PR.
   - Draft the new description/title text and SHOW it. Apply it with
     `gh pr edit` ONLY after the user approves (see step 8).
   - **No hard line-wrapping.** Write each paragraph as one flowing line with
     no manual newlines inside it; let it wrap on its own. Use blank lines only
     to separate sections/paragraphs. This applies to the description body and
     to every drafted reply.

7. **Replies: action-only, one sentence.** This is the default style for every
   reply; keep to it unless the user asks for something else.
   - **One sentence per comment.** Two only when the fix genuinely has two
     parts; never more.
   - Open with the change itself in past tense ("Moved ...", "Removed ...",
     "Corrected ..."). No "Fixed"/"Done"/"Good catch"/"Thanks" openers, no
     pleasantries, no acknowledgment: just the action and its effect.
   - Write each reply as one flowing line, no manual newlines inside it.
   - Plain language. No class-name soup or internal shorthand beyond the
     identifiers the reviewer used.
   - One comment = one reply. "ditto" comments share one reply.
   - DRAFTS ONLY by default: show them for the user to post. Post inline (reply
     to each comment via `gh api
     repos/{owner}/{repo}/pulls/{n}/comments/{id}/replies -f body=...`) only
     when the user explicitly asks; never resolve threads unless asked.

8. **Nothing external without explicit approval.** Leave code changes in the
   working tree. Do not commit, push, post replies, edit the PR
   description/title on GitHub, or touch the tracker until the user says so.
   Show every drafted change first; apply only what they approve.

## Final message format

- One-line TLDR of the action items done.
- Code: per comment, what changed and where (`file:line`).
- CI: each failing check found, its cause, and the fix (or "CI green").
- Metadata: the drafted new title / description text (or "no change needed").
- Test results, or the exact blocker / the suites awaiting a go-ahead.
- The draft replies, quoted, ready to copy-paste.

## Reply style examples

Good (one sentence, opens with the change, action-only):
> Moved the OTLP host-port publishing into `docker-compose.override.yml`, auto-loaded for local dev; the base compose no longer publishes them.
> Corrected the README: the agent samples stack traces and does not read application-level trace ids, so profiles cannot be joined to traces by trace_id.
> Non-integer bucket count now returns `INVALID_PARAMETER_VALUE.INTEGER` (SQLSTATE 22023); `INVALID_BUCKET_COUNT` is flat again for out-of-range only.

Avoid:
> Thanks, good catch! Fixed by moving it to `INVALID_PARAMETER_VALUE.INTEGER`.
> Done. Let me know if you'd like anything else!
