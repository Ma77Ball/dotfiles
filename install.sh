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

echo "--- Installing packages ---"
# Runtime dependencies this environment relies on, as "command:dnf-package" pairs.
# Package names are the Fedora ones the current machine actually uses.
#   neovim                       -- the editor
#   ghostty                      -- terminal emulator (the default terminal, below)
#   ImageMagick (magick)         -- image.nvim renders images via the magick CLI
#   ffmpeg-free (ffmpeg)         -- image.nvim extracts a video preview frame
#   ripgrep (rg)                 -- telescope live-grep / general search
#   nodejs + npm                 -- claudecode.nvim and many LSP/Mason servers
#   git-core (git)               -- gitsigns, diffview, git-conflict, neo-tree git
# Each is installed only if its command is missing; a failure (repo not enabled,
# no dnf, etc.) is reported but never aborts the script.
PACKAGES=(
    "nvim:neovim"
    "ghostty:ghostty"
    "magick:ImageMagick"
    "ffmpeg:ffmpeg-free"
    "rg:ripgrep"
    "node:nodejs"
    "npm:nodejs-npm"
    "git:git-core"
)
if command -v dnf > /dev/null 2>&1; then
    missing=()
    for pair in "${PACKAGES[@]}"; do
        cmd="${pair%%:*}"
        pkg="${pair##*:}"
        command -v "$cmd" > /dev/null 2>&1 || missing+=("$pkg")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Installing missing packages: ${missing[*]}"
        sudo dnf install -y "${missing[@]}" || echo "  (some packages failed/skipped — install manually: ${missing[*]})"
    else
        echo "All required packages already installed."
    fi
else
    echo "  dnf not found — install manually: ${PACKAGES[*]//:/ -> }"
    echo "  (wezterm, if you still want it, is not in the default repos — use the wezfurlong copr.)"
fi

echo "--- Installing fonts ---"
# JetBrains Mono is the terminal font (ghostty/config). Install only if missing, and
# never abort the script if dnf is absent or the install fails.
if fc-list 2>/dev/null | grep -qi "jetbrains mono"; then
    echo "JetBrains Mono already installed."
elif command -v dnf > /dev/null 2>&1; then
    echo "Installing JetBrains Mono..."
    sudo dnf install -y jetbrains-mono-fonts || echo "  (install failed/skipped — install 'jetbrains-mono-fonts' manually)"
else
    echo "  dnf not found — install JetBrains Mono manually (package: jetbrains-mono-fonts)."
fi

echo "--- Configuring Neovim ---"
create_symlink "$DIR/nvim" "$HOME/.config/nvim"

echo "--- Configuring Ghostty ---"
create_symlink "$DIR/ghostty" "$HOME/.config/ghostty"

echo "--- Configuring shell (Ghostty git-branch title) ---"
# ~/.bashrc.d/*.sh is auto-sourced by the Fedora default ~/.bashrc. This script
# sets the Ghostty window title to the current git branch (see ghostty/config).
create_symlink "$DIR/bashrc.d/ghostty-title.sh" "$HOME/.bashrc.d/ghostty-title.sh"

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
