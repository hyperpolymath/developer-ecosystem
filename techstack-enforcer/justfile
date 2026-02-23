# SPDX-License-Identifier: PMPL-1.0-or-later
# Justfile - techstack-enforcer task runner

default:
    @just --list

# Build debug binary
build:
    mkdir -p obj bin
    gprbuild -P techstack_enforcer.gpr -XMODE=debug -j0

# Build release binary
release-build:
    mkdir -p obj bin
    gprbuild -P techstack_enforcer.gpr -XMODE=release -j0

# Run SPARK formal verification
verify:
    gnatprove -P techstack_enforcer.gpr --level=2

# Run all checks (build + verify)
check: build verify

# Audit the current directory
audit *ARGS:
    ./bin/techstack_main audit . {{ARGS}}

# Launch the TUI
tui:
    ./bin/techstack_tui_main

# Install hooks to a target repository
install-hooks REPO:
    ./scripts/install-repo-hooks.sh {{REPO}}

# Format Ada source code
fmt:
    gnatpp -P techstack_enforcer.gpr

# Clean build artifacts
clean:
    rm -rf obj bin

# Run tests (SPARK proofs are the primary test mechanism)
test: verify

# Prepare a release
release VERSION: release-build verify
    @echo "Release v{{VERSION}} — build and verification passed"
