#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Exercise envelope handling using the actual Nickel evaluator.
set -euo pipefail
repo=$(git rev-parse --show-toplevel)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/session"
cp "$repo/coordination.k9.ncl" "$fixture/coordination.k9.ncl"
cp "$repo/session/custom-checks.k9.ncl" "$fixture/session/custom-checks.k9.ncl"
cd "$fixture"
bash "$repo/scripts/validate-session-contracts.sh"
{ printf '\n   \n'; cat "$repo/coordination.k9.ncl"; } > coordination.k9.ncl
bash "$repo/scripts/validate-session-contracts.sh"
printf '\n{ value = 1 }\n' > coordination.k9.ncl
if bash "$repo/scripts/validate-session-contracts.sh"; then
    echo 'FAIL: missing envelope accepted' >&2
    exit 1
fi
printf '\nK9!\n{ invalid = }\n' > coordination.k9.ncl
if bash "$repo/scripts/validate-session-contracts.sh"; then
    echo 'FAIL: invalid Nickel accepted' >&2
    exit 1
fi
echo 'PASS: leading blanks, missing envelope, and invalid Nickel controls'
