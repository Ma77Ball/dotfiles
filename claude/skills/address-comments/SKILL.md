---
name: address-comments
description: Fix PR review comments, add test coverage for the changed code, and draft short plain-language replies (1-2 sentences each). Trigger when the user asks to "address comments", "fix comments", "respond to review", or similar on a PR branch.
---

# Address PR Review Comments

Fix every reviewer comment on the current branch's PR, back each fix with test
coverage, and produce short draft replies the user can post themselves.

## Workflow

1. **Find the PR and comments.**
   - `gh pr view --json number,title,url,state` for the current branch.
   - `gh api repos/{owner}/{repo}/pulls/{n}/comments --paginate` for inline
     comments; `gh api .../pulls/{n}/reviews` for review-level bodies.
   - Skip comments that are already resolved, outdated, or replied to.

2. **Understand before editing.** For each comment, read the file and enough
   surrounding code (base classes, callers, registrations) to confirm what the
   reviewer is asking and that the fix is actually safe. If a comment is wrong
   or ambiguous, do NOT guess: flag it in the summary with a suggested reply
   that politely pushes back or asks for clarification.

3. **Fix the code.** Smallest change that fully addresses the comment. Match
   surrounding style. "ditto" comments mean the same fix as the previous
   comment, applied at that location.

4. **Add or update tests for coverage.**
   - If an existing test pins the old behavior, update it to pin the new one.
   - If the changed lines/branches have no test, add one in the module's
     existing test suite (follow its naming and structure). Cover the new
     behavior directly, not just "it compiles".
   - Run the affected test suite(s) and report results honestly. If the build
     is broken for environmental reasons, say exactly why and what the user
     must run to unblock it.

5. **Draft replies, following these rules:**
   - **1-2 sentences per comment, maximum.**
   - Plain language a non-expert can understand. No jargon, no class-name
     soup, no internal shorthand.
   - Lead with what was done: "Fixed ..." / "Done ..." / "Good catch ...".
   - One comment = one reply. Identical comments ("ditto") can share one reply.
   - DRAFTS ONLY: show them in the final message for the user to post.
     Never post replies or resolve threads unless the user explicitly asks.

6. **Do not commit or push unless the user asks.** Leave changes in the
   working tree and summarize what changed.

## Final message format

- One-line outcome ("Addressed N comments, added M tests, suite passes").
- Per comment: what was changed and where (file:line).
- Test results (or the exact blocker).
- The draft replies, quoted, ready to copy-paste.
