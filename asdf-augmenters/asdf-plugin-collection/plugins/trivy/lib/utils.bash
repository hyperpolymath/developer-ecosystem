#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

readonly REPO="aquasecurity/trivy"
export TOOL_NAME="trivy" TOOL_CMD="trivy"

log_info() { echo "[asdf-trivy] $*" >&2; }
fail() { echo "[asdf-trivy] ERROR: $*" >&2; exit 1; }

get_platform() {
  case "$(uname -s)" in
    Linux*) echo "Linux" ;;
    Darwin*) echo "macOS" ;;
    *) fail "Unsupported platform" ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "64bit" ;;
    aarch64|arm64) echo "ARM64" ;;
    *) fail "Unsupported arch" ;;
  esac
}

curl_wrapper() { curl --silent --fail --location --retry 3 ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@"; }
download_file() { curl --fail --location --retry 3 -o "$2" ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$1"; }

list_all_versions() {
  curl_wrapper "https://api.github.com/repos/${REPO}/releases?per_page=100" |
    grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' |
    sed 's/"tag_name":\s*"v\([^"]*\)"/\1/' | sort -t. -k1,1n -k2,2n -k3,3n | tr '\n' ' '
}

get_latest_stable() { list_all_versions | tr ' ' '\n' | grep -v '^$' | tail -1; }

get_download_url() {
  local version="$1" platform arch
  platform="$(get_platform)"; arch="$(get_arch)"
  echo "https://github.com/${REPO}/releases/download/v${version}/trivy_${version}_${platform}-${arch}.tar.gz"
}

check_dependencies() { command -v curl &>/dev/null || fail "curl required"; }
