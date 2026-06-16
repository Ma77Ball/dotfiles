# todome

A terminal todo tracker, in the spirit of
[`ghme`](https://github.com/dlvhdr/gh-dash) and its sibling `msgme`. One TUI with
tabbed **views**, a scrollable task list, a side **notes** pane, and quick
actions, sharing the same gh-dash look.

It also doubles as a tiny CLI, so you can capture a task without leaving the
shell:

```sh
todome add "review the result-poll perf branch"
```

## Views

| View | Shows |
|---|---|
| Active | tasks still to do, sorted by priority then oldest-first |
| Done | completed tasks, most-recently-done first |
| All | everything, active before done |

Each task has a title, optional multi-line **notes** (shown in the side pane),
and a priority (low / med / high) that drives both the leading marker and the
sort order.

## How it is built

Mirrors the gh-dash / msgme layout:

| Package | Role |
|---|---|
| `internal/store` | JSON persistence in the XDG data dir + the `Task` model |
| `internal/tui` | Bubbletea model: views, list, notes pane, keybindings |
| `main.go` | entrypoint + CLI subcommands (`add`, `list`, `done`, `rm`, `path`) |

Unlike msgme, there is no network and no config: todome owns its data, so the
store *is* the backend. Tasks are written atomically (temp file + rename) on
every change.

## Install

Requires Go 1.25+.

```sh
make install        # builds and copies to ~/.local/bin/todome
# make sure ~/.local/bin is on your PATH
```

`dotfiles/install.sh` builds it automatically alongside msgme and ghme.

## Keys (in the TUI)

| Key | Action |
|---|---|
| `j` / `k` | move down / up |
| `tab` / `shift+tab` | next / previous view |
| `a` | add a task |
| `e` / `enter` | edit the title |
| `N` | edit notes (`ctrl+s` to save, `ctrl+g` to cancel) |
| `space` / `x` | toggle done |
| `+` / `-` | raise / lower priority |
| `d` | delete (confirm with `d`/`y`) |
| `p` | toggle the notes pane |
| `?` | toggle the help overlay |
| `q` | quit |

Inputs cancel with `ctrl+g` (rather than `esc`, which nvim's terminal mode
intercepts when todome runs inside it). `esc` still works outside nvim.

## CLI

```sh
todome                      # launch the dashboard
todome add <text...>        # add a task
todome list [all|done]      # print tasks (active by default)
todome done <id>            # toggle a task's done state
todome rm <id>              # delete a task
todome path                 # print the tasks file path
```

## Data

Tasks live in a single JSON file:

```
~/.local/share/todome/tasks.json      (override the dir with XDG_DATA_HOME)
```

It is plain JSON, so it is easy to back up, sync, or edit by hand.
