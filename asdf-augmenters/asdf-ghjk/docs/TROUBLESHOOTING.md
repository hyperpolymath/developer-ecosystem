# Troubleshooting Guide

This guide helps you resolve common issues with asdf-ghjk.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Download Failures](#download-failures)
- [GitHub API Issues](#github-api-issues)
- [Platform Issues](#platform-issues)
- [Runtime Issues](#runtime-issues)
- [Version Management](#version-management)
- [Debug Mode](#debug-mode)

## Installation Issues

### Error: "curl: command not found"

**Cause:** curl is not installed on your system.

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get install curl

# macOS
brew install curl

# Fedora/RHEL
sudo dnf install curl
```

### Error: "tar: command not found"

**Cause:** tar is not installed on your system.

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get install tar

# macOS (should be pre-installed)
brew install gnu-tar

# Fedora/RHEL
sudo dnf install tar
```

### Error: "Archive not found"

**Cause:** The download step failed or was skipped.

**Solution:**

```bash
# Download explicitly first
asdf download ghjk <version>

# Then install
asdf install ghjk <version>
```

### Error: "ghjk binary not found after extraction"

**Cause:** The archive structure changed or extraction failed.

**Solution:**

```bash
# Enable debug mode
export ASDF_DEBUG=1

# Try installing again
asdf install ghjk <version>

# Check the extracted contents
ls -la ~/.asdf/installs/ghjk/<version>/
```

## Download Failures

### Error: "Failed to download after 3 attempts"

**Cause:** Network issues or GitHub is down.

**Solution:**

1. Check your internet connection:

```bash
ping github.com
```

2. Check GitHub status: https://www.githubstatus.com/

3. Try with a different network

4. Wait a few minutes and try again

### Error: "Checksum verification failed"

**Cause:** Downloaded file is corrupted.

**Solution:**

```bash
# Remove the corrupted download
rm -rf ~/.asdf/downloads/ghjk/<version>

# Try downloading again
asdf install ghjk <version>
```

## GitHub API Issues

### Error: "GitHub API rate limit exceeded"

**Cause:** GitHub limits unauthenticated API requests to 60 per hour.

**Solution:**

Create a GitHub personal access token and set it:

```bash
# 1. Create token at https://github.com/settings/tokens
# 2. No special permissions needed for public repos
# 3. Add to your shell profile (~/.bashrc, ~/.zshrc, etc.):
export GITHUB_API_TOKEN="ghp_your_token_here"

# 4. Reload your shell
source ~/.bashrc  # or ~/.zshrc
```

### Error: "GitHub API request failed with status code: 403"

**Cause:** Rate limit or authentication issue.

**Solution:**

Check your rate limit:

```bash
curl -H "Authorization: token $GITHUB_API_TOKEN" \
  https://api.github.com/rate_limit
```

If using a token, verify it's valid:
- Go to https://github.com/settings/tokens
- Check if your token is still active
- Generate a new one if needed

## Platform Issues

### Error: "Unsupported operating system"

**Cause:** Your OS is not supported by ghjk.

**Supported Platforms:**
- Linux (x86_64, aarch64)
- macOS (x86_64, arm64)

**Check your platform:**

```bash
uname -s  # Should be: Linux or Darwin
uname -m  # Should be: x86_64, aarch64, or arm64
```

### Error: "Unsupported architecture"

**Cause:** Your CPU architecture is not supported.

**Solution:**

ghjk currently only supports:
- x86_64 (Intel/AMD 64-bit)
- aarch64/arm64 (ARM 64-bit)

32-bit systems and other architectures are not supported.

## Runtime Issues

### Error: "ghjk: command not found"

**Cause:** asdf shims not in PATH or ghjk not installed.

**Solution:**

1. Verify ghjk is installed:

```bash
asdf list ghjk
```

2. Check that asdf is properly set up:

```bash
# Should show ghjk version
asdf current ghjk

# If not, add asdf to your PATH
# See: https://asdf-vm.com/guide/getting-started.html
```

3. Reshim if necessary:

```bash
asdf reshim ghjk
```

### Warning: "Missing recommended runtime dependencies"

**Cause:** ghjk needs additional tools to function properly.

**Required Dependencies:**
- git
- curl
- tar
- unzip
- zstd

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get install git curl tar unzip zstd

# macOS
brew install git curl tar unzip zstd

# Fedora/RHEL
sudo dnf install git curl tar unzip zstd
```

### Error: "ghjk init ts fails"

**Cause:** Missing Deno or other ghjk dependencies.

**Solution:**

1. Verify ghjk is working:

```bash
ghjk --version
```

2. Check ghjk documentation for additional requirements:

```bash
ghjk --help
```

3. Try installing Deno (ghjk's runtime):

```bash
# ghjk should handle this, but you can install manually
curl -fsSL https://deno.land/install.sh | sh
```

## Version Management

### Error: "Version not found: latest"

**Cause:** `latest` keyword resolution failed.

**Solution:**

Use a specific version instead:

```bash
# List all versions
asdf list all ghjk

# Install a specific version
asdf install ghjk 0.3.2
```

### Error: "No such version: X.Y.Z"

**Cause:** The version doesn't exist or hasn't been released yet.

**Solution:**

Check available versions:

```bash
asdf list all ghjk
```

### Multiple versions installed but wrong one is active

**Cause:** Version precedence issues.

**asdf Version Precedence (highest to lowest):**
1. `ASDF_GHJK_VERSION` environment variable
2. `.tool-versions` in current directory
3. `.tool-versions` in parent directories
4. `~/.tool-versions` (global)

**Solution:**

```bash
# Check which version is active and why
asdf current ghjk

# Set local version
asdf local ghjk 0.3.2

# Set global version
asdf global ghjk 0.3.2

# Use specific version for one command
ASDF_GHJK_VERSION=0.3.1 ghjk --version
```

## Debug Mode

### Enable Verbose Output

For detailed debugging information:

```bash
# Enable asdf debug mode
export ASDF_DEBUG=1

# Run your command
asdf install ghjk latest

# Check asdf logs
cat ~/.asdf/tmp/*/install-ghjk-*.log
```

### Manual Script Testing

Test plugin scripts directly:

```bash
# Test list-all
./bin/list-all

# Test download
export ASDF_INSTALL_VERSION="0.3.2"
export ASDF_DOWNLOAD_PATH="/tmp/test-download"
export ASDF_INSTALL_PATH="/tmp/test-install"
mkdir -p "$ASDF_DOWNLOAD_PATH" "$ASDF_INSTALL_PATH"

./bin/download
./bin/install

# Check result
ls -la /tmp/test-install/
/tmp/test-install/bin/ghjk --version

# Clean up
rm -rf /tmp/test-*
```

## Getting More Help

### Check Logs

asdf creates logs for installations:

```bash
# Find recent logs
ls -lt ~/.asdf/tmp/

# View a specific log
cat ~/.asdf/tmp/<timestamp>/install-ghjk-<version>.log
```

### Verify Plugin Installation

```bash
# List installed plugins
asdf plugin list

# Check plugin repository
asdf plugin list --urls

# Re-add plugin if needed
asdf plugin remove ghjk
asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
```

### Common Solutions

1. **Update asdf:**

```bash
asdf update
```

2. **Update the plugin:**

```bash
asdf plugin update ghjk
```

3. **Reshim:**

```bash
asdf reshim ghjk
```

4. **Clean cache:**

```bash
rm -rf ~/.asdf/downloads/ghjk
rm -rf ~/.asdf/tmp/*
```

### Report an Issue

If none of these solutions work:

1. Gather information:

```bash
# System info
uname -a
bash --version
asdf --version

# Plugin version
cd ~/.asdf/plugins/ghjk && git log -1 --oneline

# Error output with debug enabled
ASDF_DEBUG=1 asdf install ghjk <version> 2>&1 | tee error.log
```

2. Open an issue: https://github.com/Hyperpolymath/asdf-ghjk/issues/new

Include:
- System information
- Error messages
- Steps to reproduce
- What you've already tried

## Additional Resources

- **asdf Documentation:** https://asdf-vm.com
- **ghjk Documentation:** https://github.com/metatypedev/ghjk
- **Plugin README:** https://github.com/Hyperpolymath/asdf-ghjk
- **GitHub Issues:** https://github.com/Hyperpolymath/asdf-ghjk/issues
