---
name: pptx-high-level
description: "Turn any code, PR, file, concept, or question into a concise, high-level PowerPoint (.pptx) that explains a topic to any audience. Slides carry only the big picture, no low-level detail. The pptx analog of md-high-level. Trigger: /pptx-high-level"
---

# /pptx-high-level

Take any input (a PR, a file, a code path, a concept, a question) and produce a **concise, high-level PowerPoint deck** that explains the topic to anyone, from a non-technical reader to a senior engineer.

This is the slide analog of `md-high-level`. Same spirit, different medium: **clarity over completeness, big picture only.** A slide is not a document. If a point needs a paragraph, it does not belong here.

**Theme.** The deck renders in a "modern professional" theme tuned for research meetings and conference-style talks: a deep-teal accent, near-black cool ink, crisp sans, soft rounded cards with a subtle shadow and light tint, generous whitespace, and a quiet footer (deck title + slide number) on every content slide. The theme lives entirely in `build_deck.py`; you only author content. Set a top-level `"title"` on the spec (the deck/talk title) so it shows in the footer; if omitted, the footer falls back to the `title` slide's title.

**Show, don't tell. Prefer a diagram over a bullet list.** A process is a `flow`, a set of numbers is a `compare`, an architecture is a `stack`, a change is a `two_column`. Reach for a text-only `bullets` slide only when nothing structural is being said. Aim for **at least as many diagram slides as text slides**, and keep text sparse everywhere: a slide should land in a glance, not a read.

**Keep diagrams high-level.** 3 to 6 nodes, short labels (a couple of words each), one relationship per diagram. A diagram with ten boxes is a wiring schematic, not an explainer: simplify or split it.

**No low-level detail.** No code, no function names, no config keys, no line-by-line walkthroughs. If a reader would need the source open to follow it, cut it. Explain the *idea* and the *change*, not the *implementation*.

## Usage

```
/pptx-high-level <topic or question>       # explain a concept
/pptx-high-level <file or path>            # explain what a module does
/pptx-high-level this PR                    # explain the current branch's changes
/pptx-high-level <topic> --out <dir>       # write to a folder (default: reference/)
```

## Steps

1. **Gather context.** Read the file, run `git diff main...HEAD`, or use the conversation. Understand the thing well enough to explain it simply. Do NOT put raw code or low-level detail into the deck.

2. **Distill to the big picture.** Before writing slides, decide the one-sentence answer and the 3 to 5 points that matter. Everything else is cut. Aim for **6 to 10 slides total**. If you are past 10, you are including low-level detail: cut more.

3. **Author the deck spec** as JSON following the Slide Grammar below. Write it to a temp file (use the scratchpad dir).

4. **Build the deck** by running the bundled script:
   ```
   python3 ~/.claude/skills/pptx-high-level/build_deck.py <deck.json> <out.pptx>
   ```
   `python-pptx` must be installed (`pip install python-pptx`). The script only lays out and themes what you give it; it never invents content.

5. **Save** the `.pptx` to `reference/<kebab-case-topic>.pptx` in the current project (create `reference/` if needed), unless `--out` says otherwise. Tell the user the path.

## Slide Grammar (the deck spec)

The spec is `{"slides": [ ... ]}`. Each slide is one object with a `type`. Keep every string short: titles are a few words, labels and bullets are a phrase not a sentence, max ~5 items per slide.

```json
{
  "title": "Deck / talk title (shown in the footer)",
  "slides": [
    {"type": "title",   "title": "Topic name", "subtitle": "one-line framing"},
    {"type": "summary", "title": "In one sentence", "body": "The whole thing, simply, in one sentence."},

    {"type": "flow", "title": "How it works", "steps": ["Input", "Transform", "Result"], "caption": "optional one-line note"},
    {"type": "compare", "title": "The numbers", "unit": "%", "highlight": "Ours",
       "bars": [{"label": "Ours", "value": 88}, {"label": "Baseline", "value": 70}]},
    {"type": "stack", "title": "The pieces", "layers": ["Top layer", "Middle layer", "Foundation"], "caption": "optional"},

    {"type": "two_column", "title": "Before vs After",
       "left_title": "Before", "left": ["phrase", "phrase"],
       "right_title": "After", "right": ["phrase", "phrase"]},
    {"type": "bullets", "title": "The big moves", "bullets": ["phrase", "phrase", "phrase"]},
    {"type": "section", "title": "Why it matters", "subtitle": "optional"},
    {"type": "closing", "title": "Takeaway", "body": "The one thing to remember."}
  ]
}
```

