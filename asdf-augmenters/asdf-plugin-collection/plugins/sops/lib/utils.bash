#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
# Copyright (c) 2024 hyperpolymath
# asdf-sops utility functions

set -euo pipefail

readonly SOPS_REPO="getsops/sops"
readonly GITHUB_API_URL="https://api.github.com"
readonly GITHUB_RELEASES_URL="https://github.com/${SOPS_REPO}/releases/download"

export TOOL_NAME="sops"
export TOOL_CMD="sops"

if [[ -t 2 ]]; then
  readonly RED='\033[0;31m'
  readonly GREEN='\033[0;32m'
  readonly YELLOW='\033[0;33m'
  readonly BLUE='\033[0;34m'
  readonly NC='\033[0m'
else
  readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { echo -e "${BLUE}[asdf-sops]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[asdf-sops]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[asdf-sops]${NC} WARNING: $*" >&2; }
log_error() { echo -e "${RED}[asdf-sops]${NC} ERROR: $*" >&2; }
fail() { log_error "$*"; exit 1; }

get_platform() {
  local os; os="$(uname -s)"
  case "${os}" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "darwin" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) fail "Unsupported OS: ${os}" ;;
  esac
}

get_arch() {
  local arch; arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) fail "Unsupported arch: ${arch}" ;;
  esac
}

get_download_url() {
  local version="${1}"
  local platform arch filename ext

  platform="$(get_platform)"
  arch="$(get_arch)"

  if [[ "${platform}" == "windows" ]]; then
    ext=".exe"
  else
    ext=""
  fi

  # SOPS binary naming: sops-v3.8.1.linux.amd64
  filename="sops-v${version}.${platform}.${arch}${ext}"

  echo "${GITHUB_RELEASES_URL}/v${version}/${filename}"
}

get_checksum_url() {
  local version="${1}"
  echo "${GITHUB_RELEASES_URL}/v${version}/sops-v${version}.checksums.txt"
}

curl_wrapper() {
  local url="${1}"; shift
  local extra_args=("$@")
  local -a curl_args=(--silent --show-error --fail --location --retry 3 --retry-delay 2)

  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(--header "Authorization: token ${GITHUB_TOKEN}")
  fi

  curl "${curl_args[@]}" ${extra_args[@]+"${extra_args[@]}"} "${url}"
}

download_file() {
  local url="${1}" output="${2}"
  local -a curl_args=(--fail --location --retry 3 --retry-delay 2 --output "${output}")

  if [[ -t 1 ]]; then curl_args+=(--progress-bar); else curl_args+=(--silent --show-error); fi
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then curl_args+=(--header "Authorization: token ${GITHUB_TOKEN}"); fi

  curl "${curl_args[@]}" "${url}"
}

verify_checksum() {
  local file="${1}" checksum_file="${2}"
  local expected_checksum actual_checksum filename

  filename="$(basename "${file}")"
  expected_checksum="$(grep "${filename}" "${checksum_file}" 2>/dev/null | awk '{print $1}')"

  if [[ -z "${expected_checksum}" ]]; then
    log_warn "Checksum not found for ${filename}"
    return 0
  fi

  if command -v sha256sum &>/dev/null; then
    actual_checksum="$(sha256sum "${file}" | cut -d' ' -f1)"
  elif command -v shasum &>/dev/null; then
    actual_checksum="$(shasum -a 256 "${file}" | cut -d' ' -f1)"
  else
    log_warn "No SHA256 command found"; return 0
  fi

  if [[ "${expected_checksum}" != "${actual_checksum}" ]]; then
    fail "Checksum mismatch!\n  Expected: ${expected_checksum}\n  Got: ${actual_checksum}"
  fi
  log_success "Checksum verified"
}

list_all_versions() {
  local api_url="${GITHUB_API_URL}/repos/${SOPS_REPO}/releases"
  local response versions

  response="$(curl_wrapper "${api_url}?per_page=100")" || fail "Failed to fetch releases"

  versions="$(echo "${response}" | grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' | \
              sed -E 's/"tag_name":\s*"v([^"]+)"/\1/' | \
              sort -t. -k1,1n -k2,2n -k3,3n)"

  echo "${versions}" | tr '\n' ' ' | sed 's/ $//'
}

get_latest_stable() {
  list_all_versions | tr ' ' '\n' | sort -t. -k1,1rn -k2,2rn -k3,3rn | head -1
}

command_exists() { command -v "$1" &>/dev/null; }

check_dependencies() {
  local deps=("curl" "grep" "sed") missing=()
  for dep in "${deps[@]}"; do command_exists "${dep}" || missing+=("${dep}"); done
  if [[ ${#missing[@]} -gt 0 ]]; then fail "Missing: ${missing[*]}"; fi
}
