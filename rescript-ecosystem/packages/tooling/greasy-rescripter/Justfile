# SPDX-License-Identifier: AGPL-3.0-or-later
# RSR Standard Justfile - Greasy-Rescripter Implementation
# https://just.systems/man/en/

set shell := ["bash", "-uc"]
set dotenv-load := true
set positional-arguments := true

# Project metadata
project := "greasy-rescripter"
version := "0.1.0-alpha"
tier := "infrastructure"

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT & HELP
# ═══════════════════════════════════════════════════════════════════════════════

default:
    @just --list --unsorted

info:
    @echo "Project: {{project}}"
    @echo "Version: {{version}}"
    @echo "RSR Tier: {{tier}}"

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD & COMPILE (The "Neuro-Symbolic" Fusion)
# ═══════════════════════════════════════════════════════════════════════════════

# Full build: Fuse symbolic header and functional logic into .user.js
bundle: build-res export
    @mkdir -p dist
    @cat .temp_header.txt src/Main.bs.js > dist/script.user.js
    @rm .temp_header.txt
    @echo "Build complete: ./dist/script.user.js"

# Compile functional ReScript logic
build-res:
    rescript build

# Evaluate symbolic Nickel layer to produce Greasemonkey metadata
export:
    @echo "// ==UserScript==" > .temp_header.txt
    @nickel export config/metadata.ncl --format json | jq -r '.header | to_entries | .[] | "// @\(.key) \(.value | if type == "array" then join("\n// @\(.key) ") else . end)"' >> .temp_header.txt
    @echo "// ==/UserScript==" >> .temp_header.txt

# Clean build artifacts
clean:
    rm -rf dist lib .temp_header.txt node_modules

# ═══════════════════════════════════════════════════════════════════════════════
# TEST & QUALITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run ReScript tests (if configured)
test:
    @echo "Running tests..."
    # npm test

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════════

# Initialise project (The RSR 'Strike' command)
strike: deps
    @echo "Environment struck and ready."

deps:
    @echo "Installing dependencies..."
    npm install

# ═══════════════════════════════════════════════════════════════════════════════
# DOCUMENTATION
# ═══════════════════════════════════════════════════════════════════════════════

cookbook:
    #!/usr/bin/env bash
    mkdir -p docs
    OUTPUT="docs/just-cookbook.adoc"
    echo "= {{project}} Justfile Cookbook" > "$OUTPUT"
    echo "Generated: $(date -Iseconds)" >> "$OUTPUT"
    just --list --unsorted >> "$OUTPUT"

# ═══════════════════════════════════════════════════════════════════════════════
# CONTAINERS (Podman-first for RSR/Linux/Minix)
# ═══════════════════════════════════════════════════════════════════════════════

[private]
container-cmd:
    #!/usr/bin/env bash
    command -v podman >/dev/null 2>&1 && echo "podman" || echo "docker"

# Build inside the deterministic container
podman-build:
    #!/usr/bin/env bash
    CTR=$(just container-cmd)
    $CTR build -t {{project}} -f Containerfile .
    $CTR run --rm -v $(pwd):/app {{project}} just bundle

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

validate:
    @echo "Checking RSR compliance..."
    @[ -f Justfile ] && echo "Justfile: OK"
    @[ -f config/metadata.ncl ] && echo "Nickel Config: OK"
    @[ -f src/Main.res ] && echo "ReScript Source: OK"
