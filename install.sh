#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get the absolute directory of the current script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles from $DIR..."

# Create necessary directories
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.bashrc.d"
mkdir -p "$HOME/.local/bin"

# Function to safely create symlinks
create_symlink() {
    local source=$1
    local target=$2

    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            echo "Symlink for $(basename "$target") already exists."
        else
            echo "Symlink for $(basename "$target") points to a different location. Updating..."
            ln -sfn "$source" "$target"
        fi
    elif [ -e "$target" ]; then
        echo "Backing up existing $(basename "$target") to ${target}.bak..."
        mv "$target" "${target}.bak"
        ln -s "$source" "$target"
    else
        echo "Linking $source to $target..."
        ln -s "$source" "$target"
    fi
}

# ---------------------------------------------------------------------------
# Cross-distro package management
# ---------------------------------------------------------------------------
# Detect the system package manager and install packages by a *generic* name,
# mapping each to the right per-distro package. Supports Fedora/RHEL (dnf),
# Debian/Ubuntu (apt), Arch (pacman), openSUSE (zypper) and Alpine (apk), so the
# same install.sh brings up any Linux box.
PM=""
for m in dnf apt-get pacman zypper apk; do
    if command -v "$m" > /dev/null 2>&1; then
        PM="$m"
        break
    fi
done
# Short, stable key used in the package map below.
case "$PM" in
    apt-get) PMKEY="apt" ;;
    *)       PMKEY="$PM" ;;
esac

# generic-name -> "mgr:package" for every supported manager. A generic name with
# no entry for the current manager means "install manually" (reported, never
# fatal).
declare -A PKGMAP=(
    [neovim]="dnf:neovim apt:neovim pacman:neovim zypper:neovim apk:neovim"
    [imagemagick]="dnf:ImageMagick apt:imagemagick pacman:imagemagick zypper:ImageMagick apk:imagemagick"
    [ffmpeg]="dnf:ffmpeg-free apt:ffmpeg pacman:ffmpeg zypper:ffmpeg apk:ffmpeg"
    [ripgrep]="dnf:ripgrep apt:ripgrep pacman:ripgrep zypper:ripgrep apk:ripgrep"
    [nodejs]="dnf:nodejs apt:nodejs pacman:nodejs zypper:nodejs apk:nodejs"
    [npm]="dnf:nodejs-npm apt:npm pacman:npm zypper:npm apk:npm"
    [git]="dnf:git-core apt:git pacman:git zypper:git apk:git"
    [go]="dnf:golang apt:golang-go pacman:go zypper:go apk:go"
    [gh]="dnf:gh apt:gh pacman:github-cli zypper:gh apk:github-cli"
    [jq]="dnf:jq apt:jq pacman:jq zypper:jq apk:jq"
    [lazygit]="dnf:lazygit pacman:lazygit zypper:lazygit apk:lazygit"
    [gcc]="dnf:gcc apt:gcc pacman:gcc zypper:gcc apk:gcc"
    [gpp]="dnf:gcc-c++ apt:g++ pacman:gcc zypper:gcc-c++ apk:g++"
    [make]="dnf:make apt:make pacman:make zypper:make apk:make"
    [jdk]="dnf:java-21-openjdk-devel apt:default-jdk pacman:jdk-openjdk zypper:java-21-openjdk-devel apk:openjdk21"
    [jetbrains-mono]="dnf:jetbrains-mono-fonts apt:fonts-jetbrains-mono pacman:ttf-jetbrains-mono zypper:jetbrains-mono-fonts apk:font-jetbrains-mono-nerd"
)

# pkg_name <generic> -> distro package name for the current manager (or empty).
pkg_name() {
    local entry tok
    entry="${PKGMAP[$1]:-}"
    for tok in $entry; do
        if [ "${tok%%:*}" = "$PMKEY" ]; then
            echo "${tok#*:}"
            return 0
        fi
    done
    return 0
}

