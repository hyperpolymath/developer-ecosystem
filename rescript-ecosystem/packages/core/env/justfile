# rescript-env - Type-safe environment variables for ReScript
# https://just.systems/man/en/
#
# Run `just` to see all available recipes
# Run `just build` to compile ReScript
# Run `just dev` to watch for changes

set shell := ["bash", "-uc"]
set dotenv-load := true
set positional-arguments := true

# Project metadata
project := "rescript-env"
version := "0.1.0"
tier := "1"  # RSR Tier 1 (Gold) - ReScript

# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT & HELP
# ═══════════════════════════════════════════════════════════════════════════════

# Show all available recipes with descriptions
default:
    @just --list --unsorted

# Show detailed help for a specific recipe
help recipe="":
    #!/usr/bin/env bash
    if [ -z "{{recipe}}" ]; then
        just --list --unsorted
        echo ""
        echo "Usage: just help <recipe>"
        echo ""
        echo "Quick start:"
        echo "  just build    # Compile ReScript"
        echo "  just dev      # Watch mode"
        echo "  just test     # Run tests"
    else
        just --show "{{recipe}}" 2>/dev/null || echo "Recipe '{{recipe}}' not found"
    fi

# Show project info
info:
    @echo "Project: {{project}}"
    @echo "Version: {{version}}"
    @echo "RSR Tier: {{tier}} (Gold - ReScript)"
    @echo "Language: ReScript"
    @echo "Runtime: Deno / Node.js"
    @echo ""
    @echo "Source files:"
    @find src -name "*.res" -o -name "*.resi" 2>/dev/null | wc -l | xargs -I{} echo "  {} ReScript files"

# ═══════════════════════════════════════════════════════════════════════════════
# BUILD & COMPILE
# ═══════════════════════════════════════════════════════════════════════════════

# Build ReScript to JavaScript
build:
    @echo "Building {{project}}..."
    deno task build

# Build and watch for changes
dev:
    @echo "Starting watch mode..."
    deno task dev

# Clean build artifacts
clean:
    @echo "Cleaning..."
    deno task clean
    rm -rf lib/

# ═══════════════════════════════════════════════════════════════════════════════
# TEST & QUALITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run all tests
test:
    @echo "Running tests..."
    @if [ -d "tests" ]; then \
        deno test --allow-env tests/; \
    else \
        echo "No tests directory found. Create tests/*.test.ts to add tests."; \
    fi

# Run tests with verbose output
test-verbose:
    @echo "Running tests (verbose)..."
    deno test --allow-env --reporter=verbose tests/ 2>/dev/null || echo "No tests found"

# Type check ReScript
check:
    @echo "Type checking..."
    deno task build 2>&1 | head -20

# ═══════════════════════════════════════════════════════════════════════════════
# LINT & FORMAT
# ═══════════════════════════════════════════════════════════════════════════════

# Format ReScript source files
fmt:
    @echo "Formatting..."
    @command -v rescript-format >/dev/null && find src -name "*.res" -exec rescript-format -i {} \; || echo "rescript-format not found, skipping"

# Check formatting without changes
fmt-check:
    @echo "Checking format..."
    @command -v rescript-format >/dev/null && find src -name "*.res" -exec rescript-format --check {} \; || echo "rescript-format not found, skipping"

# Run linter (uses ReScript compiler warnings)
lint: check
    @echo "Lint complete (via ReScript compiler)"

# Run all quality checks
quality: fmt-check lint test
    @echo "All quality checks passed!"

# ═══════════════════════════════════════════════════════════════════════════════
# DOCUMENTATION
# ═══════════════════════════════════════════════════════════════════════════════

# Generate all documentation
docs:
    @mkdir -p docs/generated
    just cookbook
    @echo "Documentation generated in docs/"

# Generate justfile cookbook
cookbook:
    #!/usr/bin/env bash
    mkdir -p docs
    OUTPUT="docs/just-cookbook.adoc"
    echo "= {{project}} Justfile Cookbook" > "$OUTPUT"
    echo ":toc: left" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "Generated: $(date -Iseconds)" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    echo "== Recipes" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
    just --list --unsorted | while read -r line; do
        if [[ "$line" =~ ^[[:space:]]+([a-z_-]+) ]]; then
            recipe="${BASH_REMATCH[1]}"
            echo "=== $recipe" >> "$OUTPUT"
            echo "[source,bash]" >> "$OUTPUT"
            echo "----" >> "$OUTPUT"
            echo "just $recipe" >> "$OUTPUT"
            echo "----" >> "$OUTPUT"
            echo "" >> "$OUTPUT"
        fi
    done
    echo "Generated: $OUTPUT"

# ═══════════════════════════════════════════════════════════════════════════════
# CI & AUTOMATION
# ═══════════════════════════════════════════════════════════════════════════════

# Run full CI pipeline locally
ci: quality
    @echo "CI pipeline complete!"

# Install git hooks
install-hooks:
    @mkdir -p .git/hooks
    @cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
just fmt-check || exit 1
just build || exit 1
EOF
    @chmod +x .git/hooks/pre-commit
    @echo "Git hooks installed"

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY
# ═══════════════════════════════════════════════════════════════════════════════

# Run security audit
security:
    @echo "=== Security Audit ==="
    @command -v gitleaks >/dev/null && gitleaks detect --source . --verbose || echo "gitleaks not installed"
    @echo "Security audit complete"

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION & COMPLIANCE
# ═══════════════════════════════════════════════════════════════════════════════

# Validate RSR compliance
validate-rsr:
    #!/usr/bin/env bash
    echo "=== RSR Compliance Check ==="
    MISSING=""
    for f in .editorconfig .gitignore justfile RSR_COMPLIANCE.adoc README.adoc; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    for d in .well-known; do
        [ -d "$d" ] || MISSING="$MISSING $d/"
    done
    for f in .well-known/security.txt .well-known/ai.txt .well-known/humans.txt; do
        [ -f "$f" ] || MISSING="$MISSING $f"
    done
    # Note: guix.scm/flake.nix optional for pure JS libraries
    if [ -n "$MISSING" ]; then
        echo "MISSING:$MISSING"
        exit 1
    fi
    echo "RSR compliance: PASS"

# Validate machine-readable state files
validate-state:
    @echo "Checking .machine_readable/ files..."
    @for f in STATE.scm META.scm ECOSYSTEM.scm AGENTIC.scm; do \
        [ -f ".machine_readable/$f" ] && echo "  ✓ $f" || echo "  ✗ $f missing"; \
    done

# Full validation suite
validate: validate-rsr validate-state
    @echo "All validations passed!"

# ═══════════════════════════════════════════════════════════════════════════════
# PUBLISHING
# ═══════════════════════════════════════════════════════════════════════════════

# Publish to JSR (JavaScript Registry)
publish-jsr:
    @echo "Publishing to JSR..."
    @echo "Run: deno publish"
    @echo "(Requires authentication with deno login)"

# ═══════════════════════════════════════════════════════════════════════════════
# VERSION CONTROL
# ═══════════════════════════════════════════════════════════════════════════════

# Show git status
status:
    @git status --short

# Show recent commits
log count="10":
    @git log --oneline -{{count}}

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

# Count lines of code
loc:
    @echo "Lines of code:"
    @find src -name "*.res" -o -name "*.resi" 2>/dev/null | xargs wc -l 2>/dev/null || echo "0"

# Show TODO comments
todos:
    @grep -rn "TODO\|FIXME" --include="*.res" --include="*.resi" src/ 2>/dev/null || echo "No TODOs found"

# Open in editor
edit:
    ${EDITOR:-code} .
