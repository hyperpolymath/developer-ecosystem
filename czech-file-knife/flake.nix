# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 hyperpolymath
{
  description = "Czech File Knife - Universal cloud file management CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };

        # Build dependencies
        buildDeps = with pkgs; [
          pkg-config
          openssl
          fuse3
          sqlite
        ];

        # Development tools
        devTools = with pkgs; [
          just
          cargo-edit
          cargo-audit
          cargo-outdated
          cargo-tarpaulin
          cargo-deny
          cargo-watch
          jq
          tantivy  # For search testing
        ];

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = [ rustToolchain ] ++ buildDeps ++ devTools;

          shellHook = ''
            export RUST_LOG=info
            echo "Czech File Knife development environment"
            echo ""
            echo "Workspace members:"
            echo "  cfk-core       - Core types and traits"
            echo "  cfk-providers  - Cloud provider implementations"
            echo "  cfk-cache      - Caching layer"
            echo "  cfk-search     - Full-text search (Tantivy)"
            echo "  cfk-vfs        - Virtual filesystem (FUSE)"
            echo "  cfk-cli        - Command-line interface"
            echo ""
            echo "Build: cargo build -p cfk-cli"
            echo "Test:  cargo test --workspace"
          '';
        };

        # Main CLI package
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "cfk-cli";
          version = "0.1.0";

          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [ openssl fuse3 sqlite ];

          # Build only the CLI
          cargoBuildFlags = [ "-p" "cfk-cli" ];
          cargoTestFlags = [ "-p" "cfk-cli" ];

          meta = with pkgs.lib; {
            description = "Universal cloud file management CLI";
            homepage = "https://github.com/hyperpolymath/czech-file-knife";
            license = licenses.agpl3Plus;
            mainProgram = "cfk";
          };
        };

        # Full workspace package
        packages.full = pkgs.rustPlatform.buildRustPackage {
          pname = "czech-file-knife";
          version = "0.1.0";

          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;

          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [ openssl fuse3 sqlite ];

          # Build entire workspace
          cargoBuildFlags = [ "--workspace" ];

          meta = with pkgs.lib; {
            description = "Czech File Knife - Universal cloud file management";
            homepage = "https://github.com/hyperpolymath/czech-file-knife";
            license = licenses.agpl3Plus;
          };
        };

        # CI checks
        packages.ci = pkgs.stdenv.mkDerivation {
          name = "czech-file-knife-ci";
          src = ./.;

          nativeBuildInputs = [ rustToolchain pkgs.pkg-config ];
          buildInputs = with pkgs; [ openssl fuse3 sqlite ];

          buildPhase = ''
            export HOME=$TMPDIR
            cargo fmt --check
            cargo clippy --workspace -- -D warnings
            cargo test --workspace
            cargo audit
          '';

          installPhase = ''
            mkdir -p $out
            echo "CI checks passed" > $out/result
          '';
        };
      }
    );
}
