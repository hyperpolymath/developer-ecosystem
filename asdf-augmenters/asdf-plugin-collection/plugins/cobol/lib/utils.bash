#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

TOOL_NAME="gnucobol"
BINARY_NAME="cobc"

fail() { echo -e "\e[31mFail:\e[m $*" >&2; exit 1; }

list_all_versions() {
  curl -sL "https://ftp.gnu.org/gnu/gnucobol/" 2>/dev/null | \
    grep -oE 'gnucobol-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar' | sed 's/gnucobol-//;s/\.tar$//' | sort -V | uniq
}

download_release() {
  local version="$1" download_path="$2"
  local url="https://ftp.gnu.org/gnu/gnucobol/gnucobol-${version}.tar.xz"

  echo "Downloading GnuCOBOL $version..."
  mkdir -p "$download_path"
  curl -fsSL "$url" -o "$download_path/gnucobol.tar.xz" || fail "Download failed"
  tar -xJf "$download_path/gnucobol.tar.xz" -C "$download_path" --strip-components=1
  rm -f "$download_path/gnucobol.tar.xz"
}

install_version() {
  local install_type="$1" version="$2" install_path="$3"

  cd "$ASDF_DOWNLOAD_PATH"
  ./configure --prefix="$install_path" || fail "Configure failed"
  make -j"$(nproc)" || fail "Build failed"
  make install || fail "Install failed"
}