Diagram slide types (reach for these first):
- **mermaid** - a real Mermaid diagram, rendered to an image and embedded. The best-looking option and the default for anything with structure (flowcharts, relationships, decision splits, simple graphs, sequence/arch sketches). Spec: `{"type": "mermaid", "title": "...", "mermaid": "flowchart LR\n  A[Step one] --> B[Step two] --> C[Result]", "caption": "optional"}`. Keep it high-level: a handful of nodes, short labels, one relationship. Requires `@mermaid-js/mermaid-cli` (`mmdc`) plus a Chrome/Chromium install; if the render fails the slide shows a note, so prefer `flow`/`compare`/`stack` only when mermaid is unavailable. Nodes default to the teal card palette; use `classDef` when you want to color specific nodes (teal accent `fill:#E4F1EF,stroke:#0F766E`; green good `fill:#D6EEDD,stroke:#1B7F3B`; rust bad `fill:#F6D9CE,stroke:#B0451E`).
- **compare** - horizontal bars for a set of numbers (see below). Mermaid is weak at quantitative bars, so use `compare` for scores/benchmarks/costs and `mermaid` for everything structural.
- **flow** - a sequence of steps joined by arrows (`steps`, <=6). A process, pipeline, or before-to-after path. Optional `direction: "down"`, `caption`. Use only when mermaid is unavailable.
- **compare** - horizontal bars comparing a few numbers (`bars` of `{label, value}`, <=6). The go-to for benchmark results, costs, scores. Optional `unit` (e.g. `"%"`) and `highlight` (one label drawn in the accent color).
- **stack** - full-width boxes stacked top to bottom (`layers`, <=5). Architecture, layers, or a hierarchy. Optional `caption`.
- **two_column** - side-by-side comparison (before/after, old/new, problem/fix). Great for a change.
- **table** - a styled grid (`columns`, `rows`). For a "technique / source / why" decision table or a benchmark matrix. Optional `accent` ("good"|"warn"|"accent"), `col_widths`.

Progress-report types (built for status / techniques writeups):
- **metrics** - a row of 2 to 4 big-number KPI tiles. **Lead a progress report with this.** Spec: `{"type": "metrics", "title": "Where it stands", "items": [{"value": "85%", "label": "WikiTableQuestions", "note": "vs 88% best"}, {"value": "3.5x", "label": "leaner per turn"}]}`. `value` is a short string; `note` is an optional qualifier.
- **status_list** - a list of items each with a color-coded status badge. **The workhorse for "techniques tried"** (kept / dropped / testing) and for a status roadmap. Spec: `{"type": "status_list", "title": "Techniques tried", "items": [{"text": "Data-driven join discovery", "status": "kept", "note": "+X pts"}, {"text": "Eager all-file schema", "status": "dropped", "note": "regressed geo"}, {"text": "Best-of-N selection", "status": "testing"}]}`. `status`: kept|done|good -> green, dropped|cut|bad -> rust, else (testing|wip|next) -> amber. <=6 items.
- **timeline** - a horizontal milestone line with status-colored dots (progress so far + what's next). Spec: `{"type": "timeline", "title": "Path so far", "milestones": [{"label": "Whole-workflow emit", "status": "done"}, {"label": "Join-path planner", "status": "now"}, {"label": "BIRD / Spider", "status": "next"}]}`. <=6.

For a `compare` slide with more than two players, give each bar a `role` ("accent" for ours, "good" for the best competitor, "muted" for the rest) instead of a single `highlight`, so the comparison reads at a glance: `{"type": "compare", "title": "...", "unit": "%", "bars": [{"label": "Ours", "value": 85, "role": "accent"}, {"label": "Best rival", "value": 88, "role": "good"}, {"label": "Other", "value": 70, "role": "muted"}]}`.

Text slide types (use sparingly):
- **title** - opening slide. Use once, first.
- **summary** - the one-sentence answer in a highlighted panel. Use once, early (this is the "lead with the answer").
- **bullets** - a titled list of short phrases. Fallback for points with no structure to draw; don't let it become the whole deck.
- **section** - a full-color divider to break the deck into acts. Optional.
- **closing** - the dark takeaway slide. Use once, last.

## Recommended shape

```
title  ->  summary  ->  flow: how it works  ->  compare: the numbers
       ->  two_column: before/after  ->  section: why it matters  ->  closing
```

That shape is mostly diagrams by design. Swap in `stack` for architecture, or a single `bullets` slide only where nothing structural is being said. Drop any slide that would only exist to hold detail. Fewer, cleaner, more visual slides win.

### Progress-report / techniques-tried shape

For a research status update ("what we built, what we tried, where it stands"), prefer:

```
title  ->  metrics: headline numbers  ->  mermaid: how it works
       ->  status_list: techniques tried (kept/dropped/testing)
       ->  compare: benchmark results (per-bar roles)
       ->  two_column: how ours differs from the rival
       ->  timeline: path so far and next  ->  closing: takeaway
```

Lead with `metrics` so the room sees the result first. Put every lever you tried on a `status_list` with honest kept/dropped/testing badges (document the negatives, do not hide them). Use `timeline` for the arc of the work and what is next. This shape stays visual and reads in a five-minute standup.

## Rules

- **Lead with the answer.** The `summary` slide comes early and states the whole thing in one sentence.
- **Diagram first.** Before writing a `bullets` slide, ask if it is really a `flow` (steps), a `compare` (numbers), a `stack` (layers), or a `two_column` (a change). If so, draw it. Bullets are the last resort, not the default.
- **One idea per slide.** If a slide has two ideas, split it or cut one.
- **Phrases, not sentences.** Labels and bullets are glanceable. Anything that wraps to three lines is too long.
- **Before/After for changes.** When explaining a fix or a change, a `two_column` makes the point instantly.
- **Be honest and concrete.** Use real names and real numbers when they clarify. Do not invent detail you did not verify.
- **No low-level detail.** No code, identifiers, config keys, or step-by-step internals. Ever.
- **No em dashes.** Use commas, colons, hyphens, or parentheses.
- **No manual line wrapping** in the JSON strings. One string = one line.

## Tone

Friendly, calm, executive-summary clear. Like a senior engineer giving a five-minute stand-up to a room that includes their manager and a new hire. Never condescending, never buried in jargon.
