#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
set -euo pipefail

readonly REPO="arangodb/arangodb"
readonly GITHUB_API_URL="https://api.github.com"
export TOOL_NAME="arangodb" TOOL_CMD="arangosh"

log_info() { echo "[asdf-arangodb] $*" >&2; }
log_error() { echo "[asdf-arangodb] ERROR: $*" >&2; }
fail() { log_error "$*"; exit 1; }

get_platform() {
  case "$(uname -s)" in
    Linux*) echo "linux" ;; Darwin*) echo "macos" ;; *) fail "Unsupported OS" ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x86_64" ;; aarch64|arm64) echo "arm64" ;; *) fail "Unsupported arch" ;;
  esac
}

curl_wrapper() {
  local url="${1}"; shift
  curl --silent --show-error --fail --location --retry 3 ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@" "${url}"
}

download_file() {
  local url="${1}" output="${2}"
  curl --fail --location --retry 3 --output "${output}" ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "${url}"
}

get_download_url() {
  local version="${1}" platform arch
  platform="$(get_platform)"
  arch="$(get_arch)"
  # ArangoDB download format varies; using official download server
  echo "https://download.arangodb.com/arangodb312/Community/Linux/arangodb3-linux-${version}.tar.gz"
}

list_all_versions() {
  curl_wrapper "${GITHUB_API_URL}/repos/${REPO}/releases?per_page=100" | \
    grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' | \
    sed -E 's/"tag_name":\s*"v([^"]+)"/\1/' | sort -t. -k1,1n -k2,2n -k3,3n | tr '\n' ' '
}

get_latest_stable() { list_all_versions | tr ' ' '\n' | tail -1; }
check_dependencies() { command -v curl &>/dev/null || fail "curl required"; }
