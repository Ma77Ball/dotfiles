#!/usr/bin/env python3
"""PreToolUse (Bash) hook: Claude may run `git commit`, but only in the /git-commit format.

Any `git commit` in the command must take its message from a file (`git commit -F FILE`,
the file the git-commit skill writes), and that message must follow the skill's rules:

  * a non-empty summary line, followed by a blank line when there is a body
  * no hard-wrapped paragraphs: inside a block, a line may only be followed by another
    non-blank line when the next line is a bullet/numbered item, the current line is a
    label ending in ":", or the line is indented/fenced code
  * no AI/tool attribution (assistant Co-Authored-By trailers, "Generated with ...")

`-m/--message`, `-F -` (stdin) and editor commits are denied with a pointer to the skill.
`git commit --amend --no-edit` (message unchanged) is allowed. `git push` stays deny-listed
in settings.json; this hook does not touch it.

Fails open on its own errors (unparsable input) so normal Bash use is never broken.
"""
import json
import os
import re
import shlex
import sys
from typing import NoReturn

SEG_SPLIT = re.compile(r"\|\||&&|\||;|&|\n")
LIST_ITEM = re.compile(r"^\s*([-*+]|\d+[.)])\s")
ATTRIBUTION = [
    re.compile(r"(?im)^\s*co-authored-by:.*\b(claude|anthropic|copilot|chatgpt|openai|gpt|ai)\b"),
    re.compile(r"(?i)generated (with|by) .*(claude|ai\b|copilot|chatgpt)"),
    re.compile(r"\U0001F916"),  # robot emoji used in "Generated with Claude Code"
]
SKILL_HINT = (
    "Use the /git-commit skill: write the message to a file in its format (one summary line, "
    "a blank line, then one unwrapped line per paragraph/bullet, no AI attribution) and run "
    "`git commit -F FILE`."
)


def deny(reason) -> NoReturn:
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }))
    sys.exit(0)


def commit_args(seg):
    """If this segment runs `git [global opts] commit ...`, return the args after `commit`."""
    try:
        toks = shlex.split(seg, posix=True)
    except Exception:
        toks = seg.split()
    for i, t in enumerate(toks):
        if os.path.basename(t) != "git":
            continue
        j = i + 1
        while j < len(toks) and toks[j].startswith("-"):
            # global options that take a value: -C dir, -c key=val, --git-dir x, --work-tree x
            if toks[j] in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
                j += 1
            j += 1
        if j < len(toks) and toks[j] == "commit":
            return toks[j + 1:], toks[:j]
    return None, None


def message_file(args):
    """Return (file, uses_message_flag)."""
    f = None
    uses_m = False
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("-F", "--file"):
            f = args[i + 1] if i + 1 < len(args) else ""
            i += 1
        elif a.startswith("--file="):
            f = a.split("=", 1)[1]
        elif a.startswith("-F") and len(a) > 2:
            f = a[2:]
        elif a in ("-m", "--message") or a.startswith("--message=") or (a.startswith("-m") and len(a) > 2):
            uses_m = True
        elif re.match(r"^-[a-zA-Z]*m$", a):  # bundled short flags like -am
            uses_m = True
        i += 1
    return f, uses_m


def check_message(text):
    lines = [l.rstrip("\n") for l in text.splitlines() if not l.startswith("#")]
    while lines and not lines[-1].strip():
        lines.pop()
    if not lines or not lines[0].strip():
        return "The commit message has no summary line."
    if len(lines) > 1 and lines[1].strip():
        return "The summary line must be a single line followed by a blank line."
    for pat in ATTRIBUTION:
        if pat.search(text):
            return "The commit message contains AI/tool attribution, which the /git-commit format forbids."
    in_fence = False
    body = lines[2:]
    for idx in range(len(body) - 1):
        cur, nxt = body[idx], body[idx + 1]
        if cur.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or not cur.strip() or not nxt.strip():
            continue
        if cur.startswith(("    ", "\t")) or nxt.startswith(("    ", "\t")):
            continue  # indented code
        if LIST_ITEM.match(nxt) or cur.rstrip().endswith(":") or nxt.lstrip().startswith("```"):
            continue
        return (
            "The commit message looks hard-wrapped (line %d continues onto the next line). "
            "Write each paragraph/bullet as one continuous line." % (idx + 3)
        )
    return None


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    cmd = ((data.get("tool_input") or {}).get("command")) or ""
    if "commit" not in cmd:
        return
    cwd = data.get("cwd") or os.getcwd()
    for seg in SEG_SPLIT.split(cmd):
        args, prefix = commit_args(seg.strip())
        if args is None:
            continue
        if "--no-edit" in args:
            continue  # amend keeping the existing message
        f, uses_m = message_file(args)
        if uses_m:
            deny("`git commit -m` is not allowed. " + SKILL_HINT)
        if not f or f == "-":
            deny("Commits must read their message from a file. " + SKILL_HINT)
        # honour `git -C dir` when resolving a relative message file
        base = cwd
        if prefix and "-C" in prefix:
            k = prefix.index("-C")
            if k + 1 < len(prefix):
                base = os.path.join(cwd, prefix[k + 1])
        path = f if os.path.isabs(f) else os.path.join(base, f)
        path = os.path.expanduser(path)
        try:
            with open(path, "r", errors="ignore") as fh:
                text = fh.read(200000)
        except Exception:
            deny("Could not read the commit message file %s. %s" % (f, SKILL_HINT))
        problem = check_message(text)
        if problem:
            deny(problem + " " + SKILL_HINT)


main()
