# CLAUDE.md

This document provides guidance for Claude Code when working with the asdf-ghjk repository.

## Project Overview

This is an asdf plugin for [ghjk](https://github.com/metatypedev/ghjk), a development environment manager. The plugin enables asdf users to install and manage ghjk versions.

## Repository Structure

```
asdf-ghjk/
├── bin/           # Plugin executables
│   ├── download   # Download script for ghjk releases
│   ├── install    # Installation script
│   └── list-all   # Script to list all available versions
├── lib/           # Shared library functions (if needed)
└── README.md      # User-facing documentation
```

## Development Guidelines

### asdf Plugin Requirements

This plugin must follow the [asdf plugin development guidelines](https://asdf-vm.com/plugins/create.html):

1. **Required Scripts** (in `bin/`):
   - `list-all` - Lists all available ghjk versions
   - `download` - Downloads the specified version
   - `install` - Installs the downloaded version

2. **Environment Variables Available**:
   - `ASDF_INSTALL_TYPE` - `version` or `ref`
   - `ASDF_INSTALL_VERSION` - The version or ref to install
   - `ASDF_INSTALL_PATH` - Where to install the tool
   - `ASDF_DOWNLOAD_PATH` - Where to download the source/binary

3. **Script Exit Codes**:
   - Exit 0 for success
   - Exit non-zero for failure

### Shell Scripting Best Practices

- Use `#!/usr/bin/env bash` as shebang
- Enable strict mode: `set -euo pipefail`
- Use ShellCheck for linting
- Add error handling and meaningful error messages
- Support multiple platforms (Linux, macOS, etc.)

### Testing

Before committing changes:

```bash
# Test list-all
./bin/list-all

# Test download and install with a specific version
export ASDF_INSTALL_VERSION="0.1.0"
export ASDF_DOWNLOAD_PATH="/tmp/asdf-ghjk-test"
export ASDF_INSTALL_PATH="/tmp/asdf-ghjk-install"
./bin/download
./bin/install

# Verify installation
"${ASDF_INSTALL_PATH}/bin/ghjk" --version
```

## ghjk-Specific Information

### Installation Sources

- GitHub releases: https://github.com/metatypedev/ghjk/releases
- Binary naming convention: Typically `ghjk-{version}-{platform}-{arch}.tar.gz`
- Supported platforms: Check ghjk releases for available platforms

### Version Detection

- Use GitHub API to fetch available versions
- Parse version tags (usually in format `vX.Y.Z` or `X.Y.Z`)
- Sort versions properly (semantic versioning)

## Common Tasks

### Adding New Features

1. Update the appropriate script in `bin/`
2. Test manually with multiple versions
3. Update README.md if user-facing changes
4. Commit with descriptive message

### Debugging

- Enable verbose output: `export ASDF_DEBUG=1`
- Check asdf logs: `~/.asdf/logs/`
- Test scripts directly with environment variables set

### Release Process

This plugin doesn't require versioning itself - it's registered with asdf's plugin repository and pulled directly from the main branch.

## Resources

- [asdf Plugin Development Guide](https://asdf-vm.com/plugins/create.html)
- [asdf Plugin Template](https://github.com/asdf-vm/asdf-plugin-template)
- [ghjk Documentation](https://github.com/metatypedev/ghjk)
- [ghjk Releases](https://github.com/metatypedev/ghjk/releases)

## Code Style

- Follow Google Shell Style Guide
- Use consistent indentation (2 spaces)
- Comment complex logic
- Keep functions small and focused
- Use descriptive variable names in lowercase with underscores

## Error Handling

Always provide helpful error messages:

```bash
if ! command -v curl &> /dev/null; then
  echo "Error: curl is required but not installed" >&2
  exit 1
fi
```

## Platform Support

Ensure scripts work on:
- Linux (various distributions)
- macOS (Intel and Apple Silicon)
- Any other platforms supported by ghjk

## Dependencies

Minimize external dependencies. Common tools that can be assumed:
- bash
- curl or wget
- tar, gzip
- sort, grep, sed

For anything else, check availability and provide clear error messages.
