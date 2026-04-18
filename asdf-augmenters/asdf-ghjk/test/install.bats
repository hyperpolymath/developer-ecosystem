#!/usr/bin/env bats

load test_helpers

@test "install script exists and is executable" {
  [ -x "${PLUGIN_DIR}/bin/install" ]
}

@test "install requires ASDF_INSTALL_VERSION" {
  unset ASDF_INSTALL_VERSION

  run "${PLUGIN_DIR}/bin/install"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "ASDF_INSTALL_VERSION" ]]
}

@test "install requires ASDF_INSTALL_PATH" {
  export ASDF_INSTALL_VERSION="0.3.2"
  unset ASDF_INSTALL_PATH

  run "${PLUGIN_DIR}/bin/install"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "ASDF_INSTALL_PATH" ]]
}

@test "install only supports version install type" {
  export ASDF_INSTALL_VERSION="main"
  export ASDF_INSTALL_TYPE="ref"

  run "${PLUGIN_DIR}/bin/install"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "only supports installing specific versions" ]]
}

@test "install fails if archive not downloaded" {
  export ASDF_INSTALL_VERSION="0.3.2"
  export ASDF_INSTALL_TYPE="version"

  # Don't run download, so archive won't exist
  run "${PLUGIN_DIR}/bin/install"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "Archive not found" ]]
}

@test "install creates bin directory" {
  skip_unless_ci "Skipping full install test (requires download)"

  export ASDF_INSTALL_VERSION="0.3.2"
  export ASDF_INSTALL_TYPE="version"

  # First download
  run "${PLUGIN_DIR}/bin/download"
  [ "$status" -eq 0 ]

  # Then install
  run "${PLUGIN_DIR}/bin/install"
  [ "$status" -eq 0 ]

  # Should have bin directory
  [ -d "${ASDF_INSTALL_PATH}/bin" ]
}

@test "install makes ghjk executable" {
  skip_unless_ci "Skipping full install test (requires download)"

  export ASDF_INSTALL_VERSION="0.3.2"
  export ASDF_INSTALL_TYPE="version"

  # Download and install
  "${PLUGIN_DIR}/bin/download"
  "${PLUGIN_DIR}/bin/install"

  # Should be executable
  [ -x "${ASDF_INSTALL_PATH}/ghjk" ] || [ -x "${ASDF_INSTALL_PATH}/bin/ghjk" ]
}
