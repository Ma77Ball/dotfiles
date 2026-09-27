---
name: review-pr
description: Review one or more GitHub PRs and leave inline comments as a PENDING (unsubmitted) review. Use when asked to "review a PR", "review PR #N", "review all the X PRs", "leave comments on", or "suggest fixes on" a pull request. Emphasizes click-to-commit GitHub suggestion blocks, finds correctness and logic bugs plus quality issues, and explains each finding concisely with an actionable fix. Never submits the review.
version: 1.0.0
---

# Review a PR

Goal: leave high-signal inline comments on a PR, each with a concrete fix, and prefer click-to-commit `suggestion` blocks so the author can apply them in one click. Always leave the review **PENDING** so the human reads every comment before submitting.

**Keep every review very simple.** Favor a small number of clear comments over a thorough sweep. Each comment is short: one or two plain sentences, then the fix. Whenever the fix is an in-place edit, express it as a `suggestion` block rather than describing it in prose, so the author applies it in one click. Prose-only comments are the exception, not the norm.

## Operating rules

- **Never submit.** Create a pending review (omit `event` in the API call). The author submits.
- **Always reach for a suggestion block first.** Wherever a finding maps to a contiguous, in-place edit, write it as a `suggestion` so the author commits it in one click. Fall back to a fenced code block or prose only when the fix spans multiple, non-adjacent regions or is a design change, and say why.
- **One finding per comment.** Anchor it to the exact line(s) the fix touches.
- **Keep it simple and short.** One or two plain sentences on the problem, then the fix (ideally the suggestion block). No restating the diff, no essays, no hedging.
- **Signal over volume.** Report only real correctness/logic bugs and concrete quality wins. Prefer a handful of solid comments over an exhaustive list. Skip nitpicks that don't change behavior or clarity. Do not pad to hit a count.
- **No em dashes** in any comment text (a hook blocks them on tool input). Use commas, colons, or hyphens.
- **Say what you did not verify.** If you reviewed statically and did not run it, note that at the end.

## Workflow

1. **Identify the PRs.** If asked for "all the X PRs," search by title and branch, and check the umbrella issue for the full sub-PR series and their states (merged PRs need no review). `gh pr list --search "<term>" --state open` and `gh issue view <umbrella>`.
2. **Get the real diff.** For fork PRs, fetch the head into a local ref so you can read whole files, not just the truncated diff:
   `gh pr view <n> --json headRepositoryOwner,headRepository,isCrossRepository,headRefOid,baseRefName`
   `git fetch https://github.com/<owner>/<repo>.git <headBranch>:pr<n>`
   For a stacked PR, diff against its parent branch (`git diff <parent>..pr<n>`) so you review only its incremental change, not the whole stack.
3. **Read for understanding first**, then hunt for issues (see checklist). Read full files for anything you comment on; the diff alone hides context.
4. **Draft findings.** For each: file, exact line(s), the problem, the fix (as a suggestion when possible).
5. **Post a pending review** via `gh api` (recipe below). Verify anchors. Tell the user it is pending and how to submit.

## What to look for

Correctness and logic (highest priority):
- Off-by-one, wrong operator, inverted condition, truncation (`zip` to shorter, slicing).
- Unreachable or dead branches; a method shipped ahead of any caller; a docstring that contradicts the code.
- Null / empty / NaN handling; default-value fallbacks that differ between two code paths.
- Hardcoded values that should be inputs (e.g. an empty list where user data is required), making a feature silently non-functional.
- Resource and timing issues: unbounded or very long synchronous waits/polls, missing timeouts, blocking the worker.
- Error handling: swallowed exceptions, leaking large/sensitive response bodies into output, inconsistent truncation between sibling paths.
- Security: injection into URLs/commands, secrets in logs or output, missing validation before a request is built.

Quality and reuse:
- Duplicated literals/maps/tables that will drift; lift to one shared constant.
- Coupled magic numbers across files (frontend vs backend) with no comment tying them together.
- Framework correctness (e.g. Angular standalone components belong in `imports`, not `declarations`; verify before flagging).

For each finding, confirm it in the code before commenting. Quote the exact branch/line you are relying on.

## Suggestion blocks (the emphasis)

A GitHub `suggestion` block replaces the exact source line range it is anchored to, and the author commits it in one click. Rules that make them apply cleanly:

- The block content must be the **full replacement source line(s)**, reproducing leading whitespace exactly. For generated/templated code (e.g. Python inside a Scala `pyb"""..."""` string with a `       |` margin), include that margin prefix verbatim, or the suggestion will not compile.
- **Single line:** anchor with `line` + `side: RIGHT`.
- **Multiple lines:** anchor with `start_line` + `start_side` + `line` + `side` (all `RIGHT` for added code). The block may change the line count.
- Capture exact whitespace first: `git show pr<n>:<path> | sed -n '<a>,<b>p' | cat -A`.
- If a fix needs edits in two or more non-adjacent spots (e.g. define a constant + replace two uses), a single suggestion cannot express it. Use a normal code block and say it is a manual two-spot change.

Suggestion body shape:

    One sentence on the problem, one on the fix.

    ```suggestion
    <exact replacement line(s), correct indentation/margin>
    ```

## Posting a pending review (recipe)

Build a JSON payload and POST it. Omitting `event` keeps it PENDING (visible only to the reviewer until they submit).

```bash
# 1. confirm you are the requested reviewer and there is no existing pending review
gh api user -q .login
gh api repos/<owner>/<repo>/pulls/<n>/reviews -q '.[]|select(.state=="PENDING")|.id'

# 2. head SHA the comments anchor to
gh pr view <n> --json headRefOid -q .headRefOid
```

Payload (`review.json`):

```json
{
  "commit_id": "<headRefOid>",
  "body": "Short overview. Note which comments are click-to-commit suggestions.",
  "comments": [
    { "path": "src/...", "line": 354, "side": "RIGHT",
      "body": "Problem. Fix:\n\n```suggestion\n<replacement>\n```" },
    { "path": "src/...", "start_line": 196, "start_side": "RIGHT", "line": 202, "side": "RIGHT",
      "body": "Problem. Suggested rewrite:\n\n```suggestion\n<line1>\n<line2>\n```" }
  ]
}
```

```bash
# 3. create (PENDING) and verify each anchor landed on the intended line
ID=$(gh api repos/<owner>/<repo>/pulls/<n>/reviews --method POST --input review.json -q .id)
gh api repos/<owner>/<repo>/pulls/<n>/reviews/$ID/comments \
  -q '.[] | "P\(.position): " + (.diff_hunk | split("\n") | last)'
```

Notes:
- For pending comments, the GET response shows `line`/`side` as `null`; the stored `position` echoes your target. For a fully-added file, diff position equals file line, so verify via the last line of `diff_hunk` (it is the commented line).
- To revise: `gh api .../reviews/$ID --method DELETE` then recreate. A pending review is not visible to others, so deleting loses nothing.
- One pending review per reviewer per PR. If one exists, edit/delete it first.

## Close-out

Keep the chat summary short. Tell the user: the review is PENDING, how many comments, and how many are one-click suggestions vs manual. State anything you did not run or verify.

**Always end with a clickable link to the PR** so the user can jump straight to it, on its own line as the last thing in the message. Get the canonical URL with `gh pr view <n> --repo <owner>/<repo> --json url -q .url` (or reuse the URL the user gave you). Point them to the **Files changed** tab, where the comments appear under "Pending" with a **Submit review** button. Example:

```
Review is pending with 2 comments (both one-click suggestions). Open it here to read and submit:
https://github.com/<owner>/<repo>/pull/<n>/files
```
