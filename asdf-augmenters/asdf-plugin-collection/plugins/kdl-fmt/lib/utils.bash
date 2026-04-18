#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
set -euo pipefail
readonly REPO="dj95/kdl-fmt"
export TOOL_NAME="kdl-fmt" TOOL_CMD="kdl-fmt"
log_info() { echo "[asdf-kdl-fmt] $*" >&2; }
fail() { echo "[asdf-kdl-fmt] ERROR: $*" >&2; exit 1; }
get_platform() { case "$(uname -s)" in Linux*) echo "unknown-linux-musl" ;; Darwin*) echo "apple-darwin" ;; *) fail "Unsupported" ;; esac; }
get_arch() { case "$(uname -m)" in x86_64|amd64) echo "x86_64" ;; aarch64|arm64) echo "aarch64" ;; *) fail "Unsupported" ;; esac; }
curl_wrapper() { curl --silent --fail --location --retry 3 ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@"; }
download_file() { curl --fail --location --retry 3 -o "$2" ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$1"; }
list_all_versions() { curl_wrapper "https://api.github.com/repos/${REPO}/releases?per_page=100" | grep -oE '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' | sed 's/"tag_name":\s*"v\([^"]*\)"/\1/' | sort -t. -k1,1n -k2,2n -k3,3n | tr '\n' ' '; }
get_latest_stable() { list_all_versions | tr ' ' '\n' | grep -v '^$' | tail -1; }
get_download_url() { local v="$1" a p; a="$(get_arch)"; p="$(get_platform)"; echo "https://github.com/${REPO}/releases/download/v${v}/kdl-fmt.${a}-${p}.tar.gz"; }
check_dependencies() { command -v curl &>/dev/null || fail "curl required"; command -v tar &>/dev/null || fail "tar required"; }
