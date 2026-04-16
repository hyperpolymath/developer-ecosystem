# idaptik Justfile

set shell := ["bash", "-uc"]

# Default: list all recipes
import? "contractile.just"

default:
    @just --list --unsorted

# Start full development environment
dev:
    deno task dev

# Build the project
build:
    deno task build

# Lint and format
lint:
    deno task lint

# Clean build artifacts
clean:
    deno task res:clean
    rm -rf dist/
    rm -rf .assetpack/

# Run all tests (shared + VM)
test: test-shared test-vm

# Run shared tests only
test-shared:
    deno run --node-modules-dir=auto --allow-read --allow-env shared/tests/test_all.res.js

# Run VM tests only
test-vm:
    deno run --node-modules-dir=auto --allow-read --allow-env vm/tests/test_all.res.mjs

# Build the UMS Zig FFI
ums-build:
    cd idaptik-ums/ffi/zig && zig build

# Run UMS Zig FFI tests
ums-test:
    cd idaptik-ums/ffi/zig && zig build test

# Cargo check the UMS Tauri shell
ums-tauri:
    cd idaptik-ums/src-tauri && cargo check

# Run all validation (tests + Zig + Tauri)
validate: test ums-build ums-test ums-tauri

# Check for ReScript build warnings
warnings:
    deno task res:build 2>&1 | grep -i "warning" || echo "No warnings found."

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"

# Self-diagnostic — checks dependencies, permissions, paths
doctor:
    @echo "Running diagnostics for idaptik-rescript13-staging..."
    @echo "Checking required tools..."
    @command -v just >/dev/null 2>&1 && echo "  [OK] just" || echo "  [FAIL] just not found"
    @command -v git >/dev/null 2>&1 && echo "  [OK] git" || echo "  [FAIL] git not found"
    @echo "Checking for hardcoded paths..."
    @grep -rn '$HOME\|$ECLIPSE_DIR' --include='*.rs' --include='*.ex' --include='*.res' --include='*.gleam' --include='*.sh' . 2>/dev/null | head -5 || echo "  [OK] No hardcoded paths"
    @echo "Diagnostics complete."

# Auto-repair common issues
heal:
    @echo "Attempting auto-repair for idaptik-rescript13-staging..."
    @echo "Fixing permissions..."
    @find . -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    @echo "Cleaning stale caches..."
    @rm -rf .cache/stale 2>/dev/null || true
    @echo "Repair complete."

# Guided tour of key features
tour:
    @echo "=== idaptik-rescript13-staging Tour ==="
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
    @echo "=== idaptik-rescript13-staging Help ==="
    @echo "Platform: $(uname -s) $(uname -m)"
    @echo "Shell: $SHELL"
    @echo ""
    @echo "To report an issue:"
    @echo "  https://github.com/hyperpolymath/idaptik-rescript13-staging/issues/new"
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
