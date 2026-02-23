# Quick Start Guide

Get up and running with Techstack Enforcer in minutes.

## Prerequisites

- GNAT Ada compiler (with GPRbuild)
- Git (for hooks integration)

### Installing GNAT

```bash
# Fedora/RHEL
sudo dnf install gcc-gnat gprbuild

# Ubuntu/Debian
sudo apt install gnat gprbuild

# macOS (Homebrew)
brew install gnat

# Alire (Ada package manager - recommended)
curl -L https://alire.ada.dev/install.sh | bash
alr toolchain --select
```

## Installation

### Option 1: Quick Install Script

```bash
git clone https://github.com/hyperpolymath/techstack-enforcer.git
cd techstack-enforcer
./scripts/install.sh
```

### Option 2: Manual Build

```bash
git clone https://github.com/hyperpolymath/techstack-enforcer.git
cd techstack-enforcer

# Create directories
mkdir -p obj bin

# Build release version
gprbuild -P techstack_enforcer.gpr -XMODE=release -j0

# Binaries are in ./bin/
```

## First Steps

### 1. Audit Your Repository

```bash
# Check current directory
./bin/techstack_main audit .

# Check specific path
./bin/techstack_main audit /path/to/repo
```

### 2. Choose a Definition Set

```bash
# List available definition sets
./bin/techstack_main defsets

# Use strict enforcement
./bin/techstack_main --defset=strict audit .

# Use balanced enforcement
./bin/techstack_main --defset=moderate audit .
```

### 3. Get JSON Decisions

```bash
# Single file
./bin/techstack_main decide src/main.py

# Multiple files from stdin
echo -e "file1.py\nfile2.rs" | ./bin/techstack_main decide
```

### 4. Launch the TUI

```bash
./bin/techstack_tui_main
```

### 5. Install Git Hooks

```bash
# For a single repository
cd /your/repo
ln -sf /path/to/techstack/scripts/hooks/pre-commit .git/hooks/
ln -sf /path/to/techstack/scripts/hooks/pre-push .git/hooks/

# Or use the installer
./scripts/install-repo-hooks.sh /your/repo
```

## Next Steps

- [CLI Reference](./cli-reference.md) - All commands and options
- [Definition Sets](./definition-sets.md) - Pre-configured policies
- [CI Integration](./ci-integration.md) - Add to your pipeline
