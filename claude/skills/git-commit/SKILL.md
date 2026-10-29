---
name: git-commit
description: Write a git commit message that DESCRIBES WHAT THE ADDED/CHANGED CODE IS AND HOW IT WORKS (components, APIs, data flow), not a changelog of actions, then copy it to the clipboard. Do NOT run the commit - the user commits themselves. Hard rule: NO manual line wrapping - one continuous line per paragraph and per bullet, let soft-wrap handle it. No AI/tool attribution, no references to planning docs or trackers. Trigger: /git-commit, or asking to write a commit message / commit the changes.
---

# git-commit

Write a commit message for the current changes and copy it to the clipboard. **Do NOT run the commit.** The user runs `git commit` themselves. The skill's job ends at handing over the staged changes, the clipboard, and the exact command to run.

## What the message says

- Describe **what the added or existing code IS and HOW IT WORKS**: the components, their responsibilities, the endpoints/APIs, the data flow, how the pieces connect and behave. Describe the system as it stands after the change, not a list of actions taken ("added X", "refactored Y", "fixed Z").
- Ground every statement in the real diff. Run `git status --short`, `git diff --cached --stat` (and `git diff --stat` for unstaged), and read enough of the changed/added files to describe them accurately. Never invent or guess behavior.
- Lead with one short summary line (aim for <= ~72 chars), then a blank line, then the body grouped into short labeled sections or bullets by area/component.
- Plain and factual. No marketing adjectives.

## Hard formatting rule (the point of this skill)

- **Do NOT press enter to wrap lines.** Write each paragraph and each bullet as ONE continuous line and let the editor/terminal soft-wrap it. Never insert a newline mid-sentence or hard-wrap a paragraph at ~72/80 columns.
- Blank lines are used ONLY to separate the summary line from the body and to separate sections/blocks.
- Each bullet begins with `- ` and is a single line, however long.

## Do not include

- No AI or tool attribution: no "Generated with ...", no `Co-Authored-By:` assistant trailer, no mention of the assistant.
- No references to planning/roadmap documents, issue trackers, ticket numbers, or the upstream project a fork came from, unless the user explicitly asks for them.

## Steps

1. Inspect scope: `git status --short`, `git diff --cached --stat`. If nothing is staged and the user wants to commit everything, `git add -A` first (confirm the scope looks right, no `target/`, `node_modules/`, build output).
2. Read the key changed/added files so the description is accurate.
3. Write the message to a temp file with the Write tool (so the exact newlines are preserved), following the content + formatting rules above. Put the file in the session scratchpad directory when one is available, otherwise `/tmp`.
4. Copy it to the clipboard from that file, trying in order: `wl-copy < FILE` (Wayland), then `xclip -selection clipboard < FILE`, then `xsel --clipboard --input < FILE`. If none exist, say so and print the message.
5. **Do NOT commit.** Stop here and tell the user the changes are staged and the message is on the clipboard, then give them the exact command to run themselves: `git commit -F FILE` (suggest the `!` prefix so it runs in-session). Never invoke `git commit` yourself.
6. Do NOT `git push` or `git add` beyond what step 1 covers unless the user explicitly asks.
