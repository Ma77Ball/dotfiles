# Zellij session launcher (auto-sourced from ~/.bashrc.d/).
#
# At startup, name the session for this terminal window. Typing an existing
# name (shown in the list) rejoins/resurrects it, including after a reboot; a
# new name starts a fresh session; blank falls back to an auto-named one.
# Separate windows with different names stay independent (no mirroring).
#
# Skipped when: zellij isn't installed, already inside zellij, non-interactive,
# or inside an editor's embedded terminal (nvim / VS Code).
#
# Companion config lives in ~/.config/zellij/ (dotfiles/zellij/): locked by
# default so no keys collide with apps (Ctrl+g unlocks); always-live tab keys
# Ctrl+Shift+T (new), Ctrl+Tab / Ctrl+Shift+Tab (switch); fully bar-less layout.
if command -v zellij &>/dev/null \
   && [[ -z "$ZELLIJ" && $- == *i* && -z "$NVIM" && "$TERM_PROGRAM" != "vscode" ]]; then
    _zsessions="$(zellij list-sessions -s 2>/dev/null)"
    if [[ -n "$_zsessions" ]]; then
        echo "Existing sessions (type one to rejoin):"
        echo "$_zsessions" | sed 's/^/  /'
    fi
    read -rp "Zellij session name (Enter = new): " _zsession
    if [[ -n "$_zsession" ]]; then
        zellij attach --create "$_zsession"
    else
        zellij
    fi
    unset _zsession _zsessions
fi
