---
name: review-big-pr
description: Review a large or wide-ranging GitHub PR (many files, multiple modules, or a stacked series) and leave a structured, severity-tiered review as a PENDING (unsubmitted) review with inline comments. Use when asked to "review a big PR", "review this large PR", "review PR #N" where the diff is large, or when a PR spans many files/modules. Triages the diff, fans out reading across modules, reviews architecture first, then posts a prose summary plus a P0-P3 findings table (Blocking/Non-blocking/Nit) and click-to-commit inline suggestions. Tracks findings across re-reviews via a hidden marker. Never submits the review.
version: 2.0.0
---

# Review a big PR

This is the large-PR variant of `review-pr`, producing a **structured, severity-tiered review** modeled on the format experienced Apache Spark committers use (a readable prose summary + a P0-P3 findings table with Blocking/Non-blocking/Nit tiers + a Verification section), while keeping the review-pr contract intact.

The hard contract is unchanged from `review-pr` -- **create a PENDING review on GitHub, never submit it, prefer click-to-commit `suggestion` blocks, one finding per inline comment, signal over volume**. Read `../review-pr/SKILL.md` for the shared mechanics: suggestion-block anchoring/whitespace rules, the pending-review `gh api` recipe, anchor verification, and the close-out. This skill adds (1) the large-PR triage/fan-out workflow and (2) the structured review-body format below. Do not duplicate the review-pr machinery here; reuse it.

**Deliverable:** a PENDING review that actually exists on GitHub (the `POST .../reviews` call with `event` omitted), whose *body* is the structured report and whose *inline comments* carry the per-line fixes (as suggestions where possible), visible to the user under "Pending" in the Files changed tab. Creating it is required; submitting it is forbidden. If the create call is blocked, say so and surface the exact command.

## HARD GUARDRAIL: create the PENDING review, but never submit or finalize without approval (highest priority)

This overrides every other instruction here.

- **Creating the PENDING review IS the deliverable -- do it.** Call `POST .../reviews` with the `event` field omitted so it lands as PENDING. This does not need separate approval; it is the whole point of the skill. Do not stop at a local-only draft, and do not gate the pending creation behind an extra approval step. If the create call is blocked or fails, say so plainly and surface the exact command so the user can create it.
- **NEVER submit or finalize the review.** Do not pass `event` (`APPROVE`/`REQUEST_CHANGES`/`COMMENT`) to `POST .../reviews`, and never `PUT .../reviews/<id>/events`. The user reads the pending comments and submits (or discards) them.
- **No other GitHub writes without the user's explicit approval in the session.** Beyond creating this one pending review, do not submit/finalize it, post standalone issue/PR comments, post review-comment replies, or add reactions unless the user explicitly says so. A request to "review the PR" authorizes creating the pending review and nothing further.
- If ever unsure whether an action submits/finalizes or writes beyond the single pending review, treat it as forbidden and ask first.
- Read-only calls (`gh pr view`, `gh api` GETs, `git fetch`/`git diff`/`git grep`) need no approval.

One pending review per reviewer per PR: if one already exists, inspect it and, if it is a superseded draft of your own, delete it (`DELETE .../reviews/<id>`, which loses nothing since it is not visible to others) and recreate. Tell the user you replaced it.

## What makes a PR "big" (and why the approach differs)

Any one of: many files (roughly >15), a large line count (roughly >800 changed lines), several modules touched, or a stacked/umbrella series. At this size the failure modes differ from a small PR:

- **Drowning in nitpicks.** A 40-comment review is noise. Aim for the handful of findings that matter.
- **Missing the cross-file bug.** The real bugs live *between* files: a renamed field used inconsistently, a contract changed on one side but not the caller, a constant duplicated across modules that will drift, an error condition added but wired into only one path.
- **Losing the architecture.** Line-by-line hides whether the change is structured right. Review the shape first.

## Workflow

1. **Identify and size the PR.**
   ```bash
   gh pr view <n> --json title,headRepositoryOwner,headRepository,isCrossRepository,headRefOid,baseRefName,additions,deletions,changedFiles,files
   ```
   For a fork PR, fetch the head so you can read whole files, not the truncated diff (review-pr step 2). For a stacked PR, diff against its parent branch. For an umbrella/series, list sub-PRs and states; merged ones need no review.

