#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# run-all.sh — execute every www/tests/check-*.sh probe in order.
# Exit non-zero on the first failing check (all checks are listed at the end).

set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Three outcomes, not two. A check whose INPUTS DO NOT APPLY to this repository
# (it publishes nothing, it declares no AIBDP, it has no migrator to test) must
# be able to say so. The alternative is what actually happened: the bundle was
# written for the template, and every repository it reached that was not the
# template got a red check it could do nothing about. A suite that fails where
# it does not apply teaches people to ignore it.
#
# SKIP is declared, never inferred. The check must exit 77 AND print a line
# beginning "SKIP:". Exit 77 alone is not enough — a crash can produce any
# status, and a crash reported as a skip would be a lie of exactly the kind
# this estate keeps finding in its own documentation.
fail=0
ran=0
skipped=0
for check in "$here"/check-*.sh; do
    [ -f "$check" ] || continue
    ran=$((ran + 1))
    name="$(basename "$check")"
    out="$(mktemp)"
    if bash "$check" >"$out" 2>&1; then
        rc=0
    else
        rc=$?
    fi
    cat "$out"
    if [ "$rc" -eq 0 ]; then
        echo "PASS  $name"
    elif [ "$rc" -eq 77 ] && grep -q '^SKIP:' "$out"; then
        echo "SKIP  $name"
        skipped=$((skipped + 1))
    else
        echo "FAIL  $name" >&2
        fail=$((fail + 1))
    fi
    rm -f "$out"
done

echo "www/tests: ran $ran check(s), $fail failure(s), $skipped skipped"
if [ "$skipped" -gt 0 ]; then
    echo "www/tests: $skipped check(s) did not apply here — see the SKIP lines above."
    echo "www/tests: this is not full coverage of the bundle."
fi
[ "$fail" -eq 0 ]
