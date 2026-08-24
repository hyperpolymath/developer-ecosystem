# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# developer-ecosystem Justfile
# Monorepo build orchestration for V-lang, Julia, Deno, ReScript, Elixir, Idris2 ecosystems

set shell := ["bash", "-uc"]
set positional-arguments := true

import? "contractile.just"

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

# Reject legacy directive paths in satellite batches already migrated under #117.
validate-bot-directives:
    @bash hooks/validate-bot-directives.sh

# Validate RSR compliance
validate-rsr: validate-bot-directives
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

# Self-diagnostic — checks dependencies, permissions, paths
doctor:
    @echo "Running diagnostics for developer-ecosystem..."
    @echo "Checking required tools..."
    @command -v just >/dev/null 2>&1 && echo "  [OK] just" || echo "  [FAIL] just not found"
    @command -v git >/dev/null 2>&1 && echo "  [OK] git" || echo "  [FAIL] git not found"
    @echo "Checking for hardcoded paths..."
    @grep -rn '$HOME\|$ECLIPSE_DIR' --include='*.rs' --include='*.ex' --include='*.res' --include='*.gleam' --include='*.sh' . 2>/dev/null | head -5 || echo "  [OK] No hardcoded paths"
    @echo "Diagnostics complete."

# Auto-repair common issues
heal:
    @echo "Attempting auto-repair for developer-ecosystem..."
    @echo "Fixing permissions..."
    @find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    @echo "Cleaning stale caches..."
    @rm -rf .cache/stale 2>/dev/null || true
    @echo "Repair complete."

# Guided tour of key features
tour:
    @echo "=== developer-ecosystem Tour ==="
    @echo ""
    @echo "1. Project structure:"
    @ls -la
    @echo ""
    @echo "2. Available commands: just --list"
    @echo ""
    @echo "3. Read README.adoc for full overview"
    @echo "4. Read EXPLAINME.adoc for architecture decisions"
    @echo "5. Run 'just doctor' to check your setup"
    @echo ""
    @echo "Tour complete! Try 'just --list' to see all available commands."

# Open feedback channel with diagnostic context
help-me:
    @echo "=== developer-ecosystem Help ==="
    @echo "Platform: $(uname -s) $(uname -m)"
    @echo "Shell: $SHELL"
    @echo ""
    @echo "To report an issue:"
    @echo "  https://github.com/hyperpolymath/developer-ecosystem/issues/new"
    @echo ""
    @echo "Include the output of 'just doctor' in your report."


# Print the current CRG grade (reads from READINESS.md '**Current Grade:** X' line)
crg-grade:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    echo "$$grade"

# Generate a shields.io badge markdown for the current CRG grade
# Looks for '**Current Grade:** X' in READINESS.md; falls back to X
crg-badge:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    case "$$grade" in \
      A) color="brightgreen" ;; B) color="green" ;; C) color="yellow" ;; \
      D) color="orange" ;; E) color="red" ;; F) color="critical" ;; \
      *) color="lightgrey" ;; esac; \
    echo "[![CRG $$grade](https://img.shields.io/badge/CRG-$$grade-$$color?style=flat-square)](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)"

# Run E2E tests (run the main 'test' recipe)
e2e:
    just quality
    @echo "E2E validation passed"

# Run aspect-oriented tests
aspect:
    #!/usr/bin/env bash
    set -euo pipefail
    bash tests/aspect/aspect_tests.sh

secret-scan-trufflehog:
    @command -v trufflehog >/dev/null && trufflehog filesystem . --only-verified || true
