#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2024 hyperpolymath
# asdf-zig utility functions

set -euo pipefail

readonly ZIG_INDEX_URL="https://ziglang.org/download/index.json"
readonly ZIG_DOWNLOAD_BASE="https://ziglang.org/download"

export TOOL_NAME="zig"
export TOOL_CMD="zig"

# Colors for output
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
  echo -e "${BLUE}[asdf-zig]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[asdf-zig]${NC} $*" >&2
}

log_warn() {
  echo -e "${YELLOW}[asdf-zig]${NC} WARNING: $*" >&2
}

log_error() {
  echo -e "${RED}[asdf-zig]${NC} ERROR: $*" >&2
}

fail() {
  log_error "$*"
  exit 1
}

get_platform() {
  local os
  os="$(uname -s)"
  case "${os}" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) fail "Unsupported operating system: ${os}" ;;
  esac
}

get_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    armv7l) echo "armv7a" ;;
    i686|i386) echo "x86" ;;
    *) fail "Unsupported architecture: ${arch}" ;;
  esac
}

get_download_url() {
  local version="${1}"
  local platform arch ext

  platform="$(get_platform)"
  arch="$(get_arch)"

  # Use .tar.xz for all platforms except Windows
  if [[ "${platform}" == "windows" ]]; then
    ext="zip"
  else
    ext="tar.xz"
  fi

  # Master builds use different URL structure
  if [[ "${version}" == "master" ]]; then
    echo "https://ziglang.org/builds/zig-${platform}-${arch}-${version}.${ext}"
  else
    echo "${ZIG_DOWNLOAD_BASE}/${version}/zig-${platform}-${arch}-${version}.${ext}"
  fi
}

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

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: token ${GITHUB_TOKEN}")
  fi

  curl "${curl_args[@]}" ${extra_args[@]+"${extra_args[@]}"} "${url}"
}

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

list_all_versions() {
  # Fetch the Zig download index
  local index
  index="$(curl_wrapper "${ZIG_INDEX_URL}")" || fail "Failed to fetch Zig version index"

  # Extract version keys (excluding "master")
  echo "${index}" | grep -oE '"[0-9]+\.[0-9]+\.[0-9]+"' | tr -d '"' | sort -V | uniq
}

get_latest_stable() {
  list_all_versions | sort -rV | head -1
}

command_exists() {
  command -v "$1" &>/dev/null
}

check_dependencies() {
  local deps=("curl" "tar" "grep" "sed" "sort" "cut" "mkdir" "rm")
  local missing=()

  for dep in "${deps[@]}"; do
    if ! command_exists "${dep}"; then
      missing+=("${dep}")
    fi
  done

  # Check for xz (needed for .tar.xz)
  if ! command_exists "xz" && ! tar --version 2>&1 | grep -q "GNU tar"; then
    log_warn "xz not found. Install xz-utils for .tar.xz support."
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    fail "Missing required dependencies: ${missing[*]}"
  fi
}
