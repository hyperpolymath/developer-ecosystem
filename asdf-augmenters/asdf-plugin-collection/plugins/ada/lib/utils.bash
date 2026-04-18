#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

TOOL_NAME="gnat"
BINARY_NAME="gnat"

fail() { echo -e "\e[31mFail:\e[m $*" >&2; exit 1; }

get_platform() {
  case "$(uname -s)" in
    Darwin) echo "darwin" ;;
    Linux) echo "linux" ;;
    *) fail "Unsupported OS" ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x86_64" ;;
    aarch64|arm64) echo "aarch64" ;;
    *) fail "Unsupported arch" ;;
  esac
}

list_all_versions() {
  local curl_opts=(-sL)
  [[ -n "${GITHUB_TOKEN:-}" ]] && curl_opts+=(-H "Authorization: token $GITHUB_TOKEN")
  curl "${curl_opts[@]}" "https://api.github.com/repos/alire-project/GNAT-FSF-builds/releases" 2>/dev/null | \
    grep -o '"tag_name": "[^"]*"' | sed 's/"tag_name": "v\?//' | sed 's/"$//' | sort -V
}

download_release() {
  local version="$1" download_path="$2"
  local os="$(get_platform)" arch="$(get_arch)"
  local url="https://github.com/alire-project/GNAT-FSF-builds/releases/download/gnat-${version}/gnat-${arch}-${os}-${version}.tar.gz"

  echo "Downloading GNAT $version..."
  mkdir -p "$download_path"
  curl -fsSL "$url" -o "$download_path/gnat.tar.gz" || fail "Download failed"
  tar -xzf "$download_path/gnat.tar.gz" -C "$download_path" --strip-components=1
  rm -f "$download_path/gnat.tar.gz"
}

install_version() {
  local install_type="$1" version="$2" install_path="$3"
  cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path/"
  chmod +x "$install_path/bin/"* 2>/dev/null || true
}
