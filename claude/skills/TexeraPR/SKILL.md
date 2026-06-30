# Raise a PR — Step-by-Step

Follow these steps **in order**. Pause for user input at the checkpoints (marked ⏸).

---

## Step 1 — Explain the issue and proposed solution (high level)

Keep it short. Three labelled lines, plain language, no hedging. Lead with what a caller sees, not the internal mechanism.

1. **Symptom** — what a caller observes go wrong. One sentence.
2. **Mechanism** — the offending line as `file::method`, plus one sentence saying why it misbehaves. Quote 2–5 lines of code only if prose can't carry it.
3. **Fix** — what you'll change, one sentence. Add a tiny code sketch only if it clarifies.

Then one line on tests, and **tests are mandatory** for any change that affects behavior: name which existing test covers the area and state which test you will **add, update, or flip**. There is exactly one exception, a **genuinely non-functional** change (docs, pure CI/workflow YAML, config-only, formatting). If you claim that exception, say so explicitly in this line and name why no behavior changed; do not silently omit the tests line.

End with:

> ⏸ Any thoughts on the design, or alternative approaches I should consider before I start?

Wait for the user's response.

### Worked example

> **Symptom:** `generateChannelConfigs` with `OneToOnePartition` silently drops senders when the two worker lists differ in length, e.g. 3 senders + 2 receivers returns 2 channels.
>
> **Mechanism:** `ChannelConfig.scala::generateChannelConfigs` uses `fromWorkerIds.zip(toWorkerIds)`, which truncates to the shorter side. The sibling `SinglePartition` arm guards with `assert`; only `OneToOne` is silent.
>
> **Fix:** add `assert(fromWorkerIds.size == toWorkerIds.size, "...")` at the top of the `OneToOne` arm. `assert` over `require` to mirror the sibling arm.
>
> **Tests:** `ChannelConfigSpec` pins the truncation as "current behavior" with a comment inviting this tightening. I'll flip it to `assertThrows`.
>
> ⏸ Any thoughts on the design, or alternative approaches I should consider before I start?

---

## Step 2 — Implement the solution

Make the code changes. Keep scope tight, no drive-by refactors, no unrelated cleanup. Stick to what Step 1 described unless the user expanded scope.

**Write the tests in this same step, alongside the code, not after review.** The test you committed to in Step 1 (added, updated, or flipped) must exist and pass before you move on. A behavioral change that reaches Step 7 with no test is incomplete: do not proceed to the commit/PR text until the test is written and green, unless the explicit non-functional exception from Step 1 applies. Run the test locally and confirm it passes (if the environment cannot run it, say so and point to where it runs, per Step 7c).

**Code comments: short or none, and only about the code.** A comment explains what the code *does* or *why*, never what the PR changes. Do not write "replacing X", "previously this used Y", "added to fix Z" — that belongs in the PR description, not the source. Keep any comment to one short line; prefer no comment when the code is self-evident.

While working, give brief one-line updates at meaningful moments (found the bug, changing direction, hit a blocker). Don't narrate every tool call.

---

## Step 3 — Explain problem + solution together

Once the implementation is done, write a **single explanation** that ties the problem and the fix together:

- **What was wrong** (one or two sentences).
- **What the change does** to fix it.
- **Why this approach** over alternatives (the key tradeoff).

Keep it simple but include the load-bearing details. Use an ASCII diagram **only if** control flow, data flow, or before/after state would be unclear without one.

Example diagram (only use when actually helpful):

```
before:                          after:
  cursor ──▶ [a, b, c]             cursor ──▶ [a, b, c]
              ▲ stuck here                     ▲ reset to start
                                               on each iteration
```

---

## Step 4 — Check in with the user

> ⏸ Anything else to add or change before I prep the commit and PR?

Wait. Address any follow-ups. **Do not proceed to Step 5 until the user says it's ready.**

---

## Step 5 — Run the formatter

Before producing the commit/PR text, run the formatter for any languages you touched:

- **Scala edits** (`*.scala`, `*.sbt`): run `sbt scalafmtAll` from the repo root.
- **Frontend edits** (`*.ts`, `*.js`, `*.html`, `*.scss`, `*.less`, `*.json` under `frontend/`): run `yarn format:fix` from `frontend/`.
- **agent-service edits** (`*.ts`, `*.tsx`, `*.json` under `agent-service/src/`): run `bun run format` from `agent-service/` (verify with `bun run format:check`).
- **Python edits in amber** (`*.py` under `amber/src/main/python/` or `amber/src/test/python/`): run `ruff format src/main/python src/test/python` from `amber/`, then verify with `ruff check src/main/python src/test/python && ruff format --check src/main/python src/test/python`. CI runs the `--check` form and fails on any unformatted file.
- Run each formatter that applies if you touched multiple areas.

If the formatter rewrites files, mention it in one line ("formatter touched N files"). If it errors, fix the underlying issue rather than skipping.

---

## Step 6 - Open the tracking issue (before the PR)

