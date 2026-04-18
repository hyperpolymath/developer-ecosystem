#!/usr/bin/env bash

# Test helper functions

# Get plugin directory
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PLUGIN_DIR

# Set up test environment
setup() {
  # Create temporary directory for tests
  export TEST_TEMP_DIR
  TEST_TEMP_DIR="$(mktemp -d)"

  export ASDF_DOWNLOAD_PATH="${TEST_TEMP_DIR}/download"
  export ASDF_INSTALL_PATH="${TEST_TEMP_DIR}/install"

  mkdir -p "$ASDF_DOWNLOAD_PATH"
  mkdir -p "$ASDF_INSTALL_PATH"
}

# Clean up test environment
teardown() {
  if [[ -n "${TEST_TEMP_DIR:-}" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR"
  fi
}

# Check if running in CI
is_ci() {
  [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]
}

# Skip test if not in CI (for slow tests)
skip_unless_ci() {
  if ! is_ci; then
    skip "$1"
  fi
}

# Get latest ghjk version for testing
get_latest_version() {
  "${PLUGIN_DIR}/bin/list-all" | awk '{print $NF}'
}

# Get a stable version for testing (0.3.2 is known to exist)
get_stable_test_version() {
  echo "0.3.2"
}
