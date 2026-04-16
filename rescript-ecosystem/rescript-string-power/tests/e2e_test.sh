#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# T3 — End-to-end test: build the string-union-gen CLI and run it against a
# fixture .res file, verifying the generated output is well-formed.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT

# Build CLI (release for speed after first build)
echo "  • building CLI..."
(cd "$ROOT/tools/string-union-gen" && cargo build --release --quiet)

CLI="$ROOT/tools/string-union-gen/target/release/string-union-gen"
[ -x "$CLI" ] || { echo "  ✗ CLI binary missing: $CLI"; exit 1; }

# Create a fixture .res file with @stringUnion annotations
cat > "$FIXTURE_DIR/Fixture.res" <<'EOF'
// SPDX-License-Identifier: PMPL-1.0-or-later
@stringUnion
type colour = [#red | #green | #blue]

@stringUnion
type method = [
  | @as("GET") #get
  | @as("POST") #post
  | @as("DELETE") #delete
]
EOF

# Run the CLI
echo "  • running CLI on fixture..."
"$CLI" -s "$FIXTURE_DIR" -o "$FIXTURE_DIR" --verbose

GENERATED="$FIXTURE_DIR/Fixture__strings.res"
[ -f "$GENERATED" ] || { echo "  ✗ Generated file missing: $GENERATED"; exit 1; }

# Verify content
echo "  • verifying generated output..."
assert_contains() {
    if grep -q -- "$1" "$GENERATED"; then
        printf '    ✓ contains: %s\n' "$1"
    else
        printf '    ✗ missing:  %s\n' "$1"
        cat "$GENERATED"
        exit 1
    fi
}

assert_contains "colourToString"
assert_contains "stringToColour"
assert_contains "stringToColourExn"
assert_contains "allColourValues"
assert_contains "allColourStrings"
assert_contains '"red"'
assert_contains '"green"'
assert_contains '"blue"'
assert_contains "methodToString"
assert_contains '"GET"'
assert_contains '"POST"'
assert_contains '"DELETE"'

# Dry-run should not create files
echo "  • verifying --dry-run suppresses writes..."
DRY_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR" "$DRY_DIR"' EXIT
cp "$FIXTURE_DIR/Fixture.res" "$DRY_DIR/"
"$CLI" -s "$DRY_DIR" -o "$DRY_DIR" --dry-run > /dev/null
if [ -f "$DRY_DIR/Fixture__strings.res" ]; then
    echo "    ✗ --dry-run wrote a file"
    exit 1
fi
echo "    ✓ --dry-run did not write"

echo "  ✓ e2e complete"
