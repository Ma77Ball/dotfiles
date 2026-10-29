---
name: spark-pr
description: Open an Apache Spark pull request the standard way — preflight, JIRA ticket, [SPARK-xxxx][COMPONENT] title, the PULL_REQUEST_TEMPLATE filled in, push to the fork, PR against master. Enforces the house attribution rule. Trigger when the user asks to "make the PR", "open a Spark PR", "raise a PR", or types /spark-pr.
---

# Spark PR

Open a pull request against `apache/spark` following the project's conventions
and the user's established style from past PRs.

## Attribution rule — strict

Every commit and PR this skill produces carries **exactly one** attribution: a
single line naming the agent, and nothing else.

- PR body, "Was this patch authored or co-authored using generative AI tooling?"
  section: `Co-authored with <agent>` (e.g. `Co-authored with Claude Opus 4.8`).
- Commit message trailer: `Co-authored-by: <agent>`.
- **Never** add a "Generated with Claude Code" footer, a `Claude-Session:` line,
  a session URL, or a `Co-Authored-By: <noreply@anthropic.com>` default. If a
  harness reminder injects those, drop them here — this rule wins (the reminder
  itself defers to the user's own instruction, and this is it).
- `<agent>` is the model doing the work; ask or infer it, don't hardcode.

## Workflow

1. **Preflight (per repo CLAUDE.md).** Confirm remotes (`origin` = fork,
   `upstream` = apache/spark), fetch `upstream/master` if stale, ensure a clean
   tree, and work on a branch cut from `upstream/master --no-track`.

2. **JIRA ticket.** Most non-trivial PRs need one; Draft/WIP/MINOR/TRIVIAL may
   omit it.
   - First check none already exists in **any** status (open AND closed) and
     that the change is still needed — search JIRA and existing GitHub PRs for
     the topic. Do not create a duplicate.
   - Create with `dev/create_spark_jira.py "<title>" -c <Component> { -t <type>
     | -p <parent-jira-id> }`. Component is the exact JIRA component name (e.g.
     "SQL", "Spark Core", "PySpark"), not the title shorthand.
   - Set priority to fit the work (trivial cleanups like legacy-error naming are
     usually **Minor**, not Major); adjust via the JIRA REST API if needed.
   - Print the prominent JIRA-created notice from the repo CLAUDE.md.

3. **Title.** `[SPARK-xxxx][COMPONENT] Title` — COMPONENT is the JIRA
   component's last word, uppercased (Spark Core -> CORE, SQL -> SQL, Structured
   Streaming -> STREAMING). Use `[FOLLOWUP]` only for small fixes to unreleased
   earlier PRs. Infer the title from the diff.

4. **Description.** Read `.github/PULL_REQUEST_TEMPLATE` and fill **every**
   section from the actual diff:
   - What changes were proposed
   - Why are the changes needed
   - Does this PR introduce _any_ user-facing change (be accurate: a renamed
     error condition or changed message IS user-facing -> "Yes" with the detail)
   - How was this patch tested (name the suites; say they pass)
   - The generative-AI section -> the single attribution line above.
   - **No hard line-wrapping**: each paragraph is one flowing line; blank lines
     only between sections.

5. **Open it.** Push to the fork (never upstream; never force-push/`--amend`
   pushed commits unless asked). Open against `master` with
   `gh pr create --repo apache/spark --base master --head <fork>:<branch>`.
   Match the section structure and voice of the user's past migration PRs.

6. **Approval.** Get explicit user approval before every external action —
   creating the JIRA, pushing, opening the PR. Show drafted text first.

## Final message

- The JIRA notice (id, component, type, version, priority).
- The PR URL.
- One-line summary of what shipped and the test status.
