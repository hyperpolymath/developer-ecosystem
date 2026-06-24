#!/bin/bash -eu
# SPDX-License-Identifier: MPL-2.0
# ClusterFuzzLite build script for IDApTIK
#
# Builds fuzz targets from escape-hatch (Rust).

cd $SRC/idaptik/escape-hatch

# Build fuzz targets using cargo-fuzz
cargo fuzz build --release

# Copy fuzz binaries to $OUT
for fuzzer in fuzz/target/*/release/fuzz_*; do
  if [ -f "$fuzzer" ] && [ -x "$fuzzer" ]; then
    cp "$fuzzer" "$OUT/"
  fi
done
