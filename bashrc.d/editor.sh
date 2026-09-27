# Prefer Neovim as the default editor (git commits, lazygit, `git commit` in a
# terminal, etc.). Fedora's /etc/profile.d/nano-default-editor.sh sets EDITOR=nano
# whenever it's unset; this loader runs later (from ~/.bashrc.d/) and overrides it
# with nvim, falling back to vim, then leaving nano if neither is installed.
if command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim
elif command -v vim >/dev/null 2>&1; then
    export EDITOR=vim
fi
export VISUAL="$EDITOR"
