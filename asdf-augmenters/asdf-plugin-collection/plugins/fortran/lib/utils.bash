#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
# Copyright (c) 2024 hyperpolymath
# asdf-fortran utility functions - supports gfortran (via GCC) and LFortran

set -euo pipefail

# Default compiler - can be overridden with ASDF_FORTRAN_COMPILER
readonly FORTRAN_COMPILER="${ASDF_FORTRAN_COMPILER:-gfortran}"

# Sources for different compilers
readonly GNAT_FSF_REPO="alire-project/GNAT-FSF-builds"
readonly LFORTRAN_REPO="lfortran/lfortran"
readonly GITHUB_API_URL="https://api.github.com"

export TOOL_NAME="fortran"
export TOOL_CMD="gfortran"

if [[ -t 2 ]]; then
  readonly RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  readonly RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { echo -e "${BLUE}[asdf-fortran]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[asdf-fortran]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[asdf-fortran]${NC} WARNING: $*" >&2; }
log_error() { echo -e "${RED}[asdf-fortran]${NC} ERROR: $*" >&2; }
fail() { log_error "$*"; exit 1; }

get_platform() {
  local os; os="$(uname -s)"
  case "${os}" in
    Linux*) echo "linux" ;;
    Darwin*) echo "darwin" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows64" ;;
    *) fail "Unsupported OS: ${os}" ;;
  esac
}

get_arch() {
  local arch; arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) fail "Unsupported arch: ${arch}" ;;
  esac
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

# Get download URL for gfortran (from GNAT-FSF-builds)
get_gfortran_download_url() {
  local version="${1}"
  local platform arch filename

  platform="$(get_platform)"
  arch="$(get_arch)"

  # GNAT-FSF-builds naming: gnat-x86_64-linux-14.1.0-1.tar.gz
  filename="gnat-${arch}-${platform}-${version}.tar.gz"

  echo "https://github.com/${GNAT_FSF_REPO}/releases/download/gnat-${version}/${filename}"
}

# Get download URL for LFortran
get_lfortran_download_url() {
  local version="${1}"
  local platform arch filename ext

  platform="$(get_platform)"
  arch="$(get_arch)"

  case "${platform}" in
    linux) ext="tar.gz" ;;
    darwin) ext="tar.gz" ;;
    windows64) ext="zip" ;;
  esac

  # LFortran naming: lfortran-0.35.0-linux.tar.gz
  if [[ "${arch}" == "aarch64" ]]; then
    filename="lfortran-${version}-${platform}-arm64.${ext}"
  else
    filename="lfortran-${version}-${platform}.${ext}"
  fi

  echo "https://github.com/${LFORTRAN_REPO}/releases/download/v${version}/${filename}"
}

get_download_url() {
  local version="${1}"

  if [[ "${version}" == lfortran-* ]]; then
    get_lfortran_download_url "${version#lfortran-}"
  else
    get_gfortran_download_url "${version}"
  fi
}

# List gfortran versions from GNAT-FSF-builds
list_gfortran_versions() {
  local api_url="${GITHUB_API_URL}/repos/${GNAT_FSF_REPO}/releases"
  local response

  response="$(curl_wrapper "${api_url}?per_page=100")" || return 1

  echo "${response}" | grep -oE '"tag_name":\s*"gnat-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+"' | \
    sed -E 's/"tag_name":\s*"gnat-([^"]+)"/\1/' | \
    sort -t. -k1,1n -k2,2n -k3,3n
}

# List LFortran versions
list_lfortran_versions() {
  local api_url="${GITHUB_API_URL}/repos/${LFORTRAN_REPO}/releases"
  local response

  response="$(curl_wrapper "${api_url}?per_page=100")" || return 1

  echo "${response}" | grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' | \
    sed -E 's/"tag_name":\s*"v([^"]+)"/lfortran-\1/' | \
    sort -t. -k1,1n -k2,2n -k3,3n
}

list_all_versions() {
  local gfortran_versions lfortran_versions

  gfortran_versions="$(list_gfortran_versions 2>/dev/null || echo "")"
  lfortran_versions="$(list_lfortran_versions 2>/dev/null || echo "")"

  echo "${gfortran_versions} ${lfortran_versions}" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//'
}

get_latest_stable() {
  list_gfortran_versions | tail -1
}

command_exists() { command -v "$1" &>/dev/null; }

check_dependencies() {
  local deps=("curl" "tar" "grep" "sed") missing=()
  for dep in "${deps[@]}"; do command_exists "${dep}" || missing+=("${dep}"); done
  if [[ ${#missing[@]} -gt 0 ]]; then fail "Missing: ${missing[*]}"; fi
}
