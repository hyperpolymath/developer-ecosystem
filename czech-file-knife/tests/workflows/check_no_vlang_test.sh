#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

CHECKER="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/check-no-vlang.sh"
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT

git -C "$FIXTURE" init -q
git -C "$FIXTURE" config user.name "RSR fixture"
git -C "$FIXTURE" config user.email "fixture@example.invalid"

printf '%s\n' 'pub fn main() void {}' > "$FIXTURE/build.zig"
printf '%s\n' 'Zig is the supported FFI language.' > "$FIXTURE/README.adoc"
git -C "$FIXTURE" add build.zig README.adoc

"$CHECKER" "$FIXTURE" | grep -q '^PASS:'

printf '%s\n' 'import vweb' > "$FIXTURE/legacy.txt"
git -C "$FIXTURE" add legacy.txt
if "$CHECKER" "$FIXTURE" > "$FIXTURE/content.out" 2>&1; then
    echo "FAIL: checker accepted tracked V-language content" >&2
    exit 1
fi
grep -q 'legacy.txt' "$FIXTURE/content.out"

git -C "$FIXTURE" reset -q legacy.txt
rm "$FIXTURE/legacy.txt"
printf '%s\n' 'Module {}' > "$FIXTURE/v.mod"
git -C "$FIXTURE" add v.mod
if "$CHECKER" "$FIXTURE" > "$FIXTURE/module.out" 2>&1; then
    echo "FAIL: checker accepted a tracked v.mod" >&2
    exit 1
fi
grep -q 'tracked module file: v.mod' "$FIXTURE/module.out"

git -C "$FIXTURE" reset -q v.mod
rm "$FIXTURE/v.mod"

# A NEW call site must not be reported as a V-language reference. The
# :(exclude) list in the checker can only name call sites that already exist,
# so a repo that invokes the gate from its Justfile (or a hook, or another
# workflow) used to fail with a false positive on the invocation line itself.
printf 'test:\n\tbash scripts/check-no-vlang.sh .\n' > "$FIXTURE/Justfile"
git -C "$FIXTURE" add Justfile
if ! "$CHECKER" "$FIXTURE" | grep -q '^PASS:'; then
    echo "FAIL: checker false-positived on its own invocation line" >&2
    exit 1
fi

# ...but a real reference on the SAME line as an invocation is still caught,
# so the self-reference filter cannot be used to smuggle V past the gate.
printf 'test:\n\tbash scripts/check-no-vlang.sh . && vlang build\n' > "$FIXTURE/Justfile"
if "$CHECKER" "$FIXTURE" > "$FIXTURE/mixed.out" 2>&1; then
    echo "FAIL: checker missed a V reference sharing a line with its invocation" >&2
    exit 1
fi
grep -q 'Justfile' "$FIXTURE/mixed.out"

echo "PASS: Zig allowed; V content and v.mod rejected; new call sites not false-positived"
