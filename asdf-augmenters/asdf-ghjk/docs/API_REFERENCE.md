# API Reference

Complete reference for asdf-ghjk functions, scripts, and environment variables.

## Table of Contents

- [Scripts](#scripts)
- [Library Functions](#library-functions)
- [Environment Variables](#environment-variables)
- [Exit Codes](#exit-codes)
- [File Formats](#file-formats)

## Scripts

### bin/list-all

Lists all available ghjk versions from GitHub releases.

**Usage**: Called automatically by asdf

```bash
./bin/list-all
```

**Output**: Space-separated list of versions

```
v0.1.0 v0.2.0 v0.3.0 v0.3.1 v0.3.2
```

**Environment Variables**:
- `GITHUB_API_TOKEN` (optional): GitHub API token for higher rate limits

**Exit Codes**:
- `0`: Success
- `1`: GitHub API error, network error, or no versions found

**Performance**: O(n) where n = number of releases; ~1-3 seconds without cache, <100ms with cache

---

### bin/download

Downloads a specific ghjk version.

**Usage**: Called automatically by asdf

```bash
export ASDF_INSTALL_VERSION="0.3.2"
export ASDF_DOWNLOAD_PATH="/path/to/download"
./bin/download
```

**Required Environment Variables**:
- `ASDF_INSTALL_VERSION`: Version to download (e.g., "0.3.2")
- `ASDF_DOWNLOAD_PATH`: Where to download files

**Optional Environment Variables**:
- `GITHUB_API_TOKEN`: GitHub API token

**Side Effects**:
- Downloads archive to `${ASDF_DOWNLOAD_PATH}/<asset-name>.tar.gz`
- Creates `.metadata` file with version info

**Exit Codes**:
- `0`: Success
- `1`: Missing environment variable, download failure, or checksum mismatch

**Performance**: ~5-30 seconds depending on network speed

---

### bin/install

Installs a downloaded ghjk version.

**Usage**: Called automatically by asdf

```bash
export ASDF_INSTALL_VERSION="0.3.2"
export ASDF_INSTALL_PATH="/path/to/install"
export ASDF_DOWNLOAD_PATH="/path/to/download"
export ASDF_INSTALL_TYPE="version"
./bin/install
```

**Required Environment Variables**:
- `ASDF_INSTALL_VERSION`: Version to install
- `ASDF_INSTALL_PATH`: Where to install
- `ASDF_INSTALL_TYPE`: Must be "version"

**Optional Environment Variables**:
- `ASDF_DOWNLOAD_PATH`: Where files were downloaded (defaults to adjacent to install path)

**Side Effects**:
- Extracts files to `${ASDF_INSTALL_PATH}/`
- Creates `${ASDF_INSTALL_PATH}/bin/` directory
- Sets executable permissions
- Creates symlinks if needed

**Exit Codes**:
- `0`: Success
- `1`: Missing environment variable, extraction failure, or binary not found

**Performance**: ~1-3 seconds

---

### bin/list-bin-paths

Returns paths where binaries are located.

**Usage**: Called automatically by asdf

```bash
./bin/list-bin-paths /path/to/install
```

**Arguments**:
- `$1`: Installation path

**Output**: One or more paths, one per line

```
/path/to/install/bin
```

**Exit Codes**:
- `0`: Success
- `1`: No install path provided

---

### bin/help-overview

Displays user-friendly help text.

**Usage**: Manually by users

```bash
./bin/help-overview
```

**Output**: Formatted help documentation

**Exit Codes**: Always `0`

---

### bin/latest-stable

Returns the latest stable (non-prerelease) version.

**Usage**: Scripts or manual use

```bash
latest=$(./bin/latest-stable)
asdf install ghjk "$latest"
```

**Output**: Single version tag

```
v0.3.2
```

**Exit Codes**:
- `0`: Success
- `1`: No stable versions found or GitHub API error

---

## Library Functions

### lib/utils.sh

Core utility functions. Source this file to use functions:

```bash
source "${PLUGIN_DIR}/lib/utils.sh"
```

#### get_platform()

Detects current operating system and architecture.

**Signature**: `get_platform()`

**Returns**: Platform string

**Example**:
```bash
platform=$(get_platform)
echo "$platform"  # x86_64-unknown-linux-gnu
```

**Possible Values**:
- `x86_64-unknown-linux-gnu`
- `aarch64-unknown-linux-gnu`
- `x86_64-apple-darwin`
- `aarch64-apple-darwin`

**Exit Codes**:
- `0`: Success
- `1`: Unsupported platform

---

#### log(), success(), warn(), error()

Logging functions with color output.

**Signatures**:
```bash
log "message"       # Blue arrow prefix
success "message"   # Green arrow prefix
warn "message"      # Yellow warning prefix
error "message"     # Red error prefix
```

**Output**: To stderr

**Example**:
```bash
log "Downloading version 0.3.2..."
success "Download complete"
warn "Checksum not available"
error "Failed to download"
```

---

#### command_exists()

Checks if a command is available in PATH.

**Signature**: `command_exists <command>`

**Arguments**:
- `$1`: Command name

**Returns**: Nothing (use exit code)

**Example**:
```bash
if command_exists curl; then
  echo "curl is available"
fi
```

**Exit Codes**:
- `0`: Command exists
- `1`: Command not found

---

#### check_dependencies()

Verifies all required dependencies are installed.

**Signature**: `check_dependencies()`

**Checks**: bash, curl, tar, sort, grep

**Example**:
```bash
check_dependencies || exit 1
```

**Exit Codes**:
- `0`: All dependencies found
- `1`: One or more dependencies missing

---

#### github_api_fetch()

Fetches data from GitHub API with caching.

**Signature**: `github_api_fetch <url> [use_cache]`

**Arguments**:
- `$1`: GitHub API URL
- `$2`: Use cache (default: true)

**Environment Variables Used**:
- `GITHUB_API_TOKEN` (optional)

**Returns**: JSON response to stdout

**Example**:
```bash
releases=$(github_api_fetch "https://api.github.com/repos/metatypedev/ghjk/releases")
```

**Exit Codes**:
- `0`: Success
- `1`: API error or rate limit exceeded

**Performance**: With cache: <100ms, Without cache: ~500-2000ms

---

#### sort_versions()

Sorts versions semantically.

**Signature**: `sort_versions` (reads from stdin)

**Input**: Newline-separated versions

**Output**: Sorted versions

**Example**:
```bash
echo -e "v0.3.0\nv0.1.0\nv0.2.0" | sort_versions
# v0.1.0
# v0.2.0
# v0.3.0
```

**Exit Codes**: Always `0`

---

#### get_asset_name()

Generates asset filename for a version and platform.

**Signature**: `get_asset_name <version> <platform>`

**Arguments**:
- `$1`: Version (with or without 'v' prefix)
- `$2`: Platform string

**Returns**: Asset filename

**Example**:
```bash
asset=$(get_asset_name "0.3.2" "x86_64-unknown-linux-gnu")
echo "$asset"  # ghjk-v0.3.2-x86_64-unknown-linux-gnu.tar.gz
```

---

#### get_download_url()

Generates download URL for a version and platform.

**Signature**: `get_download_url <version> <platform>`

**Arguments**:
- `$1`: Version
- `$2`: Platform string

**Returns**: Download URL

**Example**:
```bash
url=$(get_download_url "0.3.2" "x86_64-unknown-linux-gnu")
echo "$url"
# https://github.com/metatypedev/ghjk/releases/download/v0.3.2/ghjk-v0.3.2-x86_64-unknown-linux-gnu.tar.gz
```

---

#### download_file()

Downloads a file with retry logic.

**Signature**: `download_file <url> <output_path>`

**Arguments**:
- `$1`: URL to download
- `$2`: Output file path

**Retries**: 3 attempts with 2-second delay

**Example**:
```bash
download_file "https://example.com/file.tar.gz" "/tmp/file.tar.gz"
```

**Exit Codes**:
- `0`: Success
- `1`: Failed after retries

---

#### verify_checksum()

Verifies SHA256 checksum of a file.

**Signature**: `verify_checksum <file_path> <expected_checksum>`

**Arguments**:
- `$1`: File to verify
- `$2`: Expected SHA256 hash

**Example**:
```bash
if verify_checksum "/tmp/file.tar.gz" "abc123..."; then
  echo "Checksum valid"
fi
```

**Exit Codes**:
- `0`: Checksum matches or no checksum provided
- `1`: Checksum mismatch

---

#### extract_archive()

Extracts a tar.gz archive.

**Signature**: `extract_archive <archive_path> <dest_dir>`

**Arguments**:
- `$1`: Archive file path
- `$2`: Destination directory

**Example**:
```bash
extract_archive "/tmp/file.tar.gz" "/tmp/extracted"
```

**Exit Codes**:
- `0`: Success
- `1`: Extraction failed

---

#### cleanup()

Removes a file or directory.

**Signature**: `cleanup <path>`

**Arguments**:
- `$1`: Path to remove

**Example**:
```bash
cleanup "/tmp/tempfile"
```

**Exit Codes**: Always `0`

---

### lib/cache.sh

Cache management functions. Source this file:

```bash
source "${PLUGIN_DIR}/lib/cache.sh"
```

#### init_cache()

Initializes cache directory.

**Signature**: `init_cache()`

**Creates**: `~/.asdf/cache/ghjk/`

---

#### get_cached()

Retrieves cached response if valid.

**Signature**: `get_cached <url>`

**Arguments**:
- `$1`: URL that was cached

**Returns**: Cached response or nothing

**Exit Codes**:
- `0`: Valid cache found
- `1`: No cache or expired

---

#### save_to_cache()

Saves response to cache.

**Signature**: `save_to_cache <url> <response>`

**Arguments**:
- `$1`: URL to cache
- `$2`: Response data

---

#### clear_cache()

Removes all cached files.

**Signature**: `clear_cache()`

---

#### clean_cache()

Removes expired cache entries.

**Signature**: `clean_cache()`

---

#### cache_stats()

Displays cache statistics.

**Signature**: `cache_stats()`

**Output**: Human-readable statistics

---

## Environment Variables

### User-Configurable

| Variable | Purpose | Default | Example |
|----------|---------|---------|---------|
| `GITHUB_API_TOKEN` | GitHub API authentication | None | `ghp_abc123...` |
| `GHJK_CACHE_TTL` | Cache time-to-live (seconds) | `3600` | `7200` |
| `ASDF_DATA_DIR` | asdf data directory | `~/.asdf` | `/custom/path` |

### asdf-Provided

| Variable | Set By | Purpose |
|----------|--------|---------|
| `ASDF_INSTALL_VERSION` | asdf | Version to install |
| `ASDF_INSTALL_PATH` | asdf | Installation destination |
| `ASDF_DOWNLOAD_PATH` | asdf | Download destination |
| `ASDF_INSTALL_TYPE` | asdf | Type of install (version/ref) |

### Internal

| Variable | Purpose |
|----------|---------|
| `PLUGIN_DIR` | Plugin installation directory |
| `GITHUB_REPO` | ghjk repository name |
| `GITHUB_API_URL` | Base GitHub API URL |

---

## Exit Codes

All scripts follow standard Unix conventions:

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| Other | Not used (reserved for future) |

---

## File Formats

### .metadata

Created by `bin/download`, read by `bin/install`.

**Location**: `${ASDF_DOWNLOAD_PATH}/.metadata`

**Format**: Shell variable assignments

**Example**:
```bash
version=0.3.2
platform=x86_64-unknown-linux-gnu
archive=ghjk-v0.3.2-x86_64-unknown-linux-gnu.tar.gz
checksum=abc123def456...
```

**Usage**:
```bash
source "${ASDF_DOWNLOAD_PATH}/.metadata"
echo "Version: $version"
```

### Cache Files

**Location**: `~/.asdf/cache/ghjk/<sha256-hash>.json`

**Format**: Raw JSON from GitHub API

**Naming**: SHA256 hash of the URL

**TTL**: Controlled by `GHJK_CACHE_TTL`

---

## Error Messages

### Common Patterns

| Pattern | Meaning | Action |
|---------|---------|--------|
| `Error: ASDF_* required` | Missing environment variable | Set variable |
| `Error: GitHub API rate limit` | Too many requests | Set `GITHUB_API_TOKEN` |
| `Error: Checksum verification failed` | Download corrupted | Re-download |
| `Error: Unsupported platform` | Platform not supported | Check compatibility |

### Debug Output

Enable with:
```bash
export ASDF_DEBUG=1
```

---

## Version Compatibility

### Script Versions

Scripts follow semantic versioning conceptually but are versioned with the plugin.

### API Stability

**Stable** (will not break):
- All `bin/*` scripts interface with asdf
- Environment variables read/written
- Exit codes
- File formats

**Internal** (may change):
- Library function signatures
- Internal variable names
- Cache format
- Log message formats

---

## Examples

### Complete Installation Flow

```bash
# 1. List versions
export GITHUB_API_TOKEN="ghp_..."
versions=$(./bin/list-all)

# 2. Download
export ASDF_INSTALL_VERSION="0.3.2"
export ASDF_DOWNLOAD_PATH="/tmp/download"
./bin/download

# 3. Install
export ASDF_INSTALL_PATH="/tmp/install"
export ASDF_INSTALL_TYPE="version"
./bin/install

# 4. Verify
/tmp/install/bin/ghjk --version
```

### Using Library Functions

```bash
#!/bin/bash
source lib/utils.sh

# Detect platform
platform=$(get_platform)
log "Detected platform: $platform"

# Check dependencies
if check_dependencies; then
  success "All dependencies found"
else
  error "Missing dependencies"
  exit 1
fi

# Fetch releases
releases=$(github_api_fetch "https://api.github.com/repos/metatypedev/ghjk/releases")

# Get latest version
latest=$(echo "$releases" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/"tag_name": *"\([^"]*\)"/\1/')
log "Latest version: $latest"

# Download
url=$(get_download_url "$latest" "$platform")
download_file "$url" "/tmp/ghjk.tar.gz"

# Extract
extract_archive "/tmp/ghjk.tar.gz" "/tmp/ghjk"

# Cleanup
cleanup "/tmp/ghjk.tar.gz"
```

---

## Performance Tips

1. **Use caching**: Keep `GHJK_CACHE_TTL` at default or higher
2. **Set GitHub token**: Avoid rate limits
3. **Parallel installs**: Install multiple versions in separate shells
4. **Clean cache**: Run `./scripts/cleanup.sh --cache` periodically

---

## See Also

- [Architecture Documentation](ARCHITECTURE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Examples](EXAMPLES.md)

---

**Last Updated**: 2024-11-22
