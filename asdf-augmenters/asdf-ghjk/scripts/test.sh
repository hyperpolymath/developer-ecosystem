#!/usr/bin/env bash

set -euo pipefail

# Test runner script for asdf-ghjk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "🧪 Running asdf-ghjk tests..."
echo ""

# Check if BATS is installed
if [[ ! -f "test/bats/bin/bats" ]]; then
  echo "❌ BATS not found. Run ./scripts/setup-dev.sh first"
  exit 1
fi

# Run ShellCheck if available
if command -v shellcheck &>/dev/null; then
  echo "📝 Running ShellCheck..."
  if shellcheck bin/* lib/*.sh lib/*.bash; then
    echo "✅ ShellCheck passed"
  else
    echo "❌ ShellCheck failed"
    exit 1
  fi
  echo ""
else
  echo "⚠️  ShellCheck not found, skipping lint"
  echo ""
fi

# Run BATS tests
echo "🧪 Running BATS tests..."

if ./test/bats/bin/bats test/*.bats; then
  echo ""
  echo "✅ All tests passed!"
  exit 0
else
  echo ""
  echo "❌ Tests failed"
  exit 1
fi
