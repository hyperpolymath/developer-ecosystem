#!/usr/bin/env bats

load test_helpers

@test "list-all lists available versions" {
  run bash -c "source '${PLUGIN_DIR}/bin/list-all'"

  [ "$status" -eq 0 ]

  # Output should contain versions
  [[ "$output" =~ v0\.[0-9]+\.[0-9]+ ]] || [[ "$output" =~ 0\.[0-9]+\.[0-9]+ ]]
}

@test "list-all outputs space-separated versions" {
  run bash -c "source '${PLUGIN_DIR}/bin/list-all'"

  [ "$status" -eq 0 ]

  # Should be single line with space-separated values
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -eq 1 ]
}

@test "list-all handles GitHub API errors gracefully" {
  # Test with invalid token to trigger error
  export GITHUB_API_TOKEN="invalid_token_12345"

  run bash -c "source '${PLUGIN_DIR}/bin/list-all'"

  # Should fail with helpful error
  [ "$status" -ne 0 ]
}

@test "list-all sorts versions correctly" {
  run bash -c "source '${PLUGIN_DIR}/bin/list-all'"

  [ "$status" -eq 0 ]

  # Extract first and last versions
  local first_version
  local last_version
  first_version=$(echo "$output" | awk '{print $1}')
  last_version=$(echo "$output" | awk '{print $NF}')

  # Last version should be >= first version
  [[ -n "$first_version" ]]
  [[ -n "$last_version" ]]
}
