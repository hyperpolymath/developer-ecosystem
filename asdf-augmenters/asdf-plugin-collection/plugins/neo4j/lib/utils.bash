#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Philosophical overlay: https://github.com/hyperpolymath/palimpsest-licence
set -euo pipefail
readonly REPO="neo4j/neo4j"
export TOOL_NAME="neo4j" TOOL_CMD="neo4j"
log_info() { echo "[asdf-neo4j] $*" >&2; }
fail() { echo "[asdf-neo4j] ERROR: $*" >&2; exit 1; }
curl_wrapper() { curl --silent --fail --location --retry 3 ${GITHUB_TOKEN:+--header "Authorization: token ${GITHUB_TOKEN}"} "$@"; }
download_file() { curl --fail --location --retry 3 -o "$2" "$1"; }
get_download_url() { echo "https://dist.neo4j.org/neo4j-community-${1}-unix.tar.gz"; }
list_all_versions() { curl_wrapper "https://api.github.com/repos/${REPO}/releases?per_page=100" | grep -oE '"tag_name":\s*"[0-9]+\.[0-9]+\.[0-9]+"' | sed 's/"tag_name":\s*"\([^"]*\)"/\1/' | sort -t. -k1,1n -k2,2n -k3,3n | tr '\n' ' '; }
get_latest_stable() { list_all_versions | tr ' ' '\n' | tail -1; }
check_dependencies() { command -v curl &>/dev/null || fail "curl required"; }
