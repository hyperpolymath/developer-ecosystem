#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
readonly REPO="AGWA/git-crypt"
export TOOL_NAME="git-crypt" TOOL_CMD="git-crypt"
log_info() { echo "[asdf-git-crypt] $*" >&2; }
fail() { echo "[asdf-git-crypt] ERROR: $*" >&2; exit 1; }
get_platform() { case "$(uname -s)" in Linux*) echo "linux" ;; *) fail "git-crypt binaries only for Linux" ;; esac; }
get_arch() { case "$(uname -m)" in x86_64|amd64) echo "x86_64" ;; *) fail "git-crypt binaries only for x86_64" ;; esac; }
curl_wrapper() { curl --silent --fail --location --retry 3 ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@"; }
download_file() { curl --fail --location --retry 3 -o "$2" ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$1"; }
list_all_versions() { curl_wrapper "https://api.github.com/repos/${REPO}/releases?per_page=100" | grep -oE '"tag_name":\s*"[0-9]+\.[0-9]+\.[0-9]+"' | sed 's/"tag_name":\s*"\([^"]*\)"/\1/' | sort -t. -k1,1n -k2,2n -k3,3n | tr '\n' ' '; }
get_latest_stable() { list_all_versions | tr ' ' '\n' | grep -v '^$' | tail -1; }
get_download_url() { local v="$1"; echo "https://github.com/${REPO}/releases/download/${v}/git-crypt-${v}-linux-x86_64"; }
check_dependencies() { command -v curl &>/dev/null || fail "curl required"; }
