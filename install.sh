#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get the absolute directory of the current script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up dotfiles from $DIR..."

# Create necessary directories
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/share/applications"

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

echo "--- Configuring Neovim ---"
create_symlink "$DIR/nvim" "$HOME/.config/nvim"

echo "--- Configuring WezTerm ---"
create_symlink "$DIR/wezterm" "$HOME/.config/wezterm"

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
