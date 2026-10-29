---
name: SparkPR
description: For an Apache Spark change, create the JIRA ticket and write the PR description in the project's standard format and voice. Leaves the generative-AI section blank for the user. Never commits or pushes. Trigger when the user says "SparkPR", "prep the JIRA and PR", "write the PR description", or asks to raise/prepare a Spark PR.
---

# SparkPR — Create the JIRA ticket and PR description

Turn a set of local changes into (1) a JIRA ticket and (2) a filled-in PR
description, both in the standard Apache Spark format and voice.

## Hard rules (do not violate)

- **NEVER commit. NEVER push. NEVER open the PR.** The user does all of that
  themselves. This skill only creates the JIRA ticket and produces the PR
  description text. Say so plainly at the end.
- **Leave the generative-AI section EMPTY.** Under
  "Was this patch authored or co-authored using generative AI tooling?" write
  nothing but a placeholder for the user (e.g. `<!-- fill in -->`). Do not write
  "No", do not name a tool. The user fills this in.
- **Get user approval before creating the JIRA ticket.** Creating a ticket is an
  external action. Show the exact title/component/type first and wait for a yes.

## Step 1 — Understand the change

Read the actual diff, do not guess from the branch name:

- `git diff <upstream>/master...HEAD` (or `git diff` for uncommitted work) to see
  every changed file.
- Read enough surrounding code to describe, in one plain sentence, **what the
  code does from a high level** and who is affected. Lead with caller-visible
  behavior, not internal mechanics.

If the change is unclear or spans multiple unrelated things, ask the user to
confirm scope before writing anything.

## Step 2 — Decide the ticket fields

- **Title** (no JIRA id / tag yet): a short imperative summary of the change,
  matching how existing Spark PR titles read (e.g. "Assign a name to the error
  condition _LEGACY_ERROR_TEMP_1052").
- **Component** (`-c`): the exact JIRA component name, not the tag shorthand
  (e.g. "SQL", "Spark Core", "PySpark", "Connect"). Run
  `python3 dev/create_spark_jira.py --list-components` if unsure.
- **Issue type** (`-t`) OR **parent** (`-p`): if the change belongs to an
  umbrella ticket the user names (e.g. a subtask of SPARK-37935), use `-p`
  instead of `-t`. Otherwise pick the type: Bug, Improvement, New Feature, Test,
  Documentation, or Dependency upgrade.
- **Component tag** for the PR title = last word of the component, uppercased
  (`Project Infra` -> `[INFRA]`, `Spark Core` -> `[CORE]`, `SQL` -> `[SQL]`).

Present these to the user and wait for approval (per the hard rule).

## Step 3 — Create the JIRA ticket

After approval, run:

    python3 dev/create_spark_jira.py "<title>" -c <component> { -t <type> | -p <parent> }

Then print the prominent notice so the user cannot miss it:

    ============================================================
    JIRA ticket created: SPARK-XXXXX
    https://issues.apache.org/jira/browse/SPARK-XXXXX

    Title:               <title>
    Component(s):        <component>
    Issue type:          <type>
    Affected version(s): <version>
    Priority:            <priority>

    Please review and adjust these fields if needed.
    ============================================================

MINOR/TRIVIAL/WIP/draft changes may skip the ticket; if the user says it is one
of those, don't create a ticket and use no JIRA id in the title.

## Step 4 — Write the PR description

Read `.github/PULL_REQUEST_TEMPLATE` and fill **every** section. Match the voice
of real Spark PRs: plain declarative sentences, start with "This PR ...", explain
the high-level intent first and the mechanism second, and keep it easy to follow
for a reviewer who has not seen the code.

**PR title:** `[SPARK-XXXXX][TAG] <title>` (omit the id for MINOR/TRIVIAL/WIP).

Fill the four content sections:

- **### What changes were proposed in this pull request?** Open with one
  high-level sentence on what the change does and why it exists. Then the
  concrete specifics: which files/methods/conditions changed, named plainly.
  Reference an umbrella JIRA (e.g. SPARK-37935) if the change is part of one.
- **### Why are the changes needed?** The motivation, not a restatement of the
  diff. Link the broader effort or bug if relevant.
- **### Does this PR introduce _any_ user-facing change?** "Yes" or "No". If yes,
  show **Before** and **After** with concrete output/examples (error messages,
  console output, API shape). State whether it is relative to a released version
  or only unreleased branches.
- **### How was this patch tested?** Name the test(s) added/updated and what they
  assert (e.g. a `checkError` test in some suite), or explain why no test was
  added.

- **### Was this patch authored or co-authored using generative AI tooling?**
  Leave EMPTY for the user (placeholder only). Do not fill this in.

### Voice checklist (how Spark contributors write)

- High level first, details second. A reviewer should get the gist from the
  first sentence.
- Plain and specific. Name the exact class/method/condition; skip adjectives
  and hedging.
- No marketing language, no "we are excited to", no essays.
- Before/After blocks for any user-facing change, using real output.
- ASCII only; keep lines readable. No em dashes if a hook blocks them.

## Step 5 — Deliver, do not push

Output the JIRA notice (if a ticket was created) and the full PR description as a
copy-pasteable block (the four sections plus the empty AI section). End with an
explicit reminder:

> I did NOT commit, push, or open the PR. The AI-tooling section is left blank
> for you to fill in. Commit and push yourself, then paste this description when
> you open the PR.