2. **Triage the file list into tiers.**
   ```bash
   git diff --stat <base>..pr<n>
   git diff <base>..pr<n> --name-only | sed 's#/[^/]*$##' | sort | uniq -c | sort -rn   # files per dir
   ```
   - **Core logic** (the actual change): read in full. Highest effort; this is where bugs are.
   - **Callers / integration points**: read enough to verify the contract still holds across the boundary.
   - **Tests**: read to confirm they actually exercise the new behavior (negative + positive), not just compile.
   - **Mechanical / generated / low-risk** (renames, imports, golden files, docs, config bumps): skim only. Never comment on generated files (e.g. Spark `.sql.out`); flag the *source* change instead.

3. **Fan out the reading (recommended for very large PRs).** When the PR spans several independent modules, dispatch one `Explore` (or general-purpose) subagent per module to read that module's changed files and report back: what changed, the contract it exposes, and any suspected issue with file:line. Keep synthesis and all commenting in the main thread -- subagents locate and summarize, you decide and comment. This keeps whole-file context out of your window while covering everything.

4. **Review top-down.**
   - **Architecture pass first.** Right layer, right abstraction, no class shipped ahead of its caller, no duplicated responsibility, backward/version compatibility handled (Spark: `@since`, `MimaExcludes`, error conditions wired everywhere). These go in the prose summary, not on a single line.
   - **Cross-file correctness pass.** Trace each changed contract to every use. Highest-value pass for a big PR.
   - **Line-level pass on the core-logic tier only.** Apply the review-pr correctness checklist. Do not line-review the mechanical tier.

5. **Draft findings, assign severity, then ruthlessly cut.** Keep only real correctness/logic bugs, cross-file contract breaks, and concrete quality wins that will bite later. Drop pure style. 5-10 sharp findings beats 40 mediocre ones.

6. **Compose the structured body** (format below), **post one PENDING review** via the review-pr `gh api` recipe with all inline comments batched into the single payload, **verify every anchor**, and **never submit**.

## Calibration (from well-cited reviewers)

These rules are lifted from the most widely-used reviewer prompts/guides (PR-Agent / Qodo, Google eng-practices) and materially improve signal:

- **Confidence vs impact (PR-Agent).** For clear bugs and security issues, be thorough -- do not skip a genuine problem just because the trigger scenario is narrow. For lower-severity concerns, be certain before flagging. When confidence is limited but potential impact is high (data loss, security), report it with an explicit note on what is uncertain. **Otherwise prefer not reporting over guessing.**
- **Scope discipline (PR-Agent).** Review the code this PR introduces (the `+` lines) and the issues it introduces. Avoid suggestions that merely duplicate existing functionality or re-litigate pre-existing code the PR didn't touch. For a big PR spanning modules, "introduced by this PR" includes contracts the PR *changed* that other files still assume.
- **Priority order (Google eng-practices).** Weigh findings in this order: **Design > Functionality > Complexity > Tests > Naming > Comments > Style > Consistency > Docs.** Design and functionality concerns are Blocking material; naming/comments/style are Nit. A big PR that is functionally correct but structurally wrong still merits a Blocking-level design note in the summary.
- **Nit labeling (Google).** Anything non-mandatory is a Nit (P3); say so, so the author knows they can skip it. Comments should explain *why*, not restate *what* the code does.
- **Actionability + explanation (empirically backed).** A review comment is "useful" in the research sense when it leads to a code change (Bosu et al., Microsoft, 1.5M comments). Two properties drive that, and both are measured, not folklore: comments are more likely to be resolved when they are (1) **specific and concise**, anchored to exact lines, and (2) **explain the reasoning** -- the concrete failure scenario and *why* it matters ("Explaining Explanations", TOSEM 2025). So every finding must be **actionable** (an imperative fix the author can act on, ideally a one-click suggestion, per Google Tricorder) and carry its **why**. Detail means *relevant* detail -- the reasoning and the repro -- not length; concise-and-specific beats long-and-vague. Cut anything that restates the diff.

## Severity taxonomy

Assign every finding exactly one level. This drives both the count line and the section grouping.

| Level | Section | Meaning |
|-------|---------|---------|
| **P0** | Blocking | Data loss, corruption, security hole, or crash on a common path. Must fix before merge. |
| **P1** | Blocking | Wrong result / broken contract on a real path; a shipped feature that is silently non-functional. Must fix before merge. |
| **P2** | Non-blocking | Real issue that should be fixed but does not block: missing test coverage, a narrow-edge bug, a doc that misleads. |
| **P3** | Nit | Style, stale comment, naming, minor clarity. Optional. |

