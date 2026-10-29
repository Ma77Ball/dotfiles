# Manual / internal setup notes

Most of this repo installs by **symlinking config files** into place (`nvim`, `ghostty`, `zellij`, ...). But some settings don't live in a file that can be symlinked - they live in the desktop environment's settings database (GNOME's dconf), on the input device, or in a cache that has to be rebuilt. Those can't "travel" as a dotfile, so they're either done by `install.sh` with the right tool (`gsettings`, `fc-cache`) or, when that isn't possible, listed here to do by hand.

This is the page to read when a fresh install *looks* right but a keypress does the wrong thing.

---

## 1. Keyboard shortcuts - who intercepts a keypress

A keypress is handled by the **first** layer that claims it, in this order:

```
device (input-remapper)  ->  GNOME / Wayland (dconf)  ->  Ghostty  ->  Zellij  ->  the shell / app
```

So if GNOME binds a key, the terminal never sees it; if Ghostty binds it, Zellij never sees it. Making "your commands work" is mostly a matter of **releasing** a key at a higher layer so it reaches the layer you want.

### 1a. GNOME-level shortcuts (dconf - NOT a dotfile)

Stored in GNOME's dconf database, not in any file in this repo. `install.sh` sets these with `gsettings`; set them by hand only if you're not on GNOME.

| Shortcut | Action | How it's set |
| --- | --- | --- |
| `Ctrl+T` | Launch Ghostty | `install.sh` adds a GNOME custom keybinding (`custom-keybindings/customN`) pointing at the Ghostty binary (or `flatpak run com.mitchellh.ghostty`). |

The installer is idempotent: if a Ghostty shortcut already exists it leaves your shortcuts alone, otherwise it claims the next free `customN` slot so it never overwrites an existing one.

**By hand (non-GNOME, or to change it):** Settings -> Keyboard -> View and Customize Shortcuts -> Custom Shortcuts -> `+`, name `Terminal`, command `ghostty` (or `flatpak run com.mitchellh.ghostty`), shortcut `Ctrl+T`.

**Inspect/change from the terminal:**

```bash
# list custom shortcuts
gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings
# read one slot
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$P binding
```

> GNOME may need a **log out / log in** (or reboot) before a freshly added shortcut fires.

### 1b. Ghostty - disabling the built-in commands (this *is* a dotfile)

These **do** transfer (they're in `ghostty/config`, which is symlinked), but they're the "default commands disabled so my commands work" part, documented here so it's clear *why* each line exists. Each `unbind` releases a key Ghostty would otherwise swallow, so it passes through to **Zellij**:

| Key | Ghostty default | Why it's unbound |
| --- | --- | --- |
| `Ctrl+Shift+T` | new Ghostty tab | let Zellij open a persistent tab instead |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | switch Ghostty tab | Zellij handles tab switching |
| `Ctrl+Shift+W` | close Ghostty tab | closes the focused Zellij pane/tab instead |
| `Ctrl+Shift+E` / `Ctrl+Shift+O` | split Ghostty pane | disable native splits; Zellij owns panes |

If you add a new Zellij binding on a `Ctrl+Shift+...` combo and it does nothing, check whether Ghostty is still grabbing it and add a matching `keybind = <combo>=unbind` to `ghostty/config`.

> Ghostty only reads its config at **startup**. After editing `ghostty/config`, fully quit and reopen Ghostty (or `Ctrl+Shift+,` to reload if that keybind is active).

### 1c. Zellij keybinds (this *is* a dotfile)

`zellij/config.kdl` sets `keybinds clear-defaults=true`, meaning Zellij's stock keymap is wiped and only the binds in that file exist. This transfers automatically. If a key does nothing inside Zellij, it's because nothing in `config.kdl` binds it (not because of a machine-level setting).

### 1d. Device-level remaps (input-remapper - optional, per-device)

`~/.config/input-remapper-2/` holds presets for specific devices (e.g. *Logitech MX Master 2S*, *Jabra Elite 7*). These are **device- and machine-specific** and are deliberately **not** in this repo - a preset for a mouse you don't own is useless, and autoload is currently empty. If you rely on a device remap:

1. Install input-remapper (`sudo dnf install input-remapper` / equivalent).
2. Recreate the preset in the input-remapper GUI, or copy the relevant `presets/<device>/*.json` over by hand.
3. Set it to autoload for that device.

---

## 2. Fonts

`install.sh` installs JetBrains Mono (the Ghostty font) via the package manager. If glyphs look wrong right after install, the font cache hasn't refreshed:

```bash
fc-cache -f
```

Then restart Ghostty.

---

## 3. Default terminal

`install.sh` writes `~/.config/xdg-terminals.list` so GNOME / file managers open Ghostty. If "Open Terminal" still opens the old terminal, log out/in so the session re-reads it.

---

## 4. Secrets and credentials (never in this repo)

These are intentionally kept out of version control (see `.gitignore`); set them per machine:

| What | Where |
| --- | --- |
| Shell secrets / tokens | `~/.bashrc.d/secrets.local.sh` (git-ignored; create it yourself) |
| Slack token for `msgme` | `$SLACK_TOKEN` (read by `~/.config/msgme/config.yml`) |
| GitHub auth for `ghme` | `gh auth login` |
| Claude Code (personal) | `claude` then `/login` |
| Claude Code (work account) | `CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude` then `/login` |

---

## 5. Quick post-install checklist

- [ ] Log out / log in so GNOME loads the `Ctrl+T` shortcut.
- [ ] `Ctrl+T` opens Ghostty.
- [ ] Inside Ghostty, `Ctrl+Shift+T` opens a **Zellij** tab (not a Ghostty tab).
- [ ] Font renders as JetBrains Mono (run `fc-cache -f` + restart if not).
- [ ] "Open Terminal" from the file manager opens Ghostty.
- [ ] Secrets in place (`secrets.local.sh`, `$SLACK_TOKEN`, `gh auth login`).
