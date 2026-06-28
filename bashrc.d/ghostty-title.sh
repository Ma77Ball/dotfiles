# Set the terminal title to the current git branch (else the working dir).
# A prompt hook updates it each prompt; a background HEAD watcher also updates it
# when the branch changes while a foreground program is running. Source this file.

# Title for a directory ($1, default $PWD): git branch (short SHA if detached),
# else the directory with $HOME shortened to ~.
__ghostty_title_string() {
    local dir="${1:-$PWD}" branch
    branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    if [ -z "$branch" ] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        # In a repo but detached HEAD (rebase, checkout of a commit/tag, etc.)
        branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    fi
    if [ -n "$branch" ]; then
        printf '%s' "$branch"
    else
        # Not in a git repo: mirror the default (current dir, ~ for $HOME).
        printf '%s' "${dir/#$HOME/~}"
    fi
}

# --- background HEAD watcher -------------------------------------------------
# Per-shell state: the watcher PID and the git dir it watches.
__ghostty_watch_pid=""
__ghostty_watch_gitdir=""

# Stop the current watcher (and any inotifywait child it spawned).
__ghostty_watch_stop() {
    if [ -n "$__ghostty_watch_pid" ]; then
        pkill -P "$__ghostty_watch_pid" 2>/dev/null
        kill "$__ghostty_watch_pid" 2>/dev/null
    fi
    __ghostty_watch_pid=""
    __ghostty_watch_gitdir=""
}

# Background loop (args: shell-pid tty git-dir repo-top). Blocks on HEAD changing
# (inotifywait, else polling), re-emits the title to $tty, and exits when the
# owning shell dies.
__ghostty_watch_loop() {
    local shellpid=$1 tty=$2 gitdir=$3 repo=$4
    local head="$gitdir/HEAD" last cur
    last=$(cat "$head" 2>/dev/null)
    while kill -0 "$shellpid" 2>/dev/null; do
        if command -v inotifywait >/dev/null 2>&1; then
            # Watch the git dir, not HEAD (checkout renames HEAD, losing the
            # inode). The 1s timeout doubles as a poll so we converge even when
            # the event fires before HEAD is rewritten, and re-checks the shell.
            inotifywait -q -t 1 -e modify,create,moved_to,close_write \
                "$gitdir" >/dev/null 2>&1
        else
            sleep 1
        fi
        cur=$(cat "$head" 2>/dev/null)
        [ "$cur" = "$last" ] && continue   # HEAD didn't actually change
        last=$cur
        printf '\033]0;%s\007' "$(__ghostty_title_string "$repo")" >"$tty" 2>/dev/null
    done
}

# Point the watcher at the current directory's repo, (re)starting it only when the
# repo changes; stop it when outside any repo.
__ghostty_watch_sync() {
    [ -n "$__ghostty_tty" ] || return       # no terminal to write to
    local gitdir
    gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null)
    if [ -z "$gitdir" ]; then
        __ghostty_watch_stop                # not in a repo anymore
        return
    fi
    # Already watching this repo with a live watcher? Nothing to do.
    if [ "$gitdir" = "$__ghostty_watch_gitdir" ] \
        && kill -0 "$__ghostty_watch_pid" 2>/dev/null; then
        return
    fi
    __ghostty_watch_stop
    local repo
    repo=$(git rev-parse --show-toplevel 2>/dev/null)
    __ghostty_watch_loop "$$" "$__ghostty_tty" "$gitdir" "$repo" &
    __ghostty_watch_pid=$!
    disown "$__ghostty_watch_pid" 2>/dev/null
    __ghostty_watch_gitdir="$gitdir"
}

__ghostty_set_title() {
    # --- one-time per shell: stop everything else from setting the title ---
    if [ -z "${__ghostty_title_fixed-}" ]; then
        # Strip Ghostty's cwd-title OSC escape from PS1 (PS1 renders after
        # PROMPT_COMMAND, so it would otherwise win).
        local _needle='\[\e]2;\w\a\]'
        PS1="${PS1//"$_needle"/}"

        # Disable Ghostty's preexec title feature so only we set the title.
        GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES/title/}"
        export GHOSTTY_SHELL_FEATURES

        # Drop leftover WezTerm precmd hooks that would also clobber the title.
        if [ -n "${precmd_functions+x}" ]; then
            local _pf=() _f
            for _f in "${precmd_functions[@]}"; do
                case $_f in __wezterm_*) ;; *) _pf+=("$_f") ;; esac
            done
            precmd_functions=("${_pf[@]}")
        fi

        __ghostty_title_fixed=1
    fi

    # --- set the title now, and keep the background watcher pointed here ---
    printf '\033]0;%s\007' "$(__ghostty_title_string)"
    __ghostty_watch_sync
}

# One-time at source time (fd 0 is still the terminal): record this shell's tty
# for the watcher and tear it down on exit. Done here, not in the prompt hook,
# since PROMPT_COMMAND often runs with stdin redirected so `tty` returns nothing.
if [ -z "${__ghostty_installed-}" ]; then
    __ghostty_tty=$(tty 2>/dev/null)
    case $__ghostty_tty in
        /dev/*) ;;
        *) __ghostty_tty="/dev/$(ps -o tty= -p $$ 2>/dev/null)" ;;  # fallback
    esac
    case $__ghostty_tty in /dev/pts/*|/dev/tty*) ;; *) __ghostty_tty="" ;; esac

    _prev_exit=$(trap -p EXIT)
    if [ -n "$_prev_exit" ]; then
        # Preserve any pre-existing EXIT trap by chaining ours in front.
        trap "__ghostty_watch_stop; ${_prev_exit#trap -- \'}" EXIT 2>/dev/null \
            || trap '__ghostty_watch_stop' EXIT
    else
        trap '__ghostty_watch_stop' EXIT
    fi
    unset _prev_exit
    __ghostty_installed=1
fi

# Install our hook so it runs every prompt, handling both the string and array
# forms of PROMPT_COMMAND (Ghostty/bash-preexec turn it into an array).
if declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare -a'; then
    __ghostty_present=0
    for __c in "${PROMPT_COMMAND[@]}"; do
        case $__c in *__ghostty_set_title*) __ghostty_present=1 ;; esac
    done
    [ "$__ghostty_present" = 0 ] && PROMPT_COMMAND+=(__ghostty_set_title)
    unset __c __ghostty_present
else
    case ";${PROMPT_COMMAND};" in
        *__ghostty_set_title*) ;;  # already installed
        *) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}__ghostty_set_title" ;;
    esac
fi