# pkg_install <package...> -> install via the detected manager.
pkg_install() {
    [ "$#" -eq 0 ] && return 0
    case "$PM" in
        dnf)     sudo dnf install -y "$@" ;;
        apt-get) sudo apt-get update -y && sudo apt-get install -y "$@" ;;
        pacman)  sudo pacman -S --needed --noconfirm "$@" ;;
        zypper)  sudo zypper install -y "$@" ;;
        apk)     sudo apk add "$@" ;;
        *)       return 1 ;;
    esac
}

echo "--- Installing packages (manager: ${PM:-none}) ---"
# Runtime dependencies, as "command:generic-package" pairs:
#   neovim                 -- the editor
#   ImageMagick (magick)   -- image.nvim renders images via the magick CLI
#   ffmpeg                 -- image.nvim extracts a video preview frame
#   ripgrep (rg)           -- telescope live-grep / general search
#   nodejs + npm           -- claudecode.nvim and many LSP/Mason servers
#   git                    -- gitsigns, diffview, git-conflict, neo-tree git
#   go                     -- builds msgme, todome, and the patched gh-dash
#                             (ghme) from their vendored source under dotfiles/
#   gh                     -- GitHub CLI; ghme wraps `gh dash`
#   jq                     -- ghme-comments parses the GitHub API with jq
#   lazygit                -- git TUI opened from nvim with <leader>gg
#                             (no Debian/Ubuntu apt package; install manually there)
#   cc + g++ + make        -- nvim-treesitter compiles each language parser from
#                             C/C++ on first use (:TSUpdate / auto_install). With
#                             no compiler, parsers silently fail to build and
#                             treesitter highlighting/indent is "missing".
#   javac (a JDK)          -- jdtls (Java LSP) and java-debug-adapter need a JDK
#                             to run; Mason can't make Java debugging work without
#                             one. Only installed if no `javac` is already on PATH
#                             (e.g. a sdkman-managed JDK already satisfies this).
# Each is installed only if its command is missing; failures are reported but
# never abort the script.
TOOLS=(
    "nvim:neovim"
    "magick:imagemagick"
    "ffmpeg:ffmpeg"
    "rg:ripgrep"
    "node:nodejs"
    "npm:npm"
    "git:git"
    "go:go"
    "gh:gh"
    "jq:jq"
    "lazygit:lazygit"
    "cc:gcc"
    "g++:gpp"
    "make:make"
    "javac:jdk"
)
if [ -n "$PM" ]; then
    missing=()
    for pair in "${TOOLS[@]}"; do
        cmd="${pair%%:*}"
        gen="${pair##*:}"
        if ! command -v "$cmd" > /dev/null 2>&1; then
            p="$(pkg_name "$gen")"
            if [ -n "$p" ]; then
                missing+=("$p")
            else
                echo "  no $PMKEY package mapping for '$gen' - install it manually"
            fi
        fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Installing missing packages: ${missing[*]}"
        pkg_install "${missing[@]}" || echo "  (some packages failed/skipped - install manually: ${missing[*]})"
    else
        echo "All required packages already installed."
    fi
else
    echo "  No supported package manager found. Install manually: ${TOOLS[*]%%:*}"
fi

echo "--- Installing fonts ---"
# JetBrains Mono is the terminal font (ghostty/config).
if fc-list 2>/dev/null | grep -qi "jetbrains mono"; then
    echo "JetBrains Mono already installed."
elif [ -n "$PM" ]; then
    p="$(pkg_name jetbrains-mono)"
    if [ -n "$p" ]; then
        echo "Installing JetBrains Mono ($p)..."
        pkg_install "$p" || echo "  (install failed/skipped - install '$p' manually)"
    else
        echo "  no JetBrains Mono package for $PMKEY - install it manually."
    fi
else
    echo "  No package manager - install JetBrains Mono manually."
fi

echo "--- Installing Ghostty terminal ---"
# Ghostty is in Fedora and Arch repos; elsewhere fall back to Flatpak or a manual
# note. Best-effort: never abort the script.
if command -v ghostty > /dev/null 2>&1; then
    echo "Ghostty already installed."
