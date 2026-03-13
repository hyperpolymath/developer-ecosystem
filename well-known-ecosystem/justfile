# SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
# SPDX-FileCopyrightText: 2024-2025 hyperpolymath
#
# well-known-ecosystem - Development Tasks

set shell := ["bash", "-uc"]
set dotenv-load := true

project := "well-known-ecosystem"
validator_dir := "validator"

# Show all recipes
default:
    @just --list --unsorted

# Build the validator
build:
    cd {{validator_dir}} && cargo build --release

# Run all tests
test:
    cd {{validator_dir}} && cargo test

# Clean build artifacts
clean:
    cd {{validator_dir}} && cargo clean

# Format code
fmt:
    cd {{validator_dir}} && cargo fmt

# Check formatting
fmt-check:
    cd {{validator_dir}} && cargo fmt --check

# Run clippy lints
lint:
    cd {{validator_dir}} && cargo clippy -- -D warnings

# Validate example well-known files
validate-examples:
    cd {{validator_dir}} && cargo run --release -- validate-dir ../examples/.well-known

# Validate a specific file
validate file:
    cd {{validator_dir}} && cargo run --release -- validate {{file}}

# List supported resource types
list-resources:
    cd {{validator_dir}} && cargo run --release -- list --detailed

# Show rules for a resource type
show-rules resource_type:
    cd {{validator_dir}} && cargo run --release -- rules {{resource_type}}

# Run all checks (fmt, lint, test)
check: fmt-check lint test

# Install the validator locally
install:
    cd {{validator_dir}} && cargo install --path .

# Generate Cargo.lock
lock:
    cd {{validator_dir}} && cargo generate-lockfile