"Blocking" = P0/P1; "Non-blocking" = P2; "Nit" = P3. Be conservative promoting to Blocking: only when you can name the concrete input/state that produces the wrong outcome (state it in Verification).

## Review body format

This mirrors the structured reviews senior committers on large OSS projects (e.g. Apache Spark's `cloud-fan`, `peter-toth`) post: a prose summary that carries the verdict, a severity-counted findings table, and a verification section, plus optional sections that only appear when relevant. There is deliberately **no separate "recommendation" or "review effort" line** -- the merge verdict is woven into the summary prose ("this should be fixed before merge", "no blocking issues") and the severity counts, exactly as those reviewers do. The GitHub review *state* (which the user sets on submit) is the formal approve/request-changes signal; the body does not restate it as a field.

The body is the map for a big PR; the inline comments carry the fixes. Structure:

Use `---` horizontal rules between the top-level sections so a long review is easy to scan. The order is fixed: Summary, then the high-level action line, then Findings, then Verification, then any optional sections.

```markdown
## Review summary

<2-4 sentences of prose. What the PR does; your overall read of whether it is sound; the single
most important risk; and the merge verdict woven in ("...should be closed before merge", or
"clean, no blocking issues"). This is the high-level orientation: a reader who stops here should
understand the change and what it needs. This is where architecture-level concerns live. When the
PR genuinely bundles independent changes, add one sentence that it would review better split.>

**Action items:** <one imperative line naming what the author must do -- the Blocking titles, e.g.
"Before merge: reject order-sensitive sources (P1); cover the negative restore path (P2)." If
nothing blocks, say so: "Nothing blocking; the P2/P3 below are optional polish.">

---

## Findings

**<N> total: <a> P0, <b> P1, <c> P2, <d> P3.**

### Blocking (P0/P1)
- **<imperative fix title>** - `path/to/File.scala:LINE` - see inline.

### Non-blocking (P2)
- **<imperative fix title>** - `path/to/File.scala:LINE` - see inline.

### Nit (P3)
- **<imperative fix title>** - `path/to/File.scala:LINE` - see inline.

---

## Verification

- <one bullet per Blocking finding: the concrete input/state -> wrong outcome that makes it real,
  and why it is specific to this PR. This is what earns a Blocking label.>
- <note anything you did NOT run or could not verify statically.>

<!-- review-big-pr {"head_sha":"<headRefOid>","findings":[{"id":"<title-slug>","sev":"P1","path":"...","line":NNN}]} -->
```

Optional sections, included only when they apply (drop them otherwise), placed after Verification in this order -- these match the Spark reviewers' format:

- `## Existing discussions` -- when a finding is already an open review thread, link it here (`[existing discussion](<thread-url>)`) instead of posting a duplicate inline comment. Mark each as remaining or resolved.
- `## Re-review status` -- on a second pass only (see "Re-reviewing" below): one bold line, e.g. `**Prior findings: 2 resolved, 1 still present. New findings: 1.**`
- `## PR metadata suggestions` -- when the PR description/title needs a concrete fix (an unchecked user-facing-change box, a wrong component tag, an undocumented behavior change).

Rules:
- **No "Recommendation"/"review effort" line.** Put the verdict in the summary prose. (Removed on purpose: those are PR-Agent fields, not the Spark committer format this skill targets.)
- **The `**Action items:**` line is required.** It is the high-level to-do: it restates, in one imperative sentence, what the author must do, derived from the Blocking findings (or states that nothing blocks). This is a deliberate, evidence-backed redundancy -- the summary orients, the action line tells the author what to act on, the Findings table anchors each item to a line. Keep it to one line; do not re-explain the findings here.
- Use `---` between Summary, Findings, and Verification for clear visual separation.
- Omit any severity section that has no findings; keep the count line complete (list all four counts even when zero).
- Each findings-list bullet is a one-line pointer whose title is the imperative fix; the *explanation and the suggestion block* live in the matching **inline comment**, not in the body. This mirrors "see inline". A finding delivered as a body note rather than an inline comment (because its line is outside the diff) says so instead of "see inline".
- The trailing HTML comment is a **hidden marker** for re-review tracking, invisible in rendered GitHub. Keep the JSON small: head SHA plus one entry per finding (slug, severity, path, line).

## Inline comments

Every finding in the body has a matching inline comment anchored to the exact line. Each inline comment carries three things, in this order (this is the evidence-backed shape -- problem + why + actionable fix):
1. **What is wrong** -- one plain sentence.
2. **Why it matters** -- the concrete failure scenario (the input/state that triggers it, and the resulting wrong outcome). This is the explanation that makes a comment get acted on; do not skip it, but keep it to a sentence or two.
3. **Suggested fix (if applicable)** -- label this part **"Suggested fix:"**. Use a click-to-commit `suggestion` block wherever the fix is a contiguous in-place edit (review-pr has the exact anchoring + whitespace/margin rules); fall back to prose (still concrete: name the method/lines to change) for multi-spot or structural fixes, and say so. When there is no single obvious fix -- a design question, a judgement call, or a concern you are raising for the author to weigh -- omit this part rather than inventing one, and end with the open question instead. Hence "if applicable".

- One finding per comment. Be specific and concise: relevant detail (the why, the repro, the fix), not length. No em dashes (a hook blocks them). No restating the diff.

## Re-reviewing (second pass on a new commit)

When re-invoked on a PR you already reviewed:
1. Read your prior pending/submitted review body and parse its `<!-- review-big-pr ... -->` marker for the prior findings and `head_sha`.
2. Diff the new head against the old `head_sha` to see what changed.
3. For each prior finding: mark **resolved** (the fix landed), **still present** (unchanged), or **superseded**. Do not re-post an inline comment that is already an open discussion; reference the existing thread instead.
4. Open the new body with a re-review line, then the normal structure for anything still open or newly found:
   ```markdown
   ## Re-review status

   **Prior findings: <x> resolved, <y> still present. New findings: <z>.**
   ```
5. Write a fresh marker with the new head SHA and the current open findings.

## Close-out

Keep the chat summary short. Tell the user: the review is PENDING; the finding counts by severity (e.g. "1 P1, 2 P2"); how many inline comments are one-click suggestions vs manual; which files/modules you read in full vs skimmed; and anything you did not run or verify. Then **end with a clickable link to the PR's Files changed tab** as the last line, so they read the pending comments and submit or discard themselves:

```
Review is PENDING: 1 blocking (P1), 2 non-blocking (P2); 2 of 3 inline comments are one-click suggestions. Read and submit here:
https://github.com/<owner>/<repo>/pull/<n>/files
```

## References

The body format mirrors the structured AI-assisted reviews now common on `apache/spark` (senior committers post a prose summary, a P0-P3 findings table, a Verification section, and optional Existing-discussions / Re-review-status / PR-metadata sections, with a hidden re-review marker). That format is the target. The *calibration* rules (how to decide what to flag) draw on widely-used reviewer guides -- but only the judgement rules, not their output fields:
- PR-Agent / Qodo `/review` prompt -- adopted: confidence-vs-impact and scope discipline. Deliberately NOT adopted: its `merge_recommendation` / `estimated_effort_to_review` / `can_be_split` output fields, which do not fit the Spark committer format. https://github.com/qodo-ai/pr-agent
- Google Engineering Practices, "What to look for in a code review" (design-first priority order, Nit labeling): https://google.github.io/eng-practices/review/reviewer/looking-for.html

The **actionability + explanation** rules (specific-and-concise comments anchored to lines, each with its reasoning, get resolved more often) are empirically grounded, not stylistic preference:
- Bosu, Greiler, Bird, "Characteristics of Useful Code Reviews: An Empirical Study at Microsoft" (a comment is useful when it leads to a nearby code change): https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/bosu2015useful.pdf
- "Explaining Explanations: An Empirical Study of Explanations in Code Reviews", ACM TOSEM 2025 (explaining the reasoning raises usefulness): https://dl.acm.org/doi/10.1145/3708518
- "Hold On! Is My Feedback Useful? Evaluating the Usefulness of Code Review Comments", EMSE 2025, and "What Types of Code Review Comments Do Developers Most Frequently Resolve?" 2025 (concise, specific, actionable comments are resolved more than vague or design-level ones): https://link.springer.com/article/10.1007/s10664-025-10617-1 , https://arxiv.org/abs/2510.05450
