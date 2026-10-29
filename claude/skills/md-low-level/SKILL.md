---
name: md-low-level
description: "Turn any code, PR, file, function, or system into a low-level, deeply technical markdown deep-dive for engineers: control flow, data structures, invariants, complexity, concurrency, and edge cases, with diagrams. Saves the result as a reference doc. Trigger: /md-low-level"
---

# /md-low-level

Take any input (a function, a file, a PR, a code path, a subsystem) and produce a
**low-level technical deep-dive** aimed at an engineer who will read, modify, or debug
the code. Save it as a reference doc.

The goal is **precision and completeness, not accessibility**. This is the counterpart to
`/md-high-level`: where that explains the idea, this documents the mechanism, exactly. If
in doubt, include the detail.

## Usage

```
/md-low-level <file or path>              # dissect a file/module
/md-low-level <function or symbol>        # trace one function end to end
/md-low-level this PR                     # analyze the current branch's changes in depth
/md-low-level <subsystem> --out <dir>     # write to a specific folder (default: reference/)
```

## Steps

1. **Read the actual code.** Open the files, follow the call graph, run `git diff main...HEAD`
   for a PR. Verify behavior against the source; do not infer from names. Note exact
   identifiers, signatures, line references (`file.py:120`), constants, and versions.

2. **Write the doc** following the Output Rules below.

3. **Save it** to `reference/<kebab-case-topic>.md` in the current project (create the
   `reference/` folder if needed), unless `--out` says otherwise. Tell the user the path.

## Output Rules (this is the important part)

**State the contract first.** Open with a `> **Contract:**` blockquote: what goes in
(inputs, preconditions), what comes out (outputs, postconditions), and what can go wrong
(errors, panics). An engineer should know the shape before reading the mechanism.

**Follow the real control flow.** Walk the execution path in order — entry point, branches,
loops, early returns, error paths. Reference exact function names and line anchors
(`serve.py:204`). Quote **small** snippets (a few lines) only where the exact code matters;
never paste whole files.

**Name the data structures and their shape.** For each important structure: its type, its
fields, ownership/lifetime, and any layout that matters. Use tables for field-by-field
breakdowns. Show representative JSON/struct shapes where a wire or storage format is involved.

**Spell out invariants and state.** What must always hold true? What mutates, who holds the
lock, what order is required, what happens on partial failure. Call out concurrency
(threads, async, reentrancy), atomicity, and idempotency explicitly.

**Give complexity and cost.** Time/space complexity (Big-O) for non-trivial routines; I/O,
syscalls, allocations, network round-trips, and any bounds/limits (max sizes, timeouts,
retry counts) with their real values.

**Enumerate edge cases and failure modes.** Empty input, overflow, truncation, races, expiry,
clock skew, encoding, path traversal, resource exhaustion. State how the code handles each,
or that it does not.

**Always include diagrams.** Use Mermaid (` ```mermaid ` fenced blocks). Aim for 2 to 4 that
carry real technical weight:
   - `flowchart TD` with decision nodes (`{...}`) for control flow, branches, retries, error paths
   - `sequenceDiagram` for call order, lock acquisition, request/response, or IPC over time
   - `classDiagram` or `erDiagram` for data-structure relationships / schema
   - `stateDiagram-v2` for lifecycles and state machines
   Keep each diagram focused on one mechanism; label edges with the real conditions.

   **Colors: black canvas, black node fill, white text, black arrows, vary only the stroke.** Light or tinted fills wash out and light/gray arrows read as white and vanish across viewers. So:
   - **Canvas + arrows:** start every diagram with `%%{init: {'theme':'dark', 'themeVariables': {'background':'#000000','lineColor':'#000000'}}}%%` on the line ABOVE the diagram type. Arrows must be black (`lineColor:'#000000'`, and `signalColor:'#000000'` for sequence diagrams), never light gray.
   - **Nodes:** give every flowchart a `classDef default fill:#000,color:#fff,stroke:#888,stroke-width:1px`, then distinguish special nodes by STROKE color only (keep `fill:#000,color:#fff`): green `#1B7F3B` good, rust `#B0451E` bad/error path, teal `#0F766E` accent.
   - **Sequence diagrams:** `%%{init: {'theme':'dark', 'themeVariables': {'background':'#000000','lineColor':'#000000','signalColor':'#000000','signalTextColor':'#000000','actorBkg':'#000000','actorTextColor':'#ffffff','actorBorder':'#888888','noteBkgColor':'#000000','noteTextColor':'#ffffff'}}}%%`.
   Never use light fills like `#d4edda`/`#f8d7da`, and never leave arrows light/gray.

**Be exact and honest.** Real identifiers, real numbers, real file:line references. If you did
not verify something, say so ("unverified") rather than inventing it. Distinguish what the
code *does* from what it *should* do.

**Structure for reference, not narrative.** Headings, tables, short paragraphs, and horizontal
rules (`---`) between sections so a reader can jump to the part they need. It is fine for this
doc to be long — but every line should earn its place.

**No em dashes.** Use commas, colons, hyphens, or parentheses instead.

**No manual line wrapping. Never press Enter to wrap a line, let soft-wrap do it.** A newline in the file is a structural break and nothing else: a new paragraph, a list item, a heading, a table row, or a code-block boundary. It is never a way to cap line width. So one paragraph is exactly one physical line no matter how long, one list item is one line, and you never break a sentence across two lines to hit 80/100/120 columns. The editor wraps the display; you do not wrap the source. This applies to every line of `.md` and `.txt` output, including this skill's own docs. Before saving, if two consecutive non-blank lines are both prose and the first does not end a sentence/heading/list-item/table-row, you hard-wrapped by mistake: join them.

## Recommended shape

```
# <Title>: <what it is, precisely>

> **Contract:** in: <inputs/preconditions> · out: <outputs/postconditions> · errors: <failure modes>

---

## 1. Overview            <- where it lives, entry points, the call graph (diagram)
## 2. Data structures     <- types, fields, shapes, lifetimes (tables + classDiagram/erDiagram)
## 3. Control flow        <- step-by-step execution, branches, loops, error paths (flowchart TD)
## 4. Invariants & state  <- locks, atomicity, ordering, concurrency, idempotency
## 5. Complexity & limits <- Big-O, I/O, bounds, timeouts, retry counts (real numbers)
## 6. Edge cases & failure modes   <- table: case | handling
## 7. Gotchas / notes     <- surprising behavior, TODOs, unverified assumptions
```

Pair with `/md-high-level` when a reader needs both altitudes: the high-level doc for the
idea, this one for the implementation.
