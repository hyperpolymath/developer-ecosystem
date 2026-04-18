#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

readonly REPO_ID="274080289"  # betwixt-labs/bebop (redirected)
export TOOL_NAME="bebop" TOOL_CMD="bebopc"

log_info() { echo "[asdf-bebop] $*" >&2; }
fail() { echo "[asdf-bebop] ERROR: $*" >&2; exit 1; }

get_platform() {
  case "$(uname -s)" in
    Linux*) echo "linux" ;;
    Darwin*) echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) fail "Unsupported platform: $(uname -s)" ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
  esac
}

curl_wrapper() {
  curl --silent --fail --location --retry 3 \
    ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@"
}

download_file() {
  curl --fail --location --retry 3 -o "$2" \
    ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$1"
}

list_all_versions() {
  curl_wrapper "https://api.github.com/repositories/${REPO_ID}/releases?per_page=100" |
    grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' |
    sed 's/"tag_name":\s*"v\([^"]*\)"/\1/' |
    sort -t. -k1,1n -k2,2n -k3,3n |
    tr '\n' ' '
}

get_latest_stable() {
  list_all_versions | tr ' ' '\n' | grep -v '^$' | tail -1
}

get_download_url() {
  local version="$1"
  local platform arch
  platform="$(get_platform)"
  arch="$(get_arch)"
  # bebopc-linux-x64.zip
  echo "https://github.com/betwixt-labs/bebop/releases/download/v${version}/bebopc-${platform}-${arch}.zip"
}

check_dependencies() {
  command -v curl &>/dev/null || fail "curl is required"
  command -v unzip &>/dev/null || fail "unzip is required"
}
