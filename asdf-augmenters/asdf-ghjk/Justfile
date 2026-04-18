# justfile for asdf-ghjk
# https://github.com/casey/just

# Load environment variables from .env if present
set dotenv-load := true

# Default recipe (list available recipes)
default:
    @just --list

# ============================================================================
# Development
# ============================================================================

# Set up development environment
setup:
    @echo "🚀 Setting up development environment..."
    @./scripts/setup-dev.sh

# Run all tests
test:
    @echo "🧪 Running tests..."
    @./scripts/test.sh

# Run specific test file
test-file FILE:
    @echo "🧪 Running {{FILE}}..."
    @./test/bats/bin/bats {{FILE}}

# Run linting (ShellCheck)
lint:
    @echo "📝 Running ShellCheck..."
    @shellcheck bin/* lib/*.sh lib/*.bash scripts/*.sh hooks/*.sh

# Format shell scripts (requires shfmt)
format:
    @echo "✨ Formatting shell scripts..."
    @shfmt -w -i 2 -ci bin/* lib/*.sh lib/*.bash scripts/*.sh

# Run all quality checks (lint + test)
check: lint test
    @echo "✅ All checks passed!"

# ============================================================================
# Testing
# ============================================================================

# Run unit tests only
test-unit:
    @./test/bats/bin/bats test/utils.bats

# Run integration tests only
test-integration:
    @./test/bats/bin/bats test/list-all.bats test/download.bats test/install.bats

# Run tests with verbose output
test-verbose:
    @./test/bats/bin/bats -t test/*.bats

# Run tests with coverage (placeholder - BATS doesn't have built-in coverage)
test-coverage:
    @echo "⚠️  Coverage reporting not yet implemented for Bash"
    @just test

# ============================================================================
# Plugin Operations
# ============================================================================

# Install plugin to local asdf
install:
    @echo "🔌 Installing plugin to asdf..."
    @if asdf plugin list | grep -q ghjk; then \
        echo "Removing existing plugin..."; \
        asdf plugin remove ghjk || true; \
    fi
    @asdf plugin add ghjk "$(pwd)"
    @echo "✅ Plugin installed!"

# Uninstall plugin from local asdf
uninstall:
    @echo "🗑️  Uninstalling plugin..."
    @asdf plugin remove ghjk || true
    @echo "✅ Plugin uninstalled!"

# Test plugin by listing versions
test-list:
    @echo "📋 Testing version listing..."
    @./bin/list-all

# Test plugin by downloading a version
test-download VERSION="0.3.2":
    @echo "⬇️  Testing download of version {{VERSION}}..."
    @export ASDF_INSTALL_VERSION="{{VERSION}}"; \
    export ASDF_DOWNLOAD_PATH="/tmp/asdf-ghjk-test-download"; \
    mkdir -p "$$ASDF_DOWNLOAD_PATH"; \
    ./bin/download && \
    echo "✅ Download successful!"

# Test full installation workflow
test-install VERSION="0.3.2":
    @echo "📦 Testing full installation of version {{VERSION}}..."
    @export ASDF_INSTALL_VERSION="{{VERSION}}"; \
    export ASDF_DOWNLOAD_PATH="/tmp/asdf-ghjk-test-download"; \
    export ASDF_INSTALL_PATH="/tmp/asdf-ghjk-test-install"; \
    export ASDF_INSTALL_TYPE="version"; \
    mkdir -p "$$ASDF_DOWNLOAD_PATH" "$$ASDF_INSTALL_PATH"; \
    ./bin/download && \
    ./bin/install && \
    "$$ASDF_INSTALL_PATH/bin/ghjk" --version && \
    echo "✅ Installation successful!" && \
    rm -rf /tmp/asdf-ghjk-test-*

# ============================================================================
# Maintenance
# ============================================================================

# Clean up cache and temporary files
clean:
    @echo "🧹 Cleaning up..."
    @./scripts/cleanup.sh --all --dry-run
    @read -p "Proceed with cleanup? [y/N] " confirm && \
    if [ "$$confirm" = "y" ]; then \
        ./scripts/cleanup.sh --all; \
    else \
        echo "Cleanup cancelled."; \
    fi

# Clean cache only
clean-cache:
    @./scripts/cleanup.sh --cache

# Clean downloads only
clean-downloads:
    @./scripts/cleanup.sh --downloads

# Show cache statistics
cache-stats:
    @echo "📊 Cache statistics..."
    @source lib/cache.sh && cache_stats

# ============================================================================
# Diagnostics
# ============================================================================

# Run diagnostic checks
doctor:
    @echo "🏥 Running diagnostics..."
    @./scripts/doctor.sh

# Show plugin information
info:
    @echo "ℹ️  Plugin Information"
    @echo "====================="
    @echo "Name: asdf-ghjk"
    @echo "Repository: https://github.com/Hyperpolymath/asdf-ghjk"
    @echo "License: MIT AND Palimpsest-0.8"
    @echo "Version: Latest from git"
    @echo ""
    @echo "Files: $(find . -type f ! -path './.git/*' ! -path './test/bats/*' | wc -l)"
    @echo "Lines of Code: $(find bin lib scripts -name '*.sh' -o -name '*.bash' | xargs wc -l | tail -1)"
    @echo "Tests: $(find test -name '*.bats' | wc -l) files"
    @echo "Docs: $(find docs -name '*.md' | wc -l) files"

# Show dependencies
deps:
    @echo "📦 Dependencies"
    @echo "==============="
    @echo ""
    @echo "Required:"
    @for cmd in bash curl tar grep sort; do \
        if command -v $$cmd >/dev/null 2>&1; then \
            echo "  ✅ $$cmd: $$($$cmd --version 2>&1 | head -1)"; \
        else \
            echo "  ❌ $$cmd: NOT FOUND"; \
        fi; \
    done
    @echo ""
    @echo "Optional:"
    @for cmd in shellcheck shfmt git; do \
        if command -v $$cmd >/dev/null 2>&1; then \
            echo "  ✅ $$cmd: $$($$cmd --version 2>&1 | head -1)"; \
        else \
            echo "  ⚠️  $$cmd: NOT FOUND"; \
        fi; \
    done

# ============================================================================
# Performance
# ============================================================================

# Run performance benchmarks
benchmark:
    @echo "🔬 Running benchmarks..."
    @./scripts/benchmark.sh

# Benchmark specific operation
benchmark-list:
    @echo "📊 Benchmarking list-all..."
    @time ./bin/list-all >/dev/null

# ============================================================================
# Documentation
# ============================================================================

# Serve documentation locally (requires Python)
docs-serve PORT="8000":
    @echo "📖 Serving documentation at http://localhost:{{PORT}}"
    @cd docs && python3 -m http.server {{PORT}}

# Check documentation for broken links (requires markdown-link-check)
docs-check:
    @echo "🔗 Checking documentation links..."
    @if command -v markdown-link-check >/dev/null 2>&1; then \
        find . -name '*.md' ! -path './test/*' -exec markdown-link-check {} \; ; \
    else \
        echo "⚠️  markdown-link-check not found. Install with: npm install -g markdown-link-check"; \
    fi

# Generate table of contents for README (requires markdown-toc)
docs-toc:
    @echo "📝 Generating table of contents..."
    @if command -v markdown-toc >/dev/null 2>&1; then \
        markdown-toc -i README.md; \
    else \
        echo "⚠️  markdown-toc not found. Install with: npm install -g markdown-toc"; \
    fi

# ============================================================================
# Release
# ============================================================================

# Prepare for release (run all checks)
pre-release: check
    @echo "🎯 Pre-release checks..."
    @echo "1. Checking git status..."
    @git status --short
    @echo "2. Checking for untracked files..."
    @if [ -n "$$(git status --porcelain)" ]; then \
        echo "⚠️  Working directory not clean!"; \
        exit 1; \
    fi
    @echo "3. Running tests..."
    @just test
    @echo "4. Running linting..."
    @just lint
    @echo "✅ Ready for release!"

# Tag a new version
tag VERSION:
    @echo "🏷️  Tagging version {{VERSION}}..."
    @git tag -a "v{{VERSION}}" -m "Release v{{VERSION}}"
    @echo "✅ Tagged! Push with: git push origin v{{VERSION}}"

# ============================================================================
# RSR Compliance
# ============================================================================

# Verify RSR compliance
rsr-check:
    @echo "🔍 Checking RSR compliance..."
    @./scripts/rsr-verify.sh

# Show RSR compliance status
rsr-status:
    @echo "📋 RSR Compliance Status"
    @echo "========================"
    @echo ""
    @./scripts/rsr-verify.sh --report

# ============================================================================
# Git Operations
# ============================================================================

# Show git status
status:
    @git status

# Show recent commits
log:
    @git log --oneline -10

# Create a new branch
branch NAME:
    @git checkout -b {{NAME}}

# Commit all changes
commit MESSAGE:
    @git add -A
    @git commit -m "{{MESSAGE}}"

# Push current branch
push:
    @git push origin $(git branch --show-current)

# Pull latest changes
pull:
    @git pull origin $(git branch --show-current)

# ============================================================================
# CI/CD
# ============================================================================

# Simulate CI pipeline locally
ci:
    @echo "🔄 Running CI pipeline locally..."
    @just lint
    @just test
    @echo "✅ CI pipeline complete!"

# Run pre-commit hooks
pre-commit:
    @if command -v pre-commit >/dev/null 2>&1; then \
        pre-commit run --all-files; \
    else \
        echo "⚠️  pre-commit not found. Install with: pip install pre-commit"; \
    fi

# ============================================================================
# Utilities
# ============================================================================

# Watch for file changes and run tests (requires entr)
watch:
    @if command -v entr >/dev/null 2>&1; then \
        find bin lib test -name '*.sh' -o -name '*.bats' | entr just test; \
    else \
        echo "⚠️  entr not found. Install with your package manager."; \
    fi

# Count lines of code
loc:
    @echo "📊 Lines of Code"
    @echo "================"
    @find bin lib scripts -name '*.sh' -o -name '*.bash' | xargs wc -l | sort -n

# Find TODOs in code
todos:
    @echo "📝 TODOs in code:"
    @grep -rn "TODO\|FIXME\|XXX" bin lib scripts || echo "No TODOs found!"

# Show help for a specific script
help-script SCRIPT:
    @echo "📖 Help for {{SCRIPT}}:"
    @head -20 {{SCRIPT}} | grep "^#" || echo "No help available"

# ============================================================================
# Docker (if using Docker examples)
# ============================================================================

# Build Docker image
docker-build:
    @echo "🐳 Building Docker image..."
    @docker build -f examples/Dockerfile -t asdf-ghjk:latest .

# Build multi-stage Docker image
docker-build-prod:
    @echo "🐳 Building production Docker image..."
    @docker build -f examples/Dockerfile.multi-stage -t asdf-ghjk:prod .

# Run Docker container
docker-run:
    @echo "🐳 Running Docker container..."
    @docker run -it --rm asdf-ghjk:latest

# Docker Compose up
docker-up:
    @echo "🐳 Starting Docker Compose..."
    @cd examples && docker-compose up

# Docker Compose down
docker-down:
    @echo "🐳 Stopping Docker Compose..."
    @cd examples && docker-compose down
