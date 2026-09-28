#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Verify plain Nickel and K9!-enveloped inputs for validate-session-contracts.sh.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
printf '%s\n' '{ value = 1 }' > "$fixture/plain.ncl"
printf '%s\n' 'K9!' '{ value = 1 }' > "$fixture/wrapped.k9.ncl"
printf '%s\n' '' '   ' 'K9!' '{ value = 1 }' > "$fixture/leading-blank-wrapped.k9.ncl"
printf '%s\n' 'K9!' '{ value = }' > "$fixture/bad.k9.ncl"
bash "$root/scripts/validate-session-contracts.sh" --typecheck "$fixture/plain.ncl" "$fixture/wrapped.k9.ncl" "$fixture/leading-blank-wrapped.k9.ncl"
if bash "$root/scripts/validate-session-contracts.sh" --typecheck "$fixture/bad.k9.ncl"; then
    echo 'Invalid Nickel was accepted' >&2
    exit 1
fi
echo 'PASS: plain and wrapped Nickel accepted, including leading blanks; malformed Nickel rejected'
