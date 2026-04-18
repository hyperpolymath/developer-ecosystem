#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
# Copyright (c) 2024 hyperpolymath
# asdf-hashicorp utility functions - supports all HashiCorp tools

set -euo pipefail

# HashiCorp releases URL
readonly HASHICORP_RELEASES_URL="https://releases.hashicorp.com"

# Supported HashiCorp tools
readonly HASHICORP_TOOLS=(
  "vault"
  "terraform"
  "consul"
  "nomad"
  "packer"
  "vagrant"
  "boundary"
  "waypoint"
  "sentinel"
  "consul-template"
  "envconsul"
)

# Detect which tool we're managing based on plugin directory name
get_tool_name() {
  local plugin_name
  plugin_name="$(basename "${ASDF_PLUGIN_PATH:-$(dirname "$(dirname "${BASH_SOURCE[0]}")")}")"

  # Map common aliases
  case "${plugin_name}" in
    asdf-hashicorp-plugin|hashicorp)
      # Default to vault if installed as the generic plugin
      echo "vault"
      ;;
    tf)
      echo "terraform"
      ;;
    *)
      echo "${plugin_name}"
      ;;
  esac
}

# Export for asdf
TOOL_NAME="$(get_tool_name)"
export TOOL_NAME
export TOOL_CMD="${TOOL_NAME}"

# Colors for output (disabled if not a tty)
if [[ -t 2 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[0;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m'
else
  readonly RED=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly BLUE=''
  readonly NC=''
fi

log_info() {
  echo -e "${BLUE}[asdf-hashicorp:${TOOL_NAME}]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[asdf-hashicorp:${TOOL_NAME}]${NC} $*" >&2
}

log_warn() {
  echo -e "${YELLOW}[asdf-hashicorp:${TOOL_NAME}]${NC} WARNING: $*" >&2
}

log_error() {
  echo -e "${RED}[asdf-hashicorp:${TOOL_NAME}]${NC} ERROR: $*" >&2
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
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    FreeBSD*) echo "freebsd" ;;
    *) fail "Unsupported operating system: ${os}" ;;
  esac
}

# Detect the current architecture
get_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armv6l) echo "arm" ;;
    i386|i686) echo "386" ;;
    *) fail "Unsupported architecture: ${arch}" ;;
  esac
}

# Get the download URL for a specific version
get_download_url() {
  local version="${1}"
  local tool="${TOOL_NAME}"
  local platform arch filename

  platform="$(get_platform)"
  arch="$(get_arch)"
  filename="${tool}_${version}_${platform}_${arch}.zip"

  echo "${HASHICORP_RELEASES_URL}/${tool}/${version}/${filename}"
}

# Get the checksum URL for a specific version
get_checksum_url() {
  local version="${1}"
  local tool="${TOOL_NAME}"
  echo "${HASHICORP_RELEASES_URL}/${tool}/${version}/${tool}_${version}_SHA256SUMS"
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

  if [[ -t 1 ]]; then
    curl_args+=(--progress-bar)
  else
    curl_args+=(--silent --show-error)
  fi

  curl "${curl_args[@]}" "${url}"
}

# Verify SHA256 checksum
verify_checksum() {
  local file="${1}"
  local checksum_file="${2}"
  local expected_checksum actual_checksum filename

  filename="$(basename "${file}")"

  # Extract checksum for our file from the SUMS file
  expected_checksum="$(grep "${filename}" "${checksum_file}" | cut -d' ' -f1)"

  if [[ -z "${expected_checksum}" ]]; then
    log_warn "Checksum not found for ${filename}"
    return 0
  fi

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

# List all available versions from HashiCorp releases
list_all_versions() {
  local tool="${TOOL_NAME}"
  local url="${HASHICORP_RELEASES_URL}/${tool}/"
  local response versions

  response="$(curl_wrapper "${url}")" || fail "Failed to fetch releases for ${tool}"

  # Extract version numbers from the HTML listing
  versions="$(echo "${response}" | grep -oE "href=\"${tool}/[0-9]+\.[0-9]+\.[0-9]+[^\"]*\"" | \
              sed -E "s|href=\"${tool}/([^/\"]+)/?\"|\1|" | \
              grep -E '^[0-9]+\.[0-9]+\.[0-9]+' | \
              sort -t. -k1,1n -k2,2n -k3,3n | \
              uniq)"

  echo "${versions}" | tr '\n' ' ' | sed 's/ $//'
}

# Get the latest stable version
get_latest_stable() {
  local versions
  versions="$(list_all_versions)"

  # Filter out alpha, beta, rc versions and get highest
  echo "${versions}" | tr ' ' '\n' | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | \
    sort -t. -k1,1rn -k2,2rn -k3,3rn | \
    head -1
}

# Check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Ensure required tools are available
check_dependencies() {
  local deps=("curl" "unzip" "grep" "sed")
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

# Validate tool name
validate_tool() {
  local tool="${1}"
  local valid=false

  for t in "${HASHICORP_TOOLS[@]}"; do
    if [[ "${t}" == "${tool}" ]]; then
      valid=true
      break
    fi
  done

  if [[ "${valid}" != "true" ]]; then
    log_warn "Unknown HashiCorp tool: ${tool}"
    log_info "Supported tools: ${HASHICORP_TOOLS[*]}"
  fi
}
