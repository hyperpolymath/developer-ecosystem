#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# rust-tool.sh — compile-on-demand runner for the single-file Rust mint tools.
#
# Ruby was the previous implementation of these tools; it is not an
# estate-authorised language, so they are Rust now. Each tool is a single
# std-only file, which `rustc` compiles in well under a second with no
# dependency resolution and no build system.
#
# Binaries are cached, and rebuilt only when the source is newer, so a machine
# pays the compile cost once rather than once per mint. Override the cache
# location with RSR_MINT_TOOL_CACHE.
#
# Usage: scripts/rust-tool.sh <tool-name> [args...]

set -euo pipefail

name="${1:-}"
[ -n "$name" ] || { echo "rust-tool: usage: rust-tool.sh <tool-name> [args...]" >&2; exit 2; }
shift

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$scripts_dir/$name.rs"

[ -f "$src" ] || { echo "rust-tool: no such tool: $src" >&2; exit 2; }

cache="${RSR_MINT_TOOL_CACHE:-${TMPDIR:-/tmp}/rsr-mint-tools}"
mkdir -p "$cache"
bin="$cache/$name"

# Recompile only when the binary is missing or older than its source, so the
# common case is a straight exec.
if [ ! -x "$bin" ] || [ "$src" -nt "$bin" ]; then
    # The toolchain is needed to BUILD, not to RUN. Checking for rustc up
    # front made a cached binary unusable on a machine without one, which is
    # the common case in CI: the run is a straight exec. Only ask for rustc
    # when a build actually has to happen.
    command -v rustc >/dev/null 2>&1 || {
        echo "rust-tool: rustc not found, and $name is not built yet." >&2
        echo "           The mint tools are Rust and need a Rust toolchain." >&2
        echo "           Install one from https://rustup.rs, then re-run." >&2
        exit 2
    }
    rustc -O -o "$bin" "$src" >&2 || {
        echo "rust-tool: failed to compile $src" >&2
        exit 2
    }
fi

exec "$bin" "$@"