The PR's `Closes: #xxxx` needs a real issue number, and the **template-compliance CI** (`.github/workflows/template-compliance-warning.yml`) keys off the issue's **GitHub Type**: it reads `issue.type.name` to pick which template's required fields to check, and flags any issue with **no recognized type** as "not using a template." So the issue must exist **and carry the right Type** before the PR is opened.

### 6a. Pick the template and its required fields

Match the work to one of the three templates in `.github/ISSUE_TEMPLATE/`. Keep each template's exact `### ` headings and fill every required field with real content (the CI checks each heading is present and non-empty):

| Work | Type | Required headings (present + non-empty) |
|---|---|---|
| Bug fix | `Bug` | `What happened?`, `How to reproduce?`, `Version/Branch` |
| New feature / improvement | `Feature` | `Feature Summary`, `Proposed Solution or Design` |
| Refactor, perf, CI, tests, docs, cleanup | `Task` | `Task Summary` (the `Task Type` checkboxes are optional) |

A perf refactor or test/coverage task is a **Task**, not a Feature.

### 6b. Show the proposed issue, get approval (⏸)

Opening an issue is outward-facing on the public Apache repo. Show the user the **Type**, **title**, and **body** (filled to the template above) and wait for approval before creating it.

### 6c. Create the issue with the Type set at creation

Create it so the Type is present on the `opened` event, so the compliance check passes immediately (a later type-only change does **not** re-trigger the workflow, so the warning would linger). `gh issue create` has no `--type` flag, so use the GraphQL `createIssue` mutation, which accepts `issueTypeId`:

```bash
# repositoryId and type IDs are stable; re-verify with this query if a call fails:
gh api graphql -f query='{repository(owner:"apache",name:"texera"){
  id  issueTypes(first:10){nodes{id name}} }}'
#   repositoryId  MDEwOlJlcG9zaXRvcnk1Mzk3NjkxMA==
#   Task          IT_kwDNuP_OAAFtgA
#   Bug           IT_kwDNuP_OAAFtgg
#   Feature       IT_kwDNuP_OAAFthg

gh api graphql -f query='
mutation($repo:ID!,$title:String!,$body:String!,$type:ID!){
  createIssue(input:{repositoryId:$repo,title:$title,body:$body,issueTypeId:$type}){
    issue{ number url issueType{name} }
  }
}' -f repo="MDEwOlJlcG9zaXRvcnk1Mzk3NjkxMA==" -f type="IT_kwDNuP_OAAFtgA" \
   -f title="<issue title>" -f body="$(cat <<'EOF'
### Task Summary
<one or two sentences describing the single step>
### Task Type
- [x] Performance
EOF
)"
```

The returned `number` is the `Closes: #xxxx` for the PR body in Step 7.

### Setting the Type on an issue that already exists