else
    case "$PM" in
        dnf)    sudo dnf install -y ghostty || true ;;
        pacman) sudo pacman -S --needed --noconfirm ghostty || true ;;
    esac
    if ! command -v ghostty > /dev/null 2>&1; then
        if command -v flatpak > /dev/null 2>&1; then
            echo "Installing Ghostty via Flatpak..."
            flatpak install -y flathub com.mitchellh.ghostty || echo "  (flatpak ghostty failed - see https://ghostty.org/download)"
        else
            echo "  Ghostty isn't packaged for $PMKEY. Install it from https://ghostty.org/download"
            echo "  (or 'flatpak install flathub com.mitchellh.ghostty')."
        fi
    fi
fi

echo "--- Installing bin commands ---"
# Personal CLI commands in dotfiles/bin -> ~/.local/bin, as SYMLINKS (not copies)
# so editing the live command edits the repo file directly and the change syncs
# across machines. This includes texera_start and the ghme toolchain (ghme,
# ghme-browser, ghme-checkout, ghme-comments, ghme-rebuild). msgme is a compiled
# binary, built separately below.
if [ -d "$DIR/bin" ]; then
    for script in "$DIR"/bin/*; do
        [ -f "$script" ] || continue
        name="$(basename "$script")"
        chmod +x "$script"
        create_symlink "$script" "$HOME/.local/bin/$name"
    done
fi

echo "--- Configuring Neovim ---"
create_symlink "$DIR/nvim" "$HOME/.config/nvim"

echo "--- Configuring Ghostty ---"
create_symlink "$DIR/ghostty" "$HOME/.config/ghostty"

echo "--- Configuring ghme (gh-dash) ---"
create_symlink "$DIR/gh-dash" "$HOME/.config/gh-dash"

echo "--- Configuring msgme ---"
# msgme reads ~/.config/msgme/config.yml. The committed config has a blank Slack
# token; set the real one via the SLACK_TOKEN env var (export it yourself, e.g.
# in ~/.bashrc). msgme prefers SLACK_TOKEN over the file, so no secret is ever
# committed to this public repo.
create_symlink "$DIR/msgme-config" "$HOME/.config/msgme"

echo "--- Configuring shell (Ghostty git-branch title) ---"
# ~/.bashrc.d/*.sh is auto-sourced by the loader below (Fedora's default
# ~/.bashrc already sources ~/.bashrc.d). This sets the Ghostty window title to
# the current git branch (see ghostty/config).
create_symlink "$DIR/bashrc.d/ghostty-title.sh" "$HOME/.bashrc.d/ghostty-title.sh"

echo "--- Ensuring ~/.bashrc loads ~/.local/bin and ~/.bashrc.d ---"
# Fedora's stock ~/.bashrc already puts ~/.local/bin on PATH and sources
# ~/.bashrc.d/*. On distros that don't (Debian/Ubuntu/Arch/Alpine), append an
# idempotent, marker-guarded block so the same setup works everywhere. Skip if
# ~/.bashrc already sources ~/.bashrc.d, to avoid double-sourcing.
BRC="$HOME/.bashrc"
touch "$BRC"
if grep -q '\.bashrc\.d' "$BRC"; then
    echo "  ~/.bashrc already sources ~/.bashrc.d"
else
    cat >> "$BRC" <<'EOF'

# --- dotfiles: PATH + ~/.bashrc.d loader (added by install.sh) ---
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
if [ -d "$HOME/.bashrc.d" ]; then
    for rc in "$HOME"/.bashrc.d/*.sh; do
        [ -r "$rc" ] && . "$rc"
    done
    unset rc
fi
EOF
    echo "  added PATH + ~/.bashrc.d loader to ~/.bashrc"
fi
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "  note: ~/.local/bin isn't on PATH in THIS shell - open a new shell or 'source ~/.bashrc'." ;;
esac

echo "--- Building msgme ---"
# msgme: a terminal dashboard for your messages (Slack/Outlook/Teams/Calendar).
# Source is vendored under dotfiles/msgme so it builds anywhere with Go.
if [ -d "$DIR/msgme" ]; then
    if command -v go > /dev/null 2>&1; then
        if ( cd "$DIR/msgme" && go build -o "$HOME/.local/bin/msgme" . ); then
            echo "Installed msgme to ~/.local/bin/msgme"
        else
            echo "  (msgme build failed - run 'cd $DIR/msgme && go build' to investigate)"
        fi
    else
        echo "  Go not installed - skipping msgme. Later: cd $DIR/msgme && go build -o ~/.local/bin/msgme ."
    fi
fi

echo "--- Building ghme (patched gh-dash) ---"
# ghme wraps `gh dash`. The full patched gh-dash source is vendored under
# dotfiles/ghme (like dotfiles/msgme), so it builds anywhere with Go: no upstream
# clone, no network, no patch step. ghme-rebuild compiles that source and installs
# it as the `gh dash` extension binary (creating the extension registration if
# needed). gh itself is only needed at runtime (auth + the keybinding commands).
if [ -d "$DIR/ghme" ] && [ -f "$DIR/ghme/go.mod" ]; then
    if command -v go > /dev/null 2>&1; then
        echo "  building the patched gh-dash binary (ghme-rebuild)..."
        GHME_SRC="$DIR/ghme" "$HOME/.local/bin/ghme-rebuild" || echo "  (ghme-rebuild failed - run 'GHME_SRC=$DIR/ghme ghme-rebuild' to investigate)"
    else
        echo "  Go not installed - skipping ghme. Later: GHME_SRC=$DIR/ghme ghme-rebuild"
    fi
    command -v gh > /dev/null 2>&1 || echo "  note: install gh (GitHub CLI) and 'gh auth login' so ghme can authenticate."
else
    echo "  no vendored source at $DIR/ghme - skipping ghme build."
fi

echo "--- Building todome ---"
# todome: a terminal todo tracker (add/edit/prioritize/complete tasks), built on
# the same Bubbletea/gh-dash look as msgme. Source is vendored under
# dotfiles/todome so it builds anywhere with Go. Tasks persist to
# ~/.local/share/todome/tasks.json; no config or login is needed.
if [ -d "$DIR/todome" ] && [ -f "$DIR/todome/go.mod" ]; then
    if command -v go > /dev/null 2>&1; then
        if ( cd "$DIR/todome" && go build -o "$HOME/.local/bin/todome" . ); then
            echo "Installed todome to ~/.local/bin/todome"
        else
            echo "  (todome build failed - run 'cd $DIR/todome && go build' to investigate)"
        fi
    else
        echo "  Go not installed - skipping todome. Later: cd $DIR/todome && go build -o ~/.local/bin/todome ."
    fi
fi

echo "--- Setting Ghostty as the default terminal ---"
# xdg-terminal-exec (used by GNOME/file managers) reads this list.
echo "com.mitchellh.ghostty.desktop" > "$HOME/.config/xdg-terminals.list"

echo "--- Installing Custom Desktop Applications ---"
for desktop_file in "$DIR"/custom_apps/*.desktop; do
    if [ -f "$desktop_file" ]; then
        filename=$(basename "$desktop_file")
        target="$HOME/.local/share/applications/$filename"

        echo "Processing $filename..."

        # Ensure we dynamically replace hardcoded paths found in earlier templates
        # Default user `matthew` and hardcoded dotfiles path are replaced with dynamic ones
        sed -e "s|/home/[^/]*/dotfiles|$DIR|g" \
            -e "s|/home/[^/]*|$HOME|g" \
            "$desktop_file" > "$target"

        # Give execution permissions just in case
        chmod +x "$target"
    fi
done

# Update desktop database so the applications appear in application launchers
if command -v update-desktop-database > /dev/null; then
    echo "Updating desktop database..."
    update-desktop-database "$HOME/.local/share/applications"
fi

echo "--- Setup Complete! ---"
