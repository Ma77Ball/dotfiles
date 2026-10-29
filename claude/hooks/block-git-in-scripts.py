#!/usr/bin/env python3
"""PreToolUse (Bash) hook: block running git commit / git push indirectly via a script.

Inline `git commit` / `git push` are already deny-listed in settings.json. This closes
the bypass where the same commands are placed inside a shell script and run via
`bash foo.sh` / `sh foo.sh` / `source foo.sh` / `./foo.sh`, which the inline deny rule
does not match. Inline git commit/push are left untouched (they still hit the deny rule).

Fails open: any parse/read error allows the command through so normal Bash use is never
broken by this hook.
"""
import sys, json, os, re, shlex

LAUNCHERS = {"bash", "sh", "zsh", "dash", "ksh", "source", "."}
# Benign leading words that precede the real command (e.g. `sudo bash x.sh`).
PREFIXES = {"sudo", "env", "time", "nice", "exec", "command", "builtin", "nohup", "stdbuf"}
SEG_SPLIT = re.compile(r"\|\||&&|\||;|&|\n")
ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
GIT_RE = re.compile(r"\bgit\b[^\n;|&]*\b(commit|push)\b")


def candidate_scripts(cmd):
    """Return scripts that are actually EXECUTED (in command position), not merely
    named as arguments to another command (so `rm x.sh` / `cat x.sh` are ignored)."""
    out = []
    for seg in SEG_SPLIT.split(cmd):
        seg = seg.strip()
        if not seg:
            continue
        try:
            toks = shlex.split(seg, comments=False, posix=True)
        except Exception:
            toks = seg.split()
        i = 0
        while i < len(toks) and (ASSIGN.match(toks[i]) or os.path.basename(toks[i]) in PREFIXES):
            i += 1
        if i >= len(toks):
            continue
        head = toks[i]
        if os.path.basename(head) in LAUNCHERS:
            for nxt in toks[i + 1:]:
                if nxt.startswith("-"):
                    continue
                out.append(nxt)
                break
        elif head.startswith("./") or head.endswith((".sh", ".bash")):
            out.append(head)
    return out


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    cmd = ((data.get("tool_input") or {}).get("command")) or ""
    if not cmd:
        return
    cwd = data.get("cwd") or os.getcwd()
    seen = set()
    for c in candidate_scripts(cmd):
        path = c if os.path.isabs(c) else os.path.join(cwd, c)
        path = os.path.normpath(path)
        if path in seen or not os.path.isfile(path):
            continue
        seen.add(path)
        try:
            with open(path, "r", errors="ignore") as f:
                content = f.read(500000)
        except Exception:
            continue
        if GIT_RE.search(content):
            reason = (
                "Blocked: this runs git commit/git push indirectly through a script (%s). "
                "Those commands are deny-listed inline and must not be routed through a script "
                "to bypass that. Run the git command yourself so it hits the normal permission "
                "prompt, or ask the user to run it." % os.path.basename(path)
            )
            print(json.dumps({
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }))
            return


main()
