# Migration Guide

This guide helps you migrate from standalone ghjk installation to asdf-ghjk.

## Table of Contents

- [Why Migrate](#why-migrate)
- [Before You Begin](#before-you-begin)
- [Migration Steps](#migration-steps)
- [Verification](#verification)
- [Rollback](#rollback)
- [Common Issues](#common-issues)

## Why Migrate

Migrating to asdf-ghjk provides:

- **Version Management**: Install and switch between multiple ghjk versions
- **Project-Specific Versions**: Different projects can use different ghjk versions
- **Consistent Tooling**: Use asdf for all your development tools
- **Easy Updates**: Simple commands to update to latest versions
- **Better CI/CD Integration**: Standard approach across projects

## Before You Begin

### Check Your Current Installation

```bash
# Find where ghjk is currently installed
which ghjk

# Check your current version
ghjk --version

# See if ghjk is managing other tools
ghjk env
```

### Backup Your Configuration

```bash
# Backup your ghjk configuration files
cp ghjk.ts ghjk.ts.backup

# Backup any environment configurations
cp .env .env.backup 2>/dev/null || true
```

### Prerequisites

Ensure you have:

1. **asdf installed** - [Installation guide](https://asdf-vm.com/guide/getting-started.html)
2. **System dependencies**: git, curl, tar
3. **Shell properly configured** for asdf

## Migration Steps

### Step 1: Note Your Current Version

```bash
# Record your current ghjk version
CURRENT_GHJK_VERSION=$(ghjk --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "Current version: $CURRENT_GHJK_VERSION"
```

### Step 2: Remove Standalone Installation

#### If Installed via Official Installer

```bash
# The official installer typically installs to one of these locations:
# - ~/.ghjk/
# - /usr/local/bin/ghjk
# - ~/bin/ghjk

# Check and remove
rm -rf ~/.ghjk
sudo rm -f /usr/local/bin/ghjk
rm -f ~/bin/ghjk
```

#### Clean Up Shell Profile

Remove ghjk-related lines from your shell profile:

```bash
# Edit your profile
nano ~/.bashrc  # or ~/.zshrc, ~/.bash_profile, etc.

# Remove lines like:
# export PATH="$HOME/.ghjk/bin:$PATH"
# source ~/.ghjk/env.sh
# etc.

# Reload your shell
source ~/.bashrc
```

### Step 3: Install asdf-ghjk Plugin

```bash
# Add the plugin
asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git

# Verify plugin was added
asdf plugin list | grep ghjk
```

### Step 4: Install Your Version

```bash
# Option A: Install the same version you were using
asdf install ghjk $CURRENT_GHJK_VERSION
asdf global ghjk $CURRENT_GHJK_VERSION

# Option B: Install latest stable
asdf install ghjk latest
asdf global ghjk latest

# Option C: Install specific version
asdf install ghjk 0.3.2
asdf global ghjk 0.3.2
```

### Step 5: Verify Installation

```bash
# Check that ghjk is available
which ghjk
# Should show: ~/.asdf/shims/ghjk

# Verify version
ghjk --version

# Test basic functionality
ghjk --help
```

### Step 6: Update Project Configuration

For each project using ghjk:

```bash
cd your-project

# Create .tool-versions file
echo "ghjk $CURRENT_GHJK_VERSION" > .tool-versions

# Or use asdf local command
asdf local ghjk $CURRENT_GHJK_VERSION

# Verify
cat .tool-versions
```

### Step 7: Test Your Projects

```bash
cd your-project

# Test ghjk commands
ghjk env
ghjk run <your-task>

# Verify everything works as before
```

## Project-by-Project Migration

If you have multiple projects, migrate them individually:

```bash
#!/bin/bash
# migrate-projects.sh

PROJECTS=(
  ~/projects/project-a
  ~/projects/project-b
  ~/projects/project-c
)

GHJK_VERSION="0.3.2"  # or use latest

for project in "${PROJECTS[@]}"; do
  if [ -f "$project/ghjk.ts" ]; then
    echo "Migrating $project..."
    cd "$project"

    # Create .tool-versions
    echo "ghjk $GHJK_VERSION" > .tool-versions

    # Test
    if ghjk --version &>/dev/null; then
      echo "✅ $project migrated successfully"
    else
      echo "❌ $project migration failed"
    fi
  fi
done
```

## Verification

### Verify asdf Setup

```bash
# Check asdf is working
asdf --version

# Check ghjk plugin
asdf plugin list | grep ghjk

# List installed ghjk versions
asdf list ghjk

# Check current version
asdf current ghjk
```

### Verify ghjk Functionality

```bash
# Basic commands should work
ghjk --version
ghjk --help

# Project commands should work
cd your-project
ghjk env
ghjk run <task>
```

### Verify PATH

```bash
# ghjk should come from asdf
which ghjk
# Expected: ~/.asdf/shims/ghjk

# Check it's executable
test -x "$(which ghjk)" && echo "✅ Executable" || echo "❌ Not executable"
```

## Rollback

If you need to revert the migration:

### Remove asdf-ghjk

```bash
# Uninstall all ghjk versions
asdf uninstall ghjk --all

# Remove plugin
asdf plugin remove ghjk
```

### Reinstall Standalone

```bash
# Use ghjk's official installer
curl -fsSL https://ghjk.deno.dev/install.sh | sh

# Or download specific version manually
# See: https://github.com/metatypedev/ghjk/releases
```

### Restore Configuration

```bash
# Restore backed up files
cp ghjk.ts.backup ghjk.ts
cp .env.backup .env 2>/dev/null || true

# Remove .tool-versions files if you added them
find ~/projects -name .tool-versions -exec grep -l "^ghjk" {} \; -delete
```

## Common Issues

### Issue: "ghjk: command not found" After Migration

**Cause**: Shell hasn't picked up asdf's shims

**Solution**:

```bash
# Reload shell configuration
source ~/.bashrc  # or ~/.zshrc

# Or restart your terminal

# Reshim asdf
asdf reshim
```

### Issue: Wrong Version Being Used

**Cause**: Version precedence confusion

**Solution**:

```bash
# Check which version is active and why
asdf current ghjk

# Set explicitly
asdf local ghjk 0.3.2   # For current project
asdf global ghjk 0.3.2  # For all projects
```

### Issue: ghjk Commands Failing

**Cause**: Missing runtime dependencies

**Solution**:

```bash
# Install ghjk runtime dependencies
# Ubuntu/Debian
sudo apt-get install git curl tar unzip zstd

# macOS
brew install git curl tar unzip zstd
```

### Issue: Different Behavior After Migration

**Cause**: Different version or configuration

**Solution**:

```bash
# Ensure exact same version
asdf install ghjk $OLD_VERSION
asdf global ghjk $OLD_VERSION

# Compare configurations
diff ghjk.ts ghjk.ts.backup
```

## Advanced Migration Scenarios

### Migrating from System Package

If ghjk was installed via package manager:

```bash
# Ubuntu/Debian
sudo apt-get remove ghjk

# Homebrew
brew uninstall ghjk

# Then follow standard migration steps
```

### Migrating CI/CD

Update your CI/CD configuration:

**Before (standalone ghjk):**

```yaml
- name: Install ghjk
  run: curl -fsSL https://ghjk.deno.dev/install.sh | sh
```

**After (asdf-ghjk):**

```yaml
- name: Install asdf
  uses: asdf-vm/actions/setup@v3

- name: Install ghjk
  run: |
    asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
    asdf install ghjk
```

### Migrating Docker

**Before:**

```dockerfile
RUN curl -fsSL https://ghjk.deno.dev/install.sh | sh
ENV PATH="/root/.ghjk/bin:${PATH}"
```

**After:**

```dockerfile
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0
ENV PATH="/root/.asdf/bin:/root/.asdf/shims:${PATH}"
RUN asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
COPY .tool-versions .
RUN asdf install
```

## Best Practices Post-Migration

### Use .tool-versions

Create `.tool-versions` in each project:

```
ghjk 0.3.2
nodejs 20.0.0
python 3.11.0
```

### Pin Versions in Version Control

```bash
# Commit .tool-versions to git
git add .tool-versions
git commit -m "chore: pin ghjk version"
```

### Document the Migration

Add to your project's README:

```markdown
## Development Setup

This project uses asdf for version management.

### Prerequisites
- [asdf](https://asdf-vm.com)

### Installation
\`\`\`bash
asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
asdf install  # Installs versions from .tool-versions
\`\`\`
```

### Team Communication

Inform your team:

```markdown
# Migration to asdf-ghjk

We've migrated from standalone ghjk to asdf-ghjk for better version management.

**Action Required:**
1. Install asdf: https://asdf-vm.com
2. Run: `asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git`
3. Run: `asdf install`

**Benefits:**
- Multiple ghjk versions supported
- Automatic version switching per project
- Consistent with other tools (Node.js, Python, etc.)
```

## Getting Help

If you encounter issues during migration:

1. Check the [troubleshooting guide](TROUBLESHOOTING.md)
2. Check the [FAQ](FAQ.md)
3. Open an [issue](https://github.com/Hyperpolymath/asdf-ghjk/issues)

## Success Checklist

- [ ] Standalone ghjk removed
- [ ] asdf-ghjk plugin installed
- [ ] Correct version(s) installed
- [ ] `which ghjk` points to asdf shims
- [ ] All projects have `.tool-versions`
- [ ] All projects tested and working
- [ ] CI/CD updated
- [ ] Team notified
- [ ] Documentation updated

---

**Migration complete!** You're now using asdf-ghjk for better version management.
