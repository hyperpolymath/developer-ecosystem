#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# repo_map_determinism_test.sh — the repository map must generate identically
# in every environment, not merely repeatably in one.
#
# The CI freshness check compares a committed map against a freshly generated
# one. That check is only meaningful if the generator is environment-independent.
# It was not: `sort` is locale-dependent, so under en_US.UTF-8 dotfiles
# interleaved with ordinary names while under LC_ALL=C they sorted first. The
# generator produced stable output when run twice in one shell and DIFFERENT
# output in CI — which the freshness gate caught on its first real run.
#
# Running the generator twice cannot detect that. The locale must be varied.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GEN="$ROOT/scripts/gen-repo-map.sh"
MAP="$ROOT/docs/architecture/REPOSITORY-MAP.adoc"

[ -x "$GEN" ] || [ -f "$GEN" ] || { echo "FAIL: generator not found at $GEN" >&2; exit 1; }

ORIGINAL=$(mktemp); trap 'cp "$ORIGINAL" "$MAP" 2>/dev/null; rm -f "$ORIGINAL"' EXIT
cp "$MAP" "$ORIGINAL"

prev=""
for loc in C en_US.UTF-8 C.UTF-8 POSIX; do
    LC_ALL="$loc" bash "$GEN" "$ROOT" >/dev/null 2>&1 || {
        echo "FAIL: generator errored under LC_ALL=$loc" >&2; exit 1; }
    sum=$(sha256sum "$MAP" | cut -d' ' -f1)
    if [ -n "$prev" ] && [ "$sum" != "$prev" ]; then
        echo "FAIL: map differs under LC_ALL=$loc — the generator is locale-dependent." >&2
        echo "      Sort with LC_ALL=C (or export it) so output is byte-identical everywhere." >&2
        exit 1
    fi
    prev="$sum"
done

# And the committed map must match a fresh generation, or CI is already stale.
if ! diff -q "$ORIGINAL" "$MAP" >/dev/null 2>&1; then
    echo "FAIL: committed REPOSITORY-MAP.adoc is stale — run: just repo-map" >&2
    exit 1
fi

echo "PASS: repository map is byte-identical across locales, and committed copy is current"
