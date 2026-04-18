# Architecture Documentation

This document describes the internal architecture and design decisions of asdf-ghjk.

## Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Component Architecture](#component-architecture)
- [Data Flow](#data-flow)
- [Design Decisions](#design-decisions)
- [Extension Points](#extension-points)

## Overview

asdf-ghjk is an asdf plugin that follows the asdf plugin specification to provide version management for ghjk. The plugin is implemented entirely in Bash for maximum portability and minimal dependencies.

### Key Principles

1. **Simplicity**: Minimal dependencies, straightforward implementation
2. **Portability**: Works across Linux and macOS with bash 4.0+
3. **Reliability**: Comprehensive error handling and validation
4. **Performance**: Caching and efficient algorithms
5. **Security**: Checksum verification and HTTPS-only downloads

## Directory Structure

```
asdf-ghjk/
├── bin/                    # Executable scripts (asdf interface)
│   ├── download           # Downloads ghjk releases
│   ├── install            # Installs downloaded releases
│   ├── list-all           # Lists all available versions
│   ├── list-bin-paths     # Lists binary paths for asdf
│   ├── help-overview      # Provides help text
│   └── latest-stable      # Returns latest stable version
├── lib/                    # Shared library code
│   ├── utils.sh           # Core utilities and helpers
│   └── cache.sh           # API response caching
├── test/                   # Test suite
│   ├── *.bats             # BATS test files
│   └── test_helpers.bash  # Test helper functions
├── scripts/                # Development and maintenance scripts
│   ├── setup-dev.sh       # Development environment setup
│   ├── test.sh            # Test runner
│   └── benchmark.sh       # Performance benchmarking
├── docs/                   # Documentation
│   ├── *.md               # Various documentation files
├── examples/               # Usage examples
│   ├── Dockerfile         # Docker integration examples
│   └── docker-compose.yml # Docker Compose examples
├── completions/            # Shell completion scripts
│   ├── ghjk.bash          # Bash completions
│   └── ghjk.zsh           # Zsh completions
└── .github/                # GitHub-specific files
    ├── workflows/         # GitHub Actions CI/CD
    └── ISSUE_TEMPLATE/    # Issue templates
```

## Component Architecture

### 1. Core Scripts (`bin/`)

#### `bin/list-all`

**Purpose**: List all available ghjk versions from GitHub releases

**Flow**:
1. Source utilities
2. Check dependencies
3. Fetch releases from GitHub API (with caching)
4. Extract version tags
5. Sort versions semantically
6. Output space-separated list

**Dependencies**: `lib/utils.sh`, `lib/cache.sh` (optional)

**Output Format**: Space-separated versions on single line

#### `bin/download`

**Purpose**: Download ghjk binary for specified version

**Flow**:
1. Read environment variables (`ASDF_INSTALL_VERSION`, `ASDF_DOWNLOAD_PATH`)
2. Detect platform architecture
3. Construct download URL
4. Fetch release metadata for checksum
5. Download binary with retry logic
6. Verify checksum (if available)
7. Save metadata for install script

**Dependencies**: `lib/utils.sh`

**Side Effects**:
- Downloads file to `ASDF_DOWNLOAD_PATH`
- Creates `.metadata` file

#### `bin/install`

**Purpose**: Install downloaded ghjk binary

**Flow**:
1. Read environment variables
2. Locate downloaded archive
3. Extract to install path
4. Verify binary exists and is executable
5. Check runtime dependencies
6. Create bin/ symlink if needed

**Dependencies**: `lib/utils.sh`

**Side Effects**:
- Extracts files to `ASDF_INSTALL_PATH`
- Creates symlinks
- Sets executable permissions

#### `bin/list-bin-paths`

**Purpose**: Tell asdf where to find binaries

**Flow**:
1. Check for `bin/` directory
2. Fall back to root directory if needed
3. Output path(s)

**Called By**: asdf (automatically)

#### `bin/help-overview`

**Purpose**: Provide user-friendly help text

**Output**: Formatted help documentation

#### `bin/latest-stable`

**Purpose**: Get latest non-prerelease version

**Flow**:
1. Fetch releases
2. Filter out pre-releases (rc, alpha, beta)
3. Return first (latest) version

### 2. Library Code (`lib/`)

#### `lib/utils.sh`

**Core utility functions**:

| Function | Purpose |
|----------|---------|
| `get_platform()` | Detect OS and architecture |
| `log()`, `success()`, `warn()`, `error()` | Logging with colors |
| `command_exists()` | Check if command is available |
| `check_dependencies()` | Verify required tools |
| `github_api_fetch()` | Fetch from GitHub API with caching |
| `sort_versions()` | Sort versions semantically |
| `get_asset_name()` | Generate asset filename |
| `get_download_url()` | Generate download URL |
| `download_file()` | Download with retry logic |
| `verify_checksum()` | SHA256 verification |
| `extract_archive()` | Extract tar.gz files |
| `cleanup()` | Clean up temporary files |

**Design**: Single-responsibility functions, pure where possible

#### `lib/cache.sh`

**Caching implementation**:

| Function | Purpose |
|----------|---------|
| `init_cache()` | Initialize cache directory |
| `get_cache_path()` | Generate cache file path |
| `is_cache_valid()` | Check cache freshness |
| `get_cached()` | Retrieve cached response |
| `save_to_cache()` | Store response in cache |
| `clear_cache()` | Remove all cache |
| `clean_cache()` | Remove expired cache |
| `cache_stats()` | Display cache statistics |

**Design**:
- TTL-based expiration (default 1 hour)
- SHA256-based cache keys
- Graceful degradation if caching fails

### 3. Test Suite (`test/`)

**Framework**: BATS (Bash Automated Testing System)

**Test Files**:
- `utils.bats`: Unit tests for utility functions
- `list-all.bats`: Tests for version listing
- `download.bats`: Tests for download functionality
- `install.bats`: Tests for installation

**Test Helpers**: Common setup/teardown, mock data, fixtures

## Data Flow

### Version Installation Flow

```
User runs: asdf install ghjk 0.3.2
    ↓
asdf calls: bin/download
    ↓
bin/download:
  1. Detects platform (x86_64-unknown-linux-gnu)
  2. Constructs URL (github.com/.../ghjk-v0.3.2-x86_64-unknown-linux-gnu.tar.gz)
  3. Fetches release metadata
  4. Downloads file (with retry)
  5. Verifies checksum
  6. Saves metadata
    ↓
asdf calls: bin/install
    ↓
bin/install:
  1. Reads metadata
  2. Extracts archive
  3. Verifies binary
  4. Creates symlinks
  5. Checks dependencies
    ↓
asdf creates shims
    ↓
User runs: ghjk --version
```

### Version Listing Flow

```
User runs: asdf list all ghjk
    ↓
asdf calls: bin/list-all
    ↓
bin/list-all:
  1. Checks cache
  2. If cached: return cached data
  3. If not cached:
     a. Fetches from GitHub API
     b. Paginates through all releases
     c. Extracts version tags
     d. Saves to cache
  4. Sorts versions
  5. Outputs space-separated list
    ↓
asdf displays to user
```

## Design Decisions

### Why Bash?

**Chosen**: Bash 4.0+

**Rationale**:
- Required by asdf specification
- Maximum portability (available on all target platforms)
- No compilation needed
- Well-understood by shell users
- Rich ecosystem of tools

**Tradeoffs**:
- Less type safety than compiled languages
- Harder to refactor than modern languages
- Requires careful error handling

### Why Caching?

**Chosen**: File-based TTL cache

**Rationale**:
- Reduces GitHub API calls (rate limit friendly)
- Improves performance for repeated operations
- Simple implementation without external dependencies
- Transparent to users

**Implementation**:
- Cache location: `~/.asdf/cache/ghjk/`
- TTL: 1 hour (configurable via `GHJK_CACHE_TTL`)
- Key: SHA256 hash of URL
- Format: Raw JSON responses

**Tradeoffs**:
- Slightly stale data possible
- Disk space usage (minimal, ~KB per cached response)
- Manual cache invalidation needed for forced updates

### Platform Detection

**Method**: `uname` system calls

**Mapping**:
```bash
Linux + x86_64   → x86_64-unknown-linux-gnu
Linux + aarch64  → aarch64-unknown-linux-gnu
Darwin + x86_64  → x86_64-apple-darwin
Darwin + arm64   → aarch64-apple-darwin
```

**Rationale**: Matches ghjk's release naming convention

### Checksum Verification

**Method**: SHA256 from GitHub release metadata

**Flow**:
1. Fetch release metadata from GitHub API
2. Extract SHA256 from asset metadata
3. Calculate SHA256 of downloaded file
4. Compare hashes
5. Fail installation if mismatch

**Rationale**:
- Prevents corrupted downloads
- Detects tampering
- Industry-standard algorithm

**Tradeoffs**:
- Extra API call
- Slight performance overhead
- Warnings if checksum unavailable (rare)

### Error Handling Strategy

**Principles**:
1. **Fail Fast**: Exit immediately on critical errors
2. **Clear Messages**: Human-readable error descriptions
3. **Actionable**: Suggest solutions when possible
4. **Logged**: All errors go to stderr
5. **Codes**: Proper exit codes (0 = success, non-zero = failure)

**Example**:
```bash
if ! curl -fsSL "$url" -o "$output"; then
  error "Failed to download ghjk ${version}"
  error "Check your internet connection and try again"
  error "URL: $url"
  exit 1
fi
```

### Dependency Philosophy

**Approach**: Minimal, standard dependencies only

**Required**:
- bash (4.0+)
- curl
- tar
- grep
- sort

**Rationale**: Available on all target platforms by default

**Not Required**:
- jq (use grep/sed for JSON parsing)
- wget (use curl)
- python (keep everything in bash)

## Extension Points

### Adding New Scripts

To add a new bin script:

1. Create file in `bin/`
2. Add shebang: `#!/usr/bin/env bash`
3. Set strict mode: `set -euo pipefail`
4. Source utilities: `source "${PLUGIN_DIR}/lib/utils.sh"`
5. Implement functionality
6. Make executable: `chmod +x bin/new-script`
7. Document in README
8. Add tests in `test/`

### Adding New Utilities

To add a new utility function:

1. Add to `lib/utils.sh`
2. Follow naming convention (lowercase with underscores)
3. Add documentation comment
4. Write tests in `test/utils.bats`
5. Update ARCHITECTURE.md (this file)

### Adding Platform Support

To add a new platform:

1. Update `get_platform()` in `lib/utils.sh`
2. Add platform detection logic
3. Add platform to documentation
4. Update tests
5. Add CI test matrix entry

### Customizing Cache Behavior

Environment variables:

- `GHJK_CACHE_TTL`: Cache time-to-live in seconds (default: 3600)
- `ASDF_DATA_DIR`: Base directory for asdf data (cache subdirectory)

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| list-all (cached) | O(1) | Direct file read |
| list-all (uncached) | O(n) | n = number of releases |
| download | O(1) | Single file download |
| install | O(1) | Single archive extraction |
| sort_versions | O(n log n) | Standard sort |

### Space Complexity

| Component | Space Usage |
|-----------|-------------|
| Plugin code | < 100 KB |
| Cache (per response) | ~10-50 KB |
| Downloaded archive | 10-50 MB |
| Installed binary | 10-50 MB |
| Per version total | ~20-100 MB |

## Security Considerations

### Attack Surface

**Potential Vectors**:
1. Malicious GitHub responses
2. Man-in-the-middle attacks
3. Compromised downloads
4. Path traversal attacks

**Mitigations**:
1. HTTPS-only connections
2. Checksum verification
3. Input validation
4. Proper path quoting
5. No use of `eval` or dangerous constructs

### Code Review Points

When reviewing changes:
- [ ] All user inputs validated
- [ ] All file paths properly quoted
- [ ] No use of `eval`, `source` on untrusted input
- [ ] HTTPS used for all downloads
- [ ] Error messages don't leak sensitive data
- [ ] ShellCheck passes
- [ ] Tests cover security-relevant cases

## Future Enhancements

Potential additions:

1. **Parallel Downloads**: Download/install multiple versions concurrently
2. **Mirror Support**: Allow alternative download sources
3. **GPG Verification**: Verify GPG signatures if ghjk adds them
4. **Version Constraints**: Support version range specifications
5. **Rollback Support**: Automatically rollback failed installations
6. **Telemetry**: Optional usage statistics (opt-in)

## References

- [asdf Plugin Development](https://asdf-vm.com/plugins/create.html)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck](https://www.shellcheck.net/)
- [BATS Testing](https://github.com/bats-core/bats-core)
- [ghjk Repository](https://github.com/metatypedev/ghjk)

---

**Maintained By**: asdf-ghjk contributors
**Last Updated**: 2024-11-22
