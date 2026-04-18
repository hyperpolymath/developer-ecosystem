#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
set -euo pipefail
readonly REPO="MariaDB/server"
export TOOL_NAME="mariadb" TOOL_CMD="mariadb"
log_info() { echo "[asdf-mariadb] $*" >&2; }
fail() { echo "[asdf-mariadb] ERROR: $*" >&2; exit 1; }
get_platform() { case "$(uname -s)" in Linux*) echo "linux" ;; Darwin*) echo "macos" ;; *) fail "Unsupported" ;; esac; }
get_arch() { case "$(uname -m)" in x86_64) echo "x86_64" ;; aarch64|arm64) echo "arm64" ;; *) fail "Unsupported" ;; esac; }
curl_wrapper() { curl --silent --fail --location --retry 3 ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@"; }
download_file() { curl --fail --location --retry 3 -o "$2" ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$1"; }
get_download_url() { local v="${1}" p="$(get_platform)" a="$(get_arch)"; echo "https://archive.mariadb.org/mariadb-${v}/bintar-${p}-${a}/mariadb-${v}-${p}-${a}.tar.gz"; }
list_all_versions() { curl_wrapper "https://api.github.com/repos/${REPO}/tags?per_page=100" | grep -oE '"name":\s*"mariadb-[0-9]+\.[0-9]+\.[0-9]+"' | sed 's/"name":\s*"mariadb-\([^"]*\)"/\1/' | sort -t. -k1,1n -k2,2n -k3,3n | tr '\n' ' '; }
get_latest_stable() { list_all_versions | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | tail -1; }
check_dependencies() { command -v curl &>/dev/null || fail "curl required"; }
