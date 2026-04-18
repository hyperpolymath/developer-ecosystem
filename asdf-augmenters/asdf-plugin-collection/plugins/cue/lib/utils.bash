#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

readonly REPO="cue-lang/cue"
export TOOL_NAME="cue" TOOL_CMD="cue"

log_info() { echo "[asdf-cue] $*" >&2; }
fail() { echo "[asdf-cue] ERROR: $*" >&2; exit 1; }

get_platform() {
  case "$(uname -s)" in
    Linux*) echo "linux" ;;
    Darwin*) echo "darwin" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) fail "Unsupported platform: $(uname -s)" ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
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
  curl_wrapper "https://api.github.com/repos/${REPO}/releases?per_page=100" |
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
  local platform arch ext="tar.gz"
  platform="$(get_platform)"
  arch="$(get_arch)"
  [[ "${platform}" == "windows" ]] && ext="zip"
  # cue_v0.15.3_linux_amd64.tar.gz
  echo "https://github.com/${REPO}/releases/download/v${version}/cue_v${version}_${platform}_${arch}.${ext}"
}

check_dependencies() {
  command -v curl &>/dev/null || fail "curl is required"
  command -v tar &>/dev/null || fail "tar is required"
}
