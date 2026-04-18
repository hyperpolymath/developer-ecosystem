# Frequently Asked Questions (FAQ)

Common questions about asdf-ghjk.

## General Questions

### What is asdf-ghjk?

asdf-ghjk is an [asdf](https://asdf-vm.com) plugin that allows you to install and manage [ghjk](https://github.com/metatypedev/ghjk) versions using asdf's version management system.

### What is ghjk?

ghjk is a modern development environment manager that provides:
- Unified package management across multiple ecosystems (npm, PyPI, crates.io, etc.)
- TypeScript-based task automation
- Reproducible POSIX shell environments
- Declarative configuration with inheritance

Think of it as a successor to asdf with additional capabilities.

### Why use asdf-ghjk instead of installing ghjk directly?

Using asdf-ghjk provides:
- **Version Management**: Install and switch between multiple ghjk versions
- **Project-Specific Versions**: Different projects can use different ghjk versions
- **Consistent Tooling**: Use the same version management approach for all your tools
- **Easy Updates**: Simple commands to update to the latest version
- **No Global Installation**: Avoids system-wide installation conflicts

### Is this an official plugin?

No, this is a community-maintained plugin. For official ghjk support, refer to the [ghjk repository](https://github.com/metatypedev/ghjk).

## Installation Questions

### How do I install the plugin?

```bash
asdf plugin add ghjk https://github.com/Hyperpolymath/asdf-ghjk.git
asdf install ghjk latest
asdf global ghjk latest
```

### Do I need to install asdf first?

Yes! This is an asdf plugin, so you need asdf installed first. Get it from [asdf-vm.com](https://asdf-vm.com).

### What are the system requirements?

**Required:**
- Bash 4.0+
- curl
- tar
- grep, sort

**For ghjk runtime:**
- git
- curl
- tar
- unzip
- zstd

### Which platforms are supported?

- Linux (x86_64, aarch64)
- macOS (x86_64, arm64/Apple Silicon)

Windows is not currently supported (but may work with WSL).

### Can I install ghjk without root/sudo access?

Yes! asdf and this plugin install everything in your home directory (~/.asdf/). No root access required.

## Usage Questions

### How do I install a specific version?

```bash
asdf install ghjk 0.3.2
asdf global ghjk 0.3.2
```

### How do I update to the latest version?

```bash
asdf install ghjk latest
asdf global ghjk latest
```

### How do I switch between versions?

```bash
# Set global version (all shells)
asdf global ghjk 0.3.2

# Set local version (current directory)
asdf local ghjk 0.3.1

# Use for single command
asdf shell ghjk 0.3.0 -- ghjk --version
```

### How do I uninstall a version?

```bash
asdf uninstall ghjk 0.3.1
```

### How do I list installed versions?

```bash
# Installed versions
asdf list ghjk

# All available versions
asdf list all ghjk

# Current version
asdf current ghjk
```

## Troubleshooting Questions

### Why am I getting "GitHub API rate limit exceeded"?

GitHub limits unauthenticated API requests to 60 per hour. Set `GITHUB_API_TOKEN` to increase the limit:

```bash
export GITHUB_API_TOKEN="ghp_your_token_here"
```

Create a token at [GitHub Settings](https://github.com/settings/tokens). No special permissions needed.

### Why is "ghjk: command not found"?

Make sure asdf is properly configured:

```bash
# Check asdf is in PATH
which asdf

# Check ghjk is installed
asdf list ghjk

# Reshim if needed
asdf reshim ghjk
```

Add to your shell profile if needed:

```bash
# For bash
echo '. $HOME/.asdf/asdf.sh' >> ~/.bashrc

# For zsh
echo '. $HOME/.asdf/asdf.sh' >> ~/.zshrc
```

### Downloads are failing. What should I do?

1. Check your internet connection
2. Check GitHub is accessible: `curl -I https://github.com`
3. Try with debug mode: `ASDF_DEBUG=1 asdf install ghjk <version>`
4. Check the [troubleshooting guide](TROUBLESHOOTING.md)

### How do I enable debug mode?

```bash
export ASDF_DEBUG=1
asdf install ghjk <version>
```

### Where are the logs?

```bash
# asdf creates temporary logs
ls -lt ~/.asdf/tmp/

# View a specific log
cat ~/.asdf/tmp/<timestamp>/install-ghjk-<version>.log
```

## Version Management Questions

### What does "latest" mean?

"latest" refers to the most recent stable release of ghjk, as published on GitHub releases.

### Can I install pre-release versions?

Yes, pre-release versions (alpha, beta, rc) are available:

```bash
asdf list all ghjk  # Shows all versions including pre-releases
asdf install ghjk 0.3.1-rc.2
```

### Can I install from a Git commit or branch?

Currently, no. The plugin only supports installing released versions. This is intentional for stability.

### How do I pin a version for my project?

Create a `.tool-versions` file:

```bash
echo "ghjk 0.3.2" > .tool-versions
```

When anyone with asdf enters this directory, that version will be used.

### Can I use multiple versions simultaneously?

Each shell session uses one version at a time, determined by:
1. `ASDF_GHJK_VERSION` environment variable
2. `.tool-versions` in current directory
3. `.tool-versions` in parent directories
4. `~/.tool-versions` (global)

You can run different versions in different terminals.

## Technical Questions

### Where are versions installed?

```bash
~/.asdf/installs/ghjk/<version>/
```

### Where are downloads cached?

```bash
~/.asdf/downloads/ghjk/<version>/
```

### How are checksums verified?

The plugin extracts SHA256 checksums from GitHub release metadata and verifies downloaded files. If no checksum is available, a warning is shown but installation continues.

### Can I install from a mirror or alternative source?

Not currently. The plugin only downloads from official GitHub releases at `github.com/metatypedev/ghjk`.

### How does platform detection work?

The plugin uses `uname -s` and `uname -m` to detect your OS and architecture, then maps to ghjk's platform naming:
- Linux x86_64 → `x86_64-unknown-linux-gnu`
- Linux aarch64 → `aarch64-unknown-linux-gnu`
- macOS x86_64 → `x86_64-apple-darwin`
- macOS arm64 → `aarch64-apple-darwin`

### Is the plugin regularly updated?

Updates are made as needed to support new ghjk versions, fix bugs, or add features. The plugin itself doesn't need frequent updates since it downloads ghjk releases dynamically.

## Integration Questions

### Can I use this in CI/CD?

Yes! See the [examples documentation](EXAMPLES.md) for GitHub Actions, GitLab CI, and CircleCI examples.

### Can I use this with Docker?

Yes! Install asdf and the plugin in your Dockerfile. See [examples](EXAMPLES.md#docker-integration).

### Does this work with direnv?

Yes, asdf integrates with direnv. Configure direnv to use asdf versions.

### Can I use this with other asdf plugins?

Absolutely! That's the whole point of asdf. You can manage ghjk, Node.js, Python, Ruby, etc., all with asdf.

## Development Questions

### How can I contribute?

See [CONTRIBUTING.md](../CONTRIBUTING.md) for contribution guidelines.

### How do I test my changes?

```bash
# Set up development environment
./scripts/setup-dev.sh

# Run tests
./scripts/test.sh

# Or use Make
make test
```

### How do I report bugs?

Open an issue on [GitHub](https://github.com/Hyperpolymath/asdf-ghjk/issues) using the bug report template.

### How do I request features?

Open an issue on [GitHub](https://github.com/Hyperpolymath/asdf-ghjk/issues) using the feature request template.

## Comparison Questions

### How is this different from using ghjk's installer?

| Aspect | ghjk Installer | asdf-ghjk |
|--------|----------------|-----------|
| Version Management | Single global version | Multiple versions |
| Switching Versions | Manual reinstall | `asdf global/local` |
| Project-Specific | Manual per-project | Automatic via `.tool-versions` |
| Updates | Manual download | `asdf install ghjk latest` |
| Tool Ecosystem | Standalone | Part of asdf ecosystem |

### Should I use asdf-ghjk or standalone ghjk?

**Use asdf-ghjk if:**
- You already use asdf for other tools
- You need multiple ghjk versions
- You want project-specific versions
- You want consistent version management

**Use standalone ghjk if:**
- You only need one ghjk version
- You don't use asdf
- You prefer ghjk's native installation

### Can I use both?

Not recommended. Stick with one installation method to avoid conflicts.

## Getting Help

### Where can I get help?

1. Check this FAQ
2. Read the [troubleshooting guide](TROUBLESHOOTING.md)
3. Check [existing issues](https://github.com/Hyperpolymath/asdf-ghjk/issues)
4. Open a [new issue](https://github.com/Hyperpolymath/asdf-ghjk/issues/new)
5. Consult [asdf documentation](https://asdf-vm.com)
6. Consult [ghjk documentation](https://github.com/metatypedev/ghjk)

### Is there a community?

- **asdf**: [GitHub Discussions](https://github.com/asdf-vm/asdf/discussions)
- **ghjk**: [GitHub Issues/Discussions](https://github.com/metatypedev/ghjk)
- **This Plugin**: [GitHub Issues](https://github.com/Hyperpolymath/asdf-ghjk/issues)

---

**Still have questions?** Open an issue or discussion on GitHub!
