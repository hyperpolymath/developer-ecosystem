#!/bin/bash -eu
# SPDX-License-Identifier: MPL-2.0
# Build script for ClusterFuzzLite

cd $SRC/czech-file-knife

# Build fuzz targets using cargo-fuzz
cargo +nightly fuzz build

# Copy fuzz targets to $OUT
for target in $(cargo +nightly fuzz list); do
    cp ./target/x86_64-unknown-linux-gnu/release/$target $OUT/
done
