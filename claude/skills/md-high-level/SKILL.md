---
name: md-high-level
description: "Turn any code, PR, file, concept, or question into a high-level, plain-language markdown explainer with diagrams that anybody can understand, regardless of technical level. Saves the result as a reference doc. Trigger: /md-high-level"
---

# /md-high-level

Take any input (a PR, a file, a code path, a concept, a question) and produce a
**high-level markdown explainer** that anyone can understand, from a non-technical
reader to a senior engineer. Save it as a reference doc.

The goal is **clarity, not completeness**. Explain the idea, not every line.

## Usage

```
/md-high-level <topic or question>        # explain a concept in plain language
/md-high-level <file or path>             # explain what a file/module does
/md-high-level this PR                     # explain the current branch's changes
/md-high-level <topic> --out <dir>        # write to a specific folder (default: reference/)
```

## Steps

1. **Gather context.** Read the file, run `git diff main...HEAD`, or use what's in the
   conversation. Understand the thing well enough to explain it simply. Do NOT dump
   raw code into the doc.

2. **Write the doc** following the Output Rules below.

3. **Save it** to `reference/<kebab-case-topic>.md` in the current project (create the
   `reference/` folder if needed), unless `--out` says otherwise. Tell the user the path.

## Output Rules (this is the important part)

**Lead with the answer.** Start with a one-sentence "In one sentence:" summary in a
blockquote before anything else.

**Layer by depth.** Structure so a reader can stop at any point and still have learned
something: one-liner -> what it is -> how it works -> why it matters. Each section builds
on the last.

**Plain language first.** Assume zero prior knowledge. The first time a technical term
appears, define it in everyday words. Prefer short sentences. If you must use jargon,
gloss it inline (e.g. "workers: the little processes that do the work").

**Use analogies.** Anchor abstract ideas to something familiar (an assembly line, a
mailbox, a waiting room). One good analogy beats a paragraph of precision.

**Always include diagrams.** Use Mermaid (` ```mermaid ` fenced blocks) since it renders
on GitHub and most markdown viewers. Aim for 2 to 4 diagrams that carry the explanation:
   - `flowchart` for structure / how pieces relate
   - `flowchart TD` with a decision node (`{...}`) for logic, loops, retries
   - `sequenceDiagram` for who-talks-to-whom over time
   Keep each diagram small (a handful of nodes). A diagram should be glanceable.

**Use before/after and comparison tables.** For fixes or changes, a two-column
Before | After table makes the point instantly. Use tables for settings/values too.

**Be honest and concrete.** Use real names, real numbers (150 attempts, 200ms) when they
clarify. Don't invent detail you didn't verify.

**Keep it tight.** No walls of text. Use headings, short paragraphs, lists, and
horizontal rules (`---`) between major sections.

**No em dashes.** Use commas, colons, hyphens, or parentheses instead.

**No manual line wrapping.** Soft-wrap is on, so never press enter mid-paragraph to hit a column width. One paragraph = one line; use a newline only for a real structural break (new paragraph, list item, heading, code block). Applies to `.md` and `.txt` output alike.

## Recommended shape

```
# <Title> (plus a parenthetical hook if useful)

> **In one sentence:** <the whole thing, simply>

---

## 1. What is <X>?          <- define + analogy + diagram
## 2. How does it work?     <- the mechanism + diagram
## 3. The problem / context <- if explaining a fix or change + diagram
## 4. The fix / the point   <- table + diagram
## 5. Why it matters        <- before/after table

---

*Reference doc: high-level overview. Source: <where this came from>.*
```

## Tone

Friendly, calm, explanatory. Like a patient senior engineer drawing on a whiteboard for
a brand-new teammate. Never condescending, never buried in jargon.
