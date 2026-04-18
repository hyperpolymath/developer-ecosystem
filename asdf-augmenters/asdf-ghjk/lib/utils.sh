#!/usr/bin/env bash

set -euo pipefail

# Color codes for output
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# GitHub repository information
GITHUB_REPO="metatypedev/ghjk"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}"

# Platform mapping for ghjk releases
# Maps asdf platform names to ghjk release asset names
get_platform() {
  local uname_s
  local uname_m

  uname_s="$(uname -s)"
  uname_m="$(uname -m)"

  case "${uname_s}" in
    Linux*)
      case "${uname_m}" in
        x86_64) echo "x86_64-unknown-linux-gnu" ;;
        aarch64|arm64) echo "aarch64-unknown-linux-gnu" ;;
        *)
          error "Unsupported Linux architecture: ${uname_m}"
          error "Supported: x86_64, aarch64"
          exit 1
          ;;
      esac
      ;;
    Darwin*)
      case "${uname_m}" in
        x86_64) echo "x86_64-apple-darwin" ;;
        arm64|aarch64) echo "aarch64-apple-darwin" ;;
        *)
          error "Unsupported macOS architecture: ${uname_m}"
          error "Supported: x86_64, arm64"
          exit 1
          ;;
      esac
      ;;
    *)
      error "Unsupported operating system: ${uname_s}"
      error "Supported: Linux, Darwin (macOS)"
      exit 1
      ;;
  esac
}

# Logging functions
log() {
  echo -e "${BLUE}==>${NC} $*" >&2
}

success() {
  echo -e "${GREEN}==>${NC} $*" >&2
}

warn() {
  echo -e "${YELLOW}Warning:${NC} $*" >&2
}

error() {
  echo -e "${RED}Error:${NC} $*" >&2
}

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Check required dependencies
check_dependencies() {
  local missing_deps=()

  for cmd in curl tar sort grep; do
    if ! command_exists "$cmd"; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    error "Missing required dependencies: ${missing_deps[*]}"
    error "Please install these tools and try again"
    exit 1
  fi
}

# Fetch data from GitHub API with rate limit handling and caching
github_api_fetch() {
  local url="$1"
  local use_cache="${2:-true}"

  # Try cache first if enabled
  if [[ "$use_cache" == "true" ]] && [[ -f "${PLUGIN_DIR}/lib/cache.sh" ]]; then
    # shellcheck source=./cache.sh
    source "${PLUGIN_DIR}/lib/cache.sh"

    local cached_response
    if cached_response="$(get_cached "$url" 2>/dev/null)"; then
      echo "$cached_response"
      return 0
    fi
  fi

  local temp_file
  temp_file="$(mktemp)"
  local http_code

  # Prefer authenticated requests if token is available
  local curl_opts=(-sSL -w "%{http_code}" -o "$temp_file")
  if [[ -n "${GITHUB_API_TOKEN:-}" ]]; then
    curl_opts+=(-H "Authorization: token ${GITHUB_API_TOKEN}")
  fi

  http_code="$(curl "${curl_opts[@]}" "$url")"

  case "$http_code" in
    200)
      local response
      response="$(cat "$temp_file")"

      # Save to cache if caching is enabled
      if [[ "$use_cache" == "true" ]] && [[ -f "${PLUGIN_DIR}/lib/cache.sh" ]]; then
        save_to_cache "$url" "$response" 2>/dev/null || true
      fi

      echo "$response"
      rm -f "$temp_file"
      return 0
      ;;
    403)
      error "GitHub API rate limit exceeded"
      error "Set GITHUB_API_TOKEN environment variable to increase rate limit"
      error "Create a token at: https://github.com/settings/tokens"
      rm -f "$temp_file"
      return 1
      ;;
    404)
      error "GitHub API endpoint not found: $url"
      rm -f "$temp_file"
      return 1
      ;;
    *)
      error "GitHub API request failed with status code: $http_code"
      rm -f "$temp_file"
      return 1
      ;;
  esac
}

# Sort versions using semantic versioning
sort_versions() {
  sed 's/^v//' | LC_ALL=C sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | sed 's/^/v/'
}

# Get the asset name for a given version and platform
get_asset_name() {
  local version="$1"
  local platform="$2"

  # Ensure version has 'v' prefix
  if [[ ! "$version" =~ ^v ]]; then
    version="v${version}"
  fi

  echo "ghjk-${version}-${platform}.tar.gz"
}

# Get download URL for a specific version and platform
get_download_url() {
  local version="$1"
  local platform="$2"
  local asset_name

  asset_name="$(get_asset_name "$version" "$platform")"

  # Ensure version has 'v' prefix for tag
  if [[ ! "$version" =~ ^v ]]; then
    version="v${version}"
  fi

  echo "https://github.com/${GITHUB_REPO}/releases/download/${version}/${asset_name}"
}

# Download file with progress and retry logic
download_file() {
  local url="$1"
  local output_path="$2"
  local max_retries=3
  local retry_count=0

  while [[ $retry_count -lt $max_retries ]]; do
    if curl -fsSL --progress-bar -o "$output_path" "$url"; then
      return 0
    else
      retry_count=$((retry_count + 1))
      if [[ $retry_count -lt $max_retries ]]; then
        warn "Download failed, retrying ($retry_count/$max_retries)..."
        sleep 2
      fi
    fi
  done

  error "Failed to download after $max_retries attempts: $url"
  return 1
}

# Verify SHA256 checksum
verify_checksum() {
  local file_path="$1"
  local expected_checksum="$2"

  if [[ -z "$expected_checksum" ]]; then
    warn "No checksum provided for verification"
    return 0
  fi

  local actual_checksum
  if command_exists sha256sum; then
    actual_checksum="$(sha256sum "$file_path" | awk '{print $1}')"
  elif command_exists shasum; then
    actual_checksum="$(shasum -a 256 "$file_path" | awk '{print $1}')"
  else
    warn "No SHA256 command found (sha256sum or shasum), skipping verification"
    return 0
  fi

  if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    error "Checksum verification failed!"
    error "Expected: $expected_checksum"
    error "Actual:   $actual_checksum"
    return 1
  fi

  success "Checksum verified"
  return 0
}

# Extract tar.gz archive
extract_archive() {
  local archive_path="$1"
  local dest_dir="$2"

  log "Extracting archive..."

  mkdir -p "$dest_dir"

  if ! tar -xzf "$archive_path" -C "$dest_dir" --strip-components=0; then
    error "Failed to extract archive: $archive_path"
    return 1
  fi

  success "Archive extracted to $dest_dir"
  return 0
}

# Clean up temporary files
cleanup() {
  local path="$1"
  if [[ -n "$path" ]] && [[ -e "$path" ]]; then
    rm -rf "$path"
  fi
}
