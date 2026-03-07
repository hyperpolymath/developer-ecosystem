#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
# aLib Conformance Test Runner Script
#
# Runs conformance tests for a given language implementation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SPECS_DIR="$PROJECT_ROOT/specs"

usage() {
    cat <<EOF
Usage: $0 <language> [category]

Languages:
  oblibeny    - Run tests against Oblíbený implementation
  wokelang    - Run tests against WokeLang implementation
  eclexia     - Run tests against Eclexia implementation

Categories (optional):
  arithmetic  - Only run arithmetic tests
  comparison  - Only run comparison tests
  logical     - Only run logical tests
  collection  - Only run collection tests
  string      - Only run string tests
  all         - Run all tests (default)

Examples:
  $0 oblibeny
  $0 oblibeny arithmetic
  $0 wokelang all
EOF
    exit 1
}

run_oblibeny_tests() {
    local category="${1:-all}"
    echo "=== Running aLib Conformance Tests for Oblíbený ==="
    echo "Category: $category"
    echo

    local oblibeny_dir="$PROJECT_ROOT/../oblibeny"

    if [[ ! -d "$oblibeny_dir" ]]; then
        echo "Error: Oblíbený directory not found at $oblibeny_dir"
        exit 1
    fi

    case "$category" in
        arithmetic|all)
            echo "--- Arithmetic Operations ---"
            (cd "$oblibeny_dir" && dune exec oblibeny examples/alib/arithmetic.obl) || true
            ;;
    esac

    case "$category" in
        comparison|all)
            echo "--- Comparison Operations ---"
            (cd "$oblibeny_dir" && dune exec oblibeny examples/alib/comparison.obl) || true
            ;;
    esac

    case "$category" in
        logical|all)
            echo "--- Logical Operations ---"
            (cd "$oblibeny_dir" && dune exec oblibeny examples/alib/logical.obl) || true
            ;;
    esac

    echo
    echo "=== Conformance Tests Complete ==="
}

# Main
if [[ $# -lt 1 ]]; then
    usage
fi

LANGUAGE="$1"
CATEGORY="${2:-all}"

case "$LANGUAGE" in
    oblibeny)
        run_oblibeny_tests "$CATEGORY"
        ;;
    wokelang|eclexia)
        echo "Error: $LANGUAGE conformance tests not yet implemented"
        exit 1
        ;;
    *)
        echo "Error: Unknown language '$LANGUAGE'"
        usage
        ;;
esac