If the issue was opened **without** a type (pre-existing, or the web form's type left unset), set it with the **`updateIssue`** mutation. A `CONTRIBUTOR` (non-committer) is allowed to run this as an author edit:

```bash
ID=$(gh issue view <num> --repo apache/texera --json id -q .id)
gh api graphql -f query='
mutation($id:ID!,$type:ID!){
  updateIssue(input:{id:$id,issueTypeId:$type}){ issue{ number issueType{name} } }
}' -f id="$ID" -f type="IT_kwDNuP_OAAFtgA"
```

Two methods that look correct but **silently fail for a non-committer**, so do not rely on them:
- `updateIssueIssueType` (the dedicated mutation): returns `FORBIDDEN` (it is triage-gated).
- REST `PATCH /repos/apache/texera/issues/<n>` with `type=Task`: returns `200 OK` but drops the field; the type stays `null`.

---

## Step 7 - Produce the commit message and PR form

Output **all three** as plain text the user can copy-paste. Do **not** run `git commit` or `gh pr create` - the user runs those.

**Punctuation rule for PR title and PR body:** do **not** use em-dashes (`—`) or en-dashes (`–`). Rewrite with a comma, colon, period, parentheses, or a new sentence instead. This applies to 7b (PR title) and 7c (PR body) only — the commit message in 7a and your in-chat explanations are unaffected.

### 7a. Commit message (one line)

Format: `<type>(<scope>): <short imperative summary>`

Examples:
- `fix(amber): reset iteration cursor on retry`
- `refactor(frontend): extract download dialog into reusable component`

### 7b. PR title (one line, under 70 chars)

**The PR title MUST be a Conventional Commit** — `.github/workflows/lint-pr.yml` runs `action-semantic-pull-request`, and a non-conforming title **fails CI and blocks merge**. Keep the `<type>(<scope>): <summary>` form (do **not** strip the type/scope prefix — the title is usually identical to the commit message in 7a).

Format: `<type>(<scope>): <summary>` — the `(<scope>)` is optional, the `<type>:` is **required**.

Allowed types (the action's defaults, lowercase): `feat`, `fix`, `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`, `revert`.

Examples of valid titles:
- `fix(frontend): drop stale attribute references on schema change`
- `refactor(workflow-core): make JSONToMap iterative`
- `ci: rename python job/flag/label to pyamber`
- `test: add spec for UserDatasetComponent`

Common scopes seen in the repo: `frontend`, `workflow-core`, `workflow-operator`, `config-service`, `dataset`, `dashboard`, `amber`, `pyamber`, `ci`, `k8s`, `asf`. Pick the area you touched; omit the scope only if the change is genuinely cross-cutting.

### 7c. PR body (fill out the form)

**CRITICAL — NO BLANK LINES.** The PR body MUST be a single tight block with **zero blank lines anywhere**. Not between sections, not between header and content, not at the start, not at the end. Every line in the body must contain text. The user is pasting this directly into a GitHub form and any blank line bloats the form and forces them to hand-edit it.

Concretely:
- One newline between a `### Header` and its content.
- One newline between the end of one section's content and the next `### Header`.
- **Never** two newlines in a row.
- No blank line before the first `### Header` or after the last line.
- Bullet lists are allowed and **preferred** for the "What changes were proposed" and "How was this PR tested?" sections — they read more easily than prose walls. Use `- ` bullets separated by **single** newlines (no blank lines between bullets). The other two sections stay single-line.

Before you output the body, scan it character-by-character and confirm there is no `\n\n` anywhere in it. If there is, rewrite it. This rule overrides any markdown-formatting instinct to "breathe" the document.

```markdown
### What changes were proposed in this PR?
- <bullet 1: what changed and what it accomplishes>
- <bullet 2: another distinct change>
- <bullet 3: another distinct change, if applicable>
### Any related issues, documentation, discussions?
Closes: #xxxx
### How was this PR tested?
- <bullet 1: the exact command a reviewer runs to exercise this change, e.g. `sbt "WorkflowOperator/testOnly *ReservoirSamplingOpExecSpec"`>
- <bullet 2: a concrete manual step with the expected observable result, e.g. "drag a Reservoir Sampling op onto a workflow, run it, confirm no null rows downstream">
- <bullet 3: what to look for / how to know it passed>
### Was this PR authored or co-authored using generative AI tooling?
Co-authored with Claude Opus 4.7 in compliance with ASF
```

These four `### ` headings mirror `.github/PULL_REQUEST_TEMPLATE` verbatim, keep them exact. The template-compliance CI requires three of them to be present and non-empty: **What changes were proposed in this PR?**, **How was this PR tested?**, and **Was this PR authored or co-authored using generative AI tooling?** (a missing heading or an empty section, including GitHub's `_No response_` placeholder, gets a non-blocking warning comment).

If a section is genuinely one short fact (a single sentence change description, a single test step), a single line is fine, don't pad with bullets just to hit the template.

**Write this section as actionable steps a reviewer can follow, not a log of what you did.** Each bullet should be a command they can copy-paste or a manual step they can reproduce, paired with the expected result so they know what "passing" looks like. Prefer "run X, expect Y" over "I ran X and it passed". Give the runnable test command (e.g. `sbt "WorkflowOperator/testOnly *SomeSpec"`, `yarn test foo.spec.ts`) rather than just naming the spec file. If you could not run something locally (environment limitation, CI-only check), say so explicitly and point the reviewer to where it does run, so they do not assume coverage that was not exercised.
**Do not list formatter runs under "How was this PR tested?"** Running the formatter (Step 5) is required, but it is not a test — never write "ran `yarn format:fix`", "ran `ruff format`", "ran `scalafmtAll`", or similar in the testing section. That section is for behavior verification only (specs, manual checks, test commands).

Use the number of the issue opened in Step 6 (`Closes: #1234`). Only in the rare case there is genuinely no tracking issue, replace `Closes: #xxxx` with `N/A`.

---

## Rules

- **Never** run `git commit` or `git push` unless the user explicitly says so.
- **Never** skip Step 1 — even for "obvious" fixes, the design check-in catches mismatched assumptions early.
- **Never** skip Step 5 — formatter runs are required for any Scala or frontend edits before the commit/PR text is produced.
- **Never** open a PR that changes behavior without a test that exercises that behavior. Tests are written in Step 2, alongside the code, and must pass before the commit/PR text in Step 7. The only exception is a genuinely non-functional change (docs, pure CI/workflow YAML, config-only, formatting), and that exception must be stated explicitly in Step 1, never assumed silently.
- **Never** expand scope beyond what was agreed in Step 1 without checking back in.
- **Keep code comments short or none, and only about the code** — never narrate the change ("replacing", "previously", "added to fix") in source; that goes in the PR description.
- **Never** put a blank line inside the PR body in Step 7c. Re-read the body before outputting it and confirm no `\n\n` exists.
- **Always open the tracking issue (Step 6) before the PR**, and set its GitHub Type at creation. An issue with no recognized type is flagged by the compliance CI as "not using a template."
- **Match the issue to the right template and Type**: Bug, Feature, or Task. A perf refactor or test/coverage task is a **Task**.
- **Setting an issue Type as a non-committer uses the `updateIssue` (or `createIssue`) mutation with `issueTypeId`**, never `updateIssueIssueType` (FORBIDDEN) or the REST `type=` field (silently dropped).
- Keep each step's output **brief**. The user is reading every word; don't pad.

