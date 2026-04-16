# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# rescript-string-power — Justfile
# Run `just` to see available recipes

set shell := ["bash", "-euc"]

# Project metadata
OWNER := "hyperpolymath"
REPO := "rescript-string-power"

# Default recipe — show help
default:
    @just --list --unsorted

# ============================================================================
# CRG GRADE B — 6 INDEPENDENT TEST TARGETS
# ============================================================================

# T1 — structural checks (bash)
test-structure:
    @echo "── T1: structure ──"
    @bash tests/validate_structure.sh

# T2 — unit tests (Rust, cargo test on the CLI)
test-unit:
    @echo "── T2: unit (cargo) ──"
    cd tools/string-union-gen && cargo test --quiet

# T3 — end-to-end (build CLI, run on fixture, verify output)
test-e2e:
    @echo "── T3: e2e ──"
    @bash tests/e2e_test.sh

# T4 — property-style tests (Deno)
test-property:
    @echo "── T4: property (deno) ──"
    deno test --quiet --allow-read tests/property_test.mjs

# T5 — benchmarks (Deno)
test-bench:
    @echo "── T5: bench (deno) ──"
    deno bench --quiet --allow-read tests/bench_test.mjs

# T6 — lint: clippy, rustfmt, shellcheck (graceful if shellcheck missing)
test-lint:
    @echo "── T6: lint ──"
    cd tools/string-union-gen && cargo clippy --quiet --all-targets -- -D warnings
    cd tools/string-union-gen && cargo fmt --check
    @if command -v shellcheck >/dev/null 2>&1; then \
       shellcheck tests/*.sh; \
     else \
       echo "  · shellcheck not installed — running bash -n syntax check instead"; \
       for f in tests/*.sh; do bash -n "$f"; done; \
     fi

# Run all six test targets — CRG Grade B requirement
test: test-structure test-unit test-e2e test-property test-bench test-lint
    @echo ""
    @echo "✓ All 6 CRG Grade B test targets passed"

# Alias
test-all: test

# Print current CRG grade from READINESS.md
crg-grade:
    @grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md | head -1

# Print a shields.io CRG badge
crg-badge:
    @grade=$(just crg-grade); \
    case "$grade" in \
      A) color="brightgreen" ;; \
      B) color="green" ;; \
      C) color="yellow" ;; \
      D) color="orange" ;; \
      E) color="red" ;; \
      F) color="critical" ;; \
      *) color="lightgrey" ;; \
    esac; \
    echo "[![CRG $grade](https://img.shields.io/badge/CRG-$grade-$color?style=flat-square)](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)"

# ============================================================================
# RESCRIPT LIBRARY (requires the ReScript compiler separately)
# ============================================================================

# Build ReScript (requires rescript installed via package manager of choice)
build-rescript:
    @command -v rescript >/dev/null || { echo "rescript not on PATH — install the ReScript compiler separately"; exit 1; }
    rescript

# Format ReScript sources
fmt-rescript:
    @command -v rescript >/dev/null || { echo "rescript not on PATH"; exit 1; }
    rescript format src/*.res

# Clean ReScript build artefacts
clean-rescript:
    rm -f src/*.res.mjs src/*__strings.res

# ============================================================================
# STRING-UNION-GEN CLI (Rust)
# ============================================================================

# Build the CLI (release)
build-cli:
    cd tools/string-union-gen && cargo build --release

# Build the CLI (debug)
build-cli-debug:
    cd tools/string-union-gen && cargo build

# Run the CLI against src/
gen: build-cli
    ./tools/string-union-gen/target/release/string-union-gen -s src/ -v

# Dry run
gen-dry: build-cli
    ./tools/string-union-gen/target/release/string-union-gen -s src/ --dry-run

# Clean Rust artefacts
clean-cli:
    cd tools/string-union-gen && cargo clean

# Install the CLI to ~/.local/bin
install-cli: build-cli
    install -m 755 tools/string-union-gen/target/release/string-union-gen ~/.local/bin/

# ============================================================================
# MAINTENANCE
# ============================================================================

# Auto-fix formatting
fmt:
    cd tools/string-union-gen && cargo fmt

# Lint everything (non-fatal)
lint:
    cd tools/string-union-gen && cargo clippy --all-targets

# Clean everything
clean: clean-cli clean-rescript
    @echo "✓ Cleaned"

# Full local CI equivalent
ci: test
    @echo "✓ CI equivalent passed"

# Show project info
info:
    @echo "Project:     {{REPO}}"
    @echo "Owner:       {{OWNER}}"
    @echo "CRG Grade:   $(just crg-grade)"
    @echo "Test targets: 6 (T1 structure, T2 unit, T3 e2e, T4 property, T5 bench, T6 lint)"
