#!/usr/bin/env bats

load test_helpers

setup() {
  source "${PLUGIN_DIR}/lib/utils.sh"
}

@test "get_platform returns valid platform" {
  run get_platform

  [ "$status" -eq 0 ]
  [[ "$output" =~ ^(x86_64-unknown-linux-gnu|aarch64-unknown-linux-gnu|x86_64-apple-darwin|aarch64-apple-darwin)$ ]]
}

@test "get_asset_name formats correctly" {
  run get_asset_name "0.3.2" "x86_64-unknown-linux-gnu"

  [ "$status" -eq 0 ]
  [ "$output" = "ghjk-v0.3.2-x86_64-unknown-linux-gnu.tar.gz" ]
}

@test "get_asset_name handles version with v prefix" {
  run get_asset_name "v0.3.2" "x86_64-unknown-linux-gnu"

  [ "$status" -eq 0 ]
  [ "$output" = "ghjk-v0.3.2-x86_64-unknown-linux-gnu.tar.gz" ]
}

@test "get_download_url formats correctly" {
  run get_download_url "0.3.2" "x86_64-unknown-linux-gnu"

  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/metatypedev/ghjk/releases/download/v0.3.2/ghjk-v0.3.2-x86_64-unknown-linux-gnu.tar.gz" ]
}

@test "command_exists detects existing commands" {
  run command_exists bash

  [ "$status" -eq 0 ]
}

@test "command_exists fails for non-existent commands" {
  run command_exists nonexistent_command_12345

  [ "$status" -ne 0 ]
}

@test "sort_versions sorts correctly" {
  input="v0.3.0
v0.1.0
v0.3.2
v0.2.0
v0.3.1"

  run bash -c "echo '$input' | sort_versions"

  [ "$status" -eq 0 ]

  # Should be sorted: v0.1.0 v0.2.0 v0.3.0 v0.3.1 v0.3.2
  local first_version
  local last_version
  first_version=$(echo "$output" | awk '{print $1}')
  last_version=$(echo "$output" | awk '{print $NF}')

  [ "$first_version" = "v0.1.0" ]
  [ "$last_version" = "v0.3.2" ]
}

@test "check_dependencies succeeds with required tools" {
  run check_dependencies

  [ "$status" -eq 0 ]
}

@test "log functions produce output" {
  run log "test message"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test message" ]]

  run success "test success"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test success" ]]

  run warn "test warning"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test warning" ]]

  run error "test error"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test error" ]]
}
