# SPDX-License-Identifier: MPL-2.0
# rescript-grpc build tasks

set shell := ["bash", "-uc"]

# Default: show available tasks
default:
    @just --list

# Build the protoc plugin
build-plugin:
    cd protoc-gen-rescript && cargo build --release

# Build the WASM codec
build-codec:
    cd codec && cargo build --release --target wasm32-unknown-unknown
    @mkdir -p dist
    cp codec/target/wasm32-unknown-unknown/release/rescript_grpc_codec.wasm dist/proto_codec.wasm

# Build ReScript runtime
build-runtime:
    cd runtime && npx rescript build

# Build everything
build: build-plugin build-codec build-runtime

# Install protoc plugin to ~/.cargo/bin
install-plugin:
    cargo install --path protoc-gen-rescript

# Run example: generate ReScript from user.proto
example:
    protoc --plugin=protoc-gen-rescript=./protoc-gen-rescript/target/release/protoc-gen-rescript \
           --rescript_out=./examples/basic/src \
           --proto_path=./examples/basic/protos \
           user.proto

# Run tests
test:
    cd protoc-gen-rescript && cargo test
    cd codec && cargo test

# Format all code
fmt:
    cd protoc-gen-rescript && cargo fmt
    cd codec && cargo fmt
    cd runtime && npx rescript format src/*.res

# Check formatting and lints
check:
    cd protoc-gen-rescript && cargo fmt --check && cargo clippy
    cd codec && cargo fmt --check && cargo clippy

# Clean build artifacts
clean:
    cd protoc-gen-rescript && cargo clean
    cd codec && cargo clean
    cd runtime && rm -rf lib
    rm -rf dist

# Setup Rust WASM target
setup:
    rustup target add wasm32-unknown-unknown
