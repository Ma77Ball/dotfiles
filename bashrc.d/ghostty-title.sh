# Set the terminal title to the current git branch when inside a repo,
# otherwise fall back to the working directory (Ghostty's default-ish title).
#
# The prompt hook (__ghostty_set_title) refreshes the title every time a new
# prompt is drawn. On its own that only catches branch changes you make AT the
# prompt — if the branch changes while a foreground program is running (an
# editor, a dev server, `claude` doing checkouts, another pane in the same
# repo...) no prompt is drawn, so the title goes stale until you hit Enter.
#
# To update "anytime the branch changes", a per-shell background watcher tails
# the repo's .git/HEAD (whose contents flip on every branch switch / detach)
# and pushes the new title straight to this shell's terminal between prompts.
#
# This is self-contained: it also neutralizes — in the current shell — the
# things that would otherwise clobber our title, so it works in already-open
# Ghostty windows WITHOUT restarting Ghostty. Just `source` this file.

# Compute the title for a given directory ($1, default $PWD): the git branch
# (or short SHA when detached), else the directory with $HOME shortened to ~.
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
# State (per shell). The watcher PID and the git dir it is currently watching.
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

# The loop that runs in the background. Args: shell-pid tty git-dir repo-top.
# It blocks on HEAD changing (event-driven via inotifywait, else polling) and
# re-emits the title to $tty. It also re-checks that the owning shell is still
# alive each iteration, so it cleans itself up if the shell is killed (-9) and
# the EXIT trap never runs.
__ghostty_watch_loop() {
    local shellpid=$1 tty=$2 gitdir=$3 repo=$4
    local head="$gitdir/HEAD" last cur
    last=$(cat "$head" 2>/dev/null)
    while kill -0 "$shellpid" 2>/dev/null; do
        if command -v inotifywait >/dev/null 2>&1; then
            # Watch the git dir (HEAD is replaced via rename on checkout, so
            # watching the file directly would lose the inode). A checkout fires
            # several events (index, HEAD, ORIG_HEAD...) and this one-shot wait
            # returns on the first, which may be before HEAD is rewritten — so
            # the short 1s timeout also serves as a poll that reliably converges
            # to the current branch, and as a chance to re-check the shell.
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

# Point the watcher at the repo for the current directory, (re)starting it only
# when the repo actually changes. Stops the watcher when outside any repo.
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
        # Ghostty's "title" shell feature appends an OSC-2 escape to PS1 that
        # prints the cwd as the title — and PS1 renders AFTER PROMPT_COMMAND, so
        # nothing in PROMPT_COMMAND can beat it. Strip that escape out of PS1.
        local _needle='\[\e]2;\w\a\]'
        PS1="${PS1//"$_needle"/}"

        # Ghostty's preexec sets the title to the running command; it checks for
        # "title" in this var. Remove it so only we touch the title.
        GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES/title/}"
        export GHOSTTY_SHELL_FEATURES

        # Drop any leftover WezTerm precmd hooks (OSC user-vars / osc7) that were
        # loaded by /etc/profile.d/wezterm.sh before we could skip it.
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

# One-time, at source time (when fd 0 is still the terminal): remember this
# shell's tty so the background watcher knows where to write, and tear the
# watcher down when the shell exits. Doing this here rather than inside the
# prompt hook matters — PROMPT_COMMAND often runs with stdin redirected away
# from the terminal, so `tty` there returns nothing.
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
