#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

readonly REPO="dhall-lang/dhall-haskell"
export TOOL_NAME="dhall" TOOL_CMD="dhall"

log_info() { echo "[asdf-dhall] $*" >&2; }
fail() { echo "[asdf-dhall] ERROR: $*" >&2; exit 1; }

get_platform() {
  case "$(uname -s)" in
    Linux*) echo "linux" ;;
    Darwin*) echo "darwin" ;;
    *) fail "Unsupported platform: $(uname -s)" ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
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
    grep -oE '"tag_name":\s*"[0-9]+\.[0-9]+\.[0-9]+"' |
    sed 's/"tag_name":\s*"\([^"]*\)"/\1/' |
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
  # dhall-1.42.2-x86_64-linux.tar.bz2
  echo "https://github.com/${REPO}/releases/download/${version}/dhall-${version}-${arch}-${platform}.tar.bz2"
}

check_dependencies() {
  command -v curl &>/dev/null || fail "curl is required"
  command -v tar &>/dev/null || fail "tar is required"
  command -v bzip2 &>/dev/null || fail "bzip2 is required"
}
