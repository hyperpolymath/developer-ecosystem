#!/usr/bin/env bats

load test_helpers

@test "download script exists and is executable" {
  [ -x "${PLUGIN_DIR}/bin/download" ]
}

@test "download requires ASDF_INSTALL_VERSION" {
  unset ASDF_INSTALL_VERSION

  run "${PLUGIN_DIR}/bin/download"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "ASDF_INSTALL_VERSION" ]]
}

@test "download requires ASDF_DOWNLOAD_PATH" {
  export ASDF_INSTALL_VERSION="0.3.2"
  unset ASDF_DOWNLOAD_PATH

  run "${PLUGIN_DIR}/bin/download"

  [ "$status" -ne 0 ]
  [[ "$output" =~ "ASDF_DOWNLOAD_PATH" ]]
}

@test "download detects platform correctly" {
  export ASDF_INSTALL_VERSION="0.3.2"

  run bash -c "source '${PLUGIN_DIR}/lib/utils.sh' && get_platform"

  [ "$status" -eq 0 ]

  # Should be one of the supported platforms
  [[ "$output" =~ ^(x86_64-unknown-linux-gnu|aarch64-unknown-linux-gnu|x86_64-apple-darwin|aarch64-apple-darwin)$ ]]
}

@test "download creates metadata file" {
  skip_unless_ci "Skipping actual download test (slow)"

  export ASDF_INSTALL_VERSION="0.3.2"

  run "${PLUGIN_DIR}/bin/download"

  [ "$status" -eq 0 ]
  [ -f "${ASDF_DOWNLOAD_PATH}/.metadata" ]

  # Metadata should contain version info
  run cat "${ASDF_DOWNLOAD_PATH}/.metadata"
  [[ "$output" =~ version=0\.3\.2 ]]
}

@test "download handles invalid version" {
  export ASDF_INSTALL_VERSION="999.999.999"

  run "${PLUGIN_DIR}/bin/download"

  [ "$status" -ne 0 ]
}
