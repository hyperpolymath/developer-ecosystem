# Quick Start Guide

Get up and running with asdf-ghjk in 5 minutes.

## Prerequisites

Before you begin, install:

1. **asdf** - [Installation guide](https://asdf-vm.com/guide/getting-started.html)
2. **System dependencies**: git, curl, tar

```bash
# Ubuntu/Debian
sudo apt-get install git curl tar

# macOS
brew install git curl tar
```

## Installation (30 seconds)

```bash
# 1. Add the plugin
asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git

# 2. Install latest version
asdf install ghjk latest

# 3. Set as default
asdf global ghjk latest

# 4. Verify
ghjk --version
```

Done! 🎉

## Your First ghjk Project (2 minutes)

```bash
# 1. Create a new project
mkdir my-project
cd my-project

# 2. Pin ghjk version for this project
asdf local ghjk latest

# 3. Initialize ghjk
ghjk init ts

# 4. View the generated config
cat ghjk.ts
```

You now have a `ghjk.ts` configuration file!

## Basic Configuration (1 minute)

Edit `ghjk.ts`:

```typescript
export { sophon } from "https://deno.land/x/ghjk/mod.ts";

sophon({
  // Environment variables
  env: {
    NODE_ENV: "development",
  },

  // Tools to install
  installs: [
    { name: "node", version: "20.0.0" },
  ],

  // Tasks you can run
  tasks: {
    dev: "npm run dev",
    test: "npm test",
    build: "npm run build",
  },
});
```

## Running Tasks (30 seconds)

```bash
# Activate environment
ghjk env

# Or run tasks directly
ghjk run dev
ghjk run test
ghjk run build
```

## Common Commands (30 seconds)

```bash
# List all available ghjk versions
asdf list all ghjk

# Install a specific version
asdf install ghjk 0.3.2

# Switch versions
asdf global ghjk 0.3.2     # All projects
asdf local ghjk 0.3.1      # Current project only
asdf shell ghjk 0.3.0      # Current shell only

# See what's installed
asdf list ghjk

# See current version
asdf current ghjk

# Update to latest
asdf install ghjk latest && asdf global ghjk latest
```

## Troubleshooting (30 seconds)

### "ghjk: command not found"

```bash
# Reshim asdf
asdf reshim ghjk

# Or add asdf to your PATH (if not already)
echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc
source ~/.bashrc
```

### "GitHub API rate limit exceeded"

```bash
# Create a token at: https://github.com/settings/tokens
export GITHUB_API_TOKEN="ghp_your_token_here"

# Add to your shell profile to make permanent
echo 'export GITHUB_API_TOKEN="ghp_..."' >> ~/.bashrc
```

### Need more help?

- [Full Documentation](../README.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [FAQ](FAQ.md)

## Next Steps

Now that you're set up, explore:

1. **[Examples](EXAMPLES.md)** - Real-world usage patterns
2. **[ghjk Docs](https://github.com/metatypedev/ghjk)** - Learn more about ghjk
3. **[asdf Docs](https://asdf-vm.com)** - Master asdf version management

## Quick Reference Card

```bash
# Plugin Management
asdf plugin add ghjk <url>     # Add plugin
asdf plugin update ghjk        # Update plugin
asdf plugin remove ghjk        # Remove plugin

# Version Installation
asdf install ghjk latest       # Install latest
asdf install ghjk 0.3.2        # Install specific version
asdf uninstall ghjk 0.3.1      # Remove version

# Version Selection
asdf global ghjk <version>     # Set global default
asdf local ghjk <version>      # Set for current directory
asdf shell ghjk <version>      # Set for current shell

# Information
asdf list all ghjk             # All available versions
asdf list ghjk                 # Installed versions
asdf current ghjk              # Active version
asdf where ghjk                # Installation path

# Maintenance
asdf reshim ghjk               # Rebuild shims
asdf update                    # Update asdf itself
```

---

**Ready to dive deeper?** Check out the [full documentation](../README.md)!
