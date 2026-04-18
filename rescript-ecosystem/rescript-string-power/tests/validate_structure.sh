#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# T1 — Structural checks for rescript-string-power.
# Verifies the repository layout, required files, and SPDX headers.

set -euo pipefail

PASS=0
FAIL=0

check() {
    local label="$1"
    local cond="$2"
    if eval "$cond"; then
        printf '  ✓ %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf '  ✗ %s\n' "$label"
        FAIL=$((FAIL + 1))
    fi
}

echo "── Required RSR files ──"
check "README.adoc present"            '[ -f README.adoc ]'
check "LICENSE present"                '[ -f LICENSE ]'
check "SECURITY.md present"            '[ -f SECURITY.md ]'
check "CONTRIBUTING.adoc present"      '[ -f CONTRIBUTING.adoc ]'
check "CODE_OF_CONDUCT.md present"     '[ -f CODE_OF_CONDUCT.md ]'
check "CHANGELOG.adoc present"         '[ -f CHANGELOG.adoc ]'
check "EXPLAINME.adoc present"         '[ -f EXPLAINME.adoc ]'
check "0-AI-MANIFEST.a2ml present"     '[ -f 0-AI-MANIFEST.a2ml ]'
check "READINESS.md present"           '[ -f READINESS.md ]'
check "TEST-NEEDS.md present"          '[ -f TEST-NEEDS.md ]'
check ".well-known/security.txt"       '[ -f .well-known/security.txt ]'
check ".github/FUNDING.yml"            '[ -f .github/FUNDING.yml ]'
check ".github/workflows/ci.yml"       '[ -f .github/workflows/ci.yml ]'

echo ""
echo "── License compliance ──"
check "LICENSE is PMPL-1.0-or-later"   'grep -q "PMPL-1.0-or-later" LICENSE'
check "no MIT text in LICENSE"         '! grep -q "^MIT License" LICENSE'

echo ""
echo "── Source files ──"
check "src/StringPower.res"            '[ -f src/StringPower.res ]'
check "src/Examples.res"               '[ -f src/Examples.res ]'
check "src/StringUnionExamples.res"    '[ -f src/StringUnionExamples.res ]'
check "tests/StringPower_test.res"     '[ -f tests/StringPower_test.res ]'

echo ""
echo "── SPDX headers on source files ──"
for f in src/*.res tests/*.res tools/string-union-gen/src/main.rs; do
    # shellcheck disable=SC2016  # the command is expanded later inside check() by eval
    check "SPDX in $f" 'grep -q "SPDX-License-Identifier: PMPL-1.0-or-later" "$f"'
done

echo ""
echo "── Rust CLI ──"
check "Cargo.toml present"             '[ -f tools/string-union-gen/Cargo.toml ]'
check "Cargo.toml license set to PMPL" 'grep -q "LicenseRef-PMPL-1.0-or-later" tools/string-union-gen/Cargo.toml'
check "main.rs present"                '[ -f tools/string-union-gen/src/main.rs ]'

echo ""
echo "── Test targets (6) ──"
check "validate_structure.sh"          '[ -f tests/validate_structure.sh ]'
check "e2e_test.sh"                    '[ -f tests/e2e_test.sh ]'
check "property_test.mjs"              '[ -f tests/property_test.mjs ]'
check "bench_test.mjs"                 '[ -f tests/bench_test.mjs ]'
check "justfile has test-structure"    'grep -q "^test-structure:" Justfile'
check "justfile has test-unit"         'grep -q "^test-unit:" Justfile'
check "justfile has test-e2e"          'grep -q "^test-e2e:" Justfile'
check "justfile has test-property"     'grep -q "^test-property:" Justfile'
check "justfile has test-bench"        'grep -q "^test-bench:" Justfile'
check "justfile has test-lint"         'grep -q "^test-lint:" Justfile'

echo ""
echo "──────────────────────────────"
printf "Structural checks: %d passed, %d failed\n" "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
