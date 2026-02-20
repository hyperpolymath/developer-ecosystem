#!/bin/bash
# Install techstack hooks to a specific repository or all repos in a directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"
TARGET="${1:-.}"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

install_hooks() {
    local repo="$1"
    local hooks_path="$repo/.git/hooks"

    if [ ! -d "$hooks_path" ]; then
        echo -e "${YELLOW}  Skipping $repo (not a git repo)${RESET}"
        return
    fi

    for hook in pre-commit pre-push commit-msg; do
        if [ -f "$HOOKS_DIR/$hook" ]; then
            # Backup existing hook
            if [ -f "$hooks_path/$hook" ] && [ ! -L "$hooks_path/$hook" ]; then
                mv "$hooks_path/$hook" "$hooks_path/$hook.backup"
            fi

            # Create symlink
            ln -sf "$HOOKS_DIR/$hook" "$hooks_path/$hook"
            echo -e "${GREEN}  Installed $hook -> $repo${RESET}"
        fi
    done
}

echo -e "${CYAN}Installing techstack hooks...${RESET}"

if [ -d "$TARGET/.git" ]; then
    # Single repository
    install_hooks "$TARGET"
else
    # Directory of repositories
    find "$TARGET" -type d -name ".git" -prune | while read -r git_dir; do
        repo_dir="$(dirname "$git_dir")"
        install_hooks "$repo_dir"
    done
fi

echo -e "${GREEN}Done!${RESET}"
