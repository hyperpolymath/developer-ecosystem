#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# End-to-end: build the `cfk` binary, drive it against a scratch directory,
# and verify the reversible journal restores every destructive operation.
#
# Usage: bash tests/e2e.sh   (or: just e2e)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

ok()   { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
expect_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }

echo "Building cfk..."
cargo build --quiet --manifest-path "$PROJECT_DIR/Cargo.toml" -p cfk-cli
CFK="$PROJECT_DIR/target/debug/cfk"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CFK_JOURNAL_DIR="$WORK/.journal"
cd "$WORK"

echo "one" > a.txt

# 1. rm + undo restores content
"$CFK" rm a.txt
[ ! -e a.txt ] && ok "rm removes file" || bad "rm removes file"
"$CFK" undo
expect_eq "undo restores deleted file" "one" "$(cat a.txt 2>/dev/null || true)"

# 2. mv + undo restores original name
"$CFK" mv a.txt b.txt
"$CFK" undo
[ -e a.txt ] && [ ! -e b.txt ] && ok "undo reverses move" || bad "undo reverses move"

# 3. cp over existing file + undo restores the overwritten content
echo "two" > c.txt
"$CFK" cp --force a.txt c.txt
expect_eq "cp overwrote destination" "one" "$(cat c.txt)"
"$CFK" undo
expect_eq "undo restores overwritten destination" "two" "$(cat c.txt)"

# 4. recursive rm + undo restores tree
mkdir -p d/sub && echo x > d/x && echo y > d/sub/y
"$CFK" rm -r d
"$CFK" undo
expect_eq "undo restores nested file" "y" "$(cat d/sub/y 2>/dev/null || true)"

# 5. history records operations and undos
HIST="$("$CFK" history -n 50)"
printf '%s\n' "$HIST" | grep -q "(undone)" && ok "history marks undone ops" || bad "history marks undone ops"

# 6. nothing left to undo is an error, not a silent success
if "$CFK" undo >/dev/null 2>&1; then bad "empty undo fails"; else ok "empty undo fails"; fi

echo
echo "E2E: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
