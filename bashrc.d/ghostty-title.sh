# Set the terminal title to the current git branch when inside a repo,
# otherwise fall back to the working directory (Ghostty's default-ish title).
#
# This is self-contained: it also neutralizes — in the current shell — the
# things that would otherwise clobber our title, so it works in already-open
# Ghostty windows WITHOUT restarting Ghostty. Just `source` this file.
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

    # --- set the title ---
    local title branch
    branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$branch" ] && git rev-parse --git-dir >/dev/null 2>&1; then
        # In a repo but detached HEAD (rebase, checkout of a commit/tag, etc.)
        branch=$(git rev-parse --short HEAD 2>/dev/null)
    fi

    if [ -n "$branch" ]; then
        title="$branch"
    else
        # Not in a git repo: mirror the default (current dir, ~ for $HOME).
        title="${PWD/#$HOME/~}"
    fi

    # OSC 0: set both the icon name and the window title.
    printf '\033]0;%s\007' "$title"
}

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
