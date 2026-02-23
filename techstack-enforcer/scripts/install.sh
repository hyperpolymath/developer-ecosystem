#!/bin/bash
# Techstack Enforcer - Installation Script
# Builds and installs the enforcer system-wide or per-user

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME/.local}"
INSTALL_GLOBAL="${INSTALL_GLOBAL:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${CYAN}${BOLD}========================================${RESET}"
echo -e "${CYAN}${BOLD}  Techstack Enforcer Installer${RESET}"
echo -e "${CYAN}${BOLD}========================================${RESET}"
echo ""

# Check for GNAT
if ! command -v gprbuild &> /dev/null; then
    echo -e "${RED}Error: gprbuild not found${RESET}"
    echo "Please install GNAT (Ada compiler):"
    echo "  - Fedora: sudo dnf install gcc-gnat gprbuild"
    echo "  - Ubuntu: sudo apt install gnat gprbuild"
    echo "  - macOS:  brew install gnat"
    exit 1
fi

echo -e "${GREEN}Found GNAT toolchain${RESET}"

# Check for GNATprove (optional, for SPARK verification)
if command -v gnatprove &> /dev/null; then
    echo -e "${GREEN}Found GNATprove - SPARK verification available${RESET}"
    HAS_SPARK=1
else
    echo -e "${YELLOW}GNATprove not found - skipping SPARK verification${RESET}"
    HAS_SPARK=0
fi

# Create directories
echo ""
echo -e "${CYAN}Creating directories...${RESET}"
mkdir -p "$PROJECT_DIR/obj"
mkdir -p "$PROJECT_DIR/bin"
mkdir -p "$INSTALL_PREFIX/bin"
mkdir -p "$INSTALL_PREFIX/share/techstack"
mkdir -p "$HOME/.config/techstack"

# Build
echo ""
echo -e "${CYAN}Building Techstack Enforcer...${RESET}"
cd "$PROJECT_DIR"

# Debug build first
echo "  Building debug version..."
gprbuild -P techstack_enforcer.gpr -XMODE=debug -j0 2>&1 | head -20

# SPARK verification (if available)
if [ "$HAS_SPARK" = "1" ]; then
    echo ""
    echo -e "${CYAN}Running SPARK verification...${RESET}"
    gnatprove -P techstack_enforcer.gpr --level=2 --mode=check 2>&1 | head -30 || true
fi

# Release build
echo ""
echo "  Building release version..."
gprbuild -P techstack_enforcer.gpr -XMODE=release -j0

# Install binaries
echo ""
echo -e "${CYAN}Installing binaries...${RESET}"
cp "$PROJECT_DIR/bin/techstack_main" "$INSTALL_PREFIX/bin/techstack-enforcer"
cp "$PROJECT_DIR/bin/techstack_tui_main" "$INSTALL_PREFIX/bin/techstack-tui"
cp "$PROJECT_DIR/bin/techstack_hook" "$INSTALL_PREFIX/bin/techstack-hook"
chmod +x "$INSTALL_PREFIX/bin/techstack-"*

# Install configuration
echo ""
echo -e "${CYAN}Installing configuration...${RESET}"
if [ ! -f "$HOME/.config/techstack/techstack.toml" ]; then
    cp "$PROJECT_DIR/config/techstack.toml" "$HOME/.config/techstack/"
    echo "  Installed default configuration"
else
    echo "  Configuration exists, skipping"
fi

# Install hooks
echo ""
echo -e "${CYAN}Installing git hooks...${RESET}"
cp "$PROJECT_DIR/scripts/hooks/"* "$INSTALL_PREFIX/share/techstack/"
chmod +x "$INSTALL_PREFIX/share/techstack/"*

# Create global git hook symlinks (optional)
if [ "$INSTALL_GLOBAL" = "1" ]; then
    echo ""
    echo -e "${CYAN}Setting up global git hooks...${RESET}"
    git config --global core.hooksPath "$INSTALL_PREFIX/share/techstack"
    echo "  Global hooks enabled"
fi

# Verify installation
echo ""
echo -e "${CYAN}Verifying installation...${RESET}"
if "$INSTALL_PREFIX/bin/techstack-enforcer" version &> /dev/null; then
    echo -e "${GREEN}  techstack-enforcer: OK${RESET}"
else
    echo -e "${RED}  techstack-enforcer: FAILED${RESET}"
fi

# Add to PATH reminder
if [[ ":$PATH:" != *":$INSTALL_PREFIX/bin:"* ]]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Add to your shell profile:${RESET}"
    echo ""
    echo "  export PATH=\"$INSTALL_PREFIX/bin:\$PATH\""
    echo ""
fi

echo ""
echo -e "${GREEN}${BOLD}========================================${RESET}"
echo -e "${GREEN}${BOLD}  Installation Complete!${RESET}"
echo -e "${GREEN}${BOLD}========================================${RESET}"
echo ""
echo "Commands:"
echo "  techstack-enforcer   - CLI for checking/auditing"
echo "  techstack-tui        - Interactive TUI for filter management"
echo ""
echo "Quick start:"
echo "  techstack-enforcer list           # View all filters"
echo "  techstack-enforcer audit .        # Audit current directory"
echo "  techstack-tui                     # Launch TUI"
echo ""
echo "Enable for a repository:"
echo "  cd /your/repo"
echo "  ln -s $INSTALL_PREFIX/share/techstack/pre-commit .git/hooks/"
echo "  ln -s $INSTALL_PREFIX/share/techstack/pre-push .git/hooks/"
echo ""
echo "Or enable globally:"
echo "  git config --global core.hooksPath $INSTALL_PREFIX/share/techstack"
echo ""
