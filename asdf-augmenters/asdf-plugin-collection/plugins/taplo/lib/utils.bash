#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
set -euo pipefail
readonly REPO="tamasfe/taplo"
export TOOL_NAME="taplo" TOOL_CMD="taplo"
log_info() { echo "[asdf-taplo] $*" >&2; }
fail() { echo "[asdf-taplo] ERROR: $*" >&2; exit 1; }
get_platform() { case "$(uname -s)" in Linux*) echo "linux" ;; Darwin*) echo "darwin" ;; *) fail "Unsupported" ;; esac; }
get_arch() { case "$(uname -m)" in x86_64|amd64) echo "x86_64" ;; aarch64|arm64) echo "aarch64" ;; *) fail "Unsupported" ;; esac; }
curl_wrapper() { curl --silent --fail --location --retry 3 ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@"; }
download_file() { curl --fail --location --retry 3 -o "$2" ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$1"; }
list_all_versions() { curl_wrapper "https://api.github.com/repos/${REPO}/releases?per_page=100" | grep -oE '"tag_name":\s*"[0-9]+\.[0-9]+\.[0-9]+"' | sed 's/"tag_name":\s*"\([^"]*\)"/\1/' | sort -t. -k1,1n -k2,2n -k3,3n | tr '\n' ' '; }
get_latest_stable() { list_all_versions | tr ' ' '\n' | grep -v '^$' | tail -1; }
get_download_url() { local v="$1" p a; p="$(get_platform)"; a="$(get_arch)"; echo "https://github.com/${REPO}/releases/download/${v}/taplo-${p}-${a}.gz"; }
check_dependencies() { command -v curl &>/dev/null || fail "curl required"; command -v gunzip &>/dev/null || fail "gunzip required"; }
