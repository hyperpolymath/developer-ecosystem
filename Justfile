# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# developer-ecosystem Justfile
# Monorepo build orchestration for V-lang, Julia, Deno, ReScript, Elixir, Idris2 ecosystems

set shell := ["bash", "-uc"]
set positional-arguments := true

project := "developer-ecosystem"
version := "0.1.0"

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT & HELP
# ═══════════════════════════════════════════════════════════════════════════════

# Show all available recipes
default:
    @just --list --unsorted

# ═══════════════════════════════════════════════════════════════════════════════
# V-LANG ECOSYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

# Compile all V-lang API interfaces
v-build:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Building V-lang API interfaces ==="
    cd v-ecosystem/v_api_interfaces
    errors=0
    for d in v_*/; do
        [ -f "$d/src/"*.v ] 2>/dev/null || continue
        name="${d%/}"
        if v -shared "$d/src/" 2>/dev/null; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name"
            errors=$((errors+1))
        fi
    done
    echo ""
    if [ $errors -eq 0 ]; then
        echo "All V modules compiled successfully."
    else
        echo "$errors module(s) failed."
        exit 1
    fi

# Run all V-lang tests
v-test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== Testing V-lang API interfaces ==="
    cd v-ecosystem/v_api_interfaces
    errors=0
    for d in v_*/; do
        [ -d "$d/tests" ] || continue
        name="${d%/}"
        if v test "$d/tests/" 2>/dev/null; then
            echo "  ✓ $name"
        else
            echo "  ✗ $name"
            errors=$((errors+1))
        fi
    done
    echo ""
    if [ $errors -eq 0 ]; then
        echo "All V tests passed."
    else
        echo "$errors module(s) failed tests."
        exit 1
    fi

# Format all V source files
v-fmt:
    #!/usr/bin/env bash
    echo "=== Formatting V-lang source ==="
    find v-ecosystem/v_api_interfaces -name "*.v" -exec v fmt {} \;
    echo "Done."

# List V-lang connector coverage
v-coverage:
    #!/usr/bin/env bash
    echo "=== V-lang Connector Coverage ==="
    total=$(ls -d v-ecosystem/v_api_interfaces/v_*/ 2>/dev/null | wc -l)
    echo "Total connectors: $total"
    echo ""
    for d in v-ecosystem/v_api_interfaces/v_*/; do
        name=$(basename "$d")
        src=$(find "$d/src" -name "*.v" 2>/dev/null | wc -l)
        tests=$(find "$d/tests" -name "*.v" 2>/dev/null | wc -l)
        echo "  $name: $src src, $tests test files"
    done

# ═══════════════════════════════════════════════════════════════════════════════
# QUALITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run all quality checks
quality: v-build v-test
    @echo "Quality checks complete."

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "WARN: panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

# Validate RSR compliance
validate-rsr:
    #!/usr/bin/env bash
    echo "=== RSR Compliance Check ==="
    MISSING=""
    for f in .editorconfig LICENSE 0-AI-MANIFEST.a2ml README.adoc SECURITY.md CONTRIBUTING.md; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    for f in .machine_readable/6a2/STATE.a2ml .machine_readable/6a2/META.a2ml .machine_readable/6a2/ECOSYSTEM.a2ml; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    for f in .machine_readable/contractiles/must/Mustfile.a2ml .machine_readable/contractiles/trust/Trustfile.a2ml .machine_readable/contractiles/dust/Dustfile.a2ml; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    if [ -z "$MISSING" ]; then
        echo "All RSR files present."
    else
        echo "MISSING:$MISSING"
        exit 1
    fi
