#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
# Copyright (c) 2024 hyperpolymath
# asdf-casket-ssg utility functions

set -euo pipefail

# casket-ssg repository for releases
readonly CASKET_REPO="hyperpolymath/casket-ssg"
readonly GITHUB_API_URL="https://api.github.com"
readonly GITHUB_RELEASES_URL="https://github.com/${CASKET_REPO}/releases/download"

# Tool name for this plugin (exported for use by asdf)
export TOOL_NAME="casket-ssg"
export TOOL_CMD="casket-ssg"

# Colors for output (disabled if not a tty)
if [[ -t 2 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[0;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m' # No Color
else
  readonly RED=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly BLUE=''
  readonly NC=''
fi

# Logging functions
log_info() {
  echo -e "${BLUE}[asdf-casket-ssg]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[asdf-casket-ssg]${NC} $*" >&2
}

log_warn() {
  echo -e "${YELLOW}[asdf-casket-ssg]${NC} WARNING: $*" >&2
}

log_error() {
  echo -e "${RED}[asdf-casket-ssg]${NC} ERROR: $*" >&2
}

fail() {
  log_error "$*"
  exit 1
}

# Detect the current platform
get_platform() {
  local os
  os="$(uname -s)"
  case "${os}" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "darwin" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows64" ;;
    *) fail "Unsupported operating system: ${os}" ;;
  esac
}

# Detect the current architecture
get_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) fail "Unsupported architecture: ${arch}" ;;
  esac
}

# Get the download URL for a specific version
get_download_url() {
  local version="${1}"
  local platform arch filename tag_name

  platform="$(get_platform)"
  arch="$(get_arch)"

  # Tag name format: v1.0.0
  tag_name="v${version}"
  filename="casket-ssg-${arch}-${platform}-${version}.tar.gz"

  echo "${GITHUB_RELEASES_URL}/${tag_name}/${filename}"
}

# Get the checksum URL for a specific version
get_checksum_url() {
  local version="${1}"
  local download_url
  download_url="$(get_download_url "${version}")"
  echo "${download_url}.sha256"
}

# Wrapper for curl with proper headers
curl_wrapper() {
  local url="${1}"
  shift
  local extra_args=("$@")

  local -a curl_args=(
    --silent
    --show-error
    --fail
    --location
    --retry 3
    --retry-delay 2
  )

  # Add GitHub token if available for rate limiting
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: token ${GITHUB_TOKEN}")
  elif [[ -n "${GITHUB_API_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: token ${GITHUB_API_TOKEN}")
  fi

  # Use safe array expansion for potentially empty extra_args
  curl "${curl_args[@]}" ${extra_args[@]+"${extra_args[@]}"} "${url}"
}

# Download a file with progress indication
download_file() {
  local url="${1}"
  local output="${2}"

  local -a curl_args=(
    --fail
    --location
    --retry 3
    --retry-delay 2
    --output "${output}"
  )

  # Show progress if interactive
  if [[ -t 1 ]]; then
    curl_args+=(--progress-bar)
  else
    curl_args+=(--silent --show-error)
  fi

  # Add GitHub token if available
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: token ${GITHUB_TOKEN}")
  elif [[ -n "${GITHUB_API_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: token ${GITHUB_API_TOKEN}")
  fi

  curl "${curl_args[@]}" "${url}"
}

# Verify SHA256 checksum
verify_checksum() {
  local file="${1}"
  local checksum_file="${2}"

  local expected_checksum actual_checksum

  # Read expected checksum (file format: "hash  filename" or just "hash")
  expected_checksum="$(cut -d' ' -f1 < "${checksum_file}")"

  # Calculate actual checksum
  if command -v sha256sum &>/dev/null; then
    actual_checksum="$(sha256sum "${file}" | cut -d' ' -f1)"
  elif command -v shasum &>/dev/null; then
    actual_checksum="$(shasum -a 256 "${file}" | cut -d' ' -f1)"
  else
    log_warn "No SHA256 command found, skipping verification"
    return 0
  fi

  if [[ "${expected_checksum}" != "${actual_checksum}" ]]; then
    fail "Checksum verification failed!\n  Expected: ${expected_checksum}\n  Got: ${actual_checksum}"
  fi

  log_success "Checksum verified"
}

# List all available versions from GitHub releases
list_all_versions() {
  local api_url="${GITHUB_API_URL}/repos/${CASKET_REPO}/releases"
  local response versions

  response="$(curl_wrapper "${api_url}?per_page=100")" || fail "Failed to fetch releases from GitHub"

  # Extract version numbers from tag names (format: vX.Y.Z)
  versions="$(echo "${response}" | grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' | \
              sed -E 's/"tag_name":\s*"v([^"]+)"/\1/' | \
              sort -t. -k1,1n -k2,2n -k3,3n)"

  # Return space-separated list for asdf
  echo "${versions}" | tr '\n' ' ' | sed 's/ $//'
}

# Get the latest stable version
get_latest_stable() {
  local versions
  versions="$(list_all_versions)"

  # Get the highest version
  echo "${versions}" | tr ' ' '\n' | sort -t. -k1,1rn -k2,2rn -k3,3rn | head -1
}

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Ensure required tools are available
check_dependencies() {
  local deps=("curl" "tar" "grep" "sed")
  local missing=()

  for dep in "${deps[@]}"; do
    if ! command_exists "${dep}"; then
      missing+=("${dep}")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "Missing required dependencies: ${missing[*]}"
  fi
}
