# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 used for ecosystem compatibility)
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
#
# Nix flake development environment for developer-ecosystem.
# Usage: nix develop
#
# Provides tooling for all sub-ecosystems:
#   ada, coq, deno, idris2, julia, rescript, v-lang, zig
{
  description = "Developer ecosystem — multi-language tooling monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Deno — deno-ecosystem tooling
            deno

            # Idris2 — idris2-ecosystem and ABI definitions
            idris2

            # Zig — zig-ecosystem and FFI
            zig

            # Julia — julia-ecosystem
            julia

            # Coq — coq-ecosystem formal proofs
            coqPackages.coq

            # Ada/GNAT — ada-ecosystem
            gnat

            # ReScript — rescript-ecosystem (via npm/deno)
            # Note: ReScript installed via deno/npm within rescript-ecosystem

            # V-lang — v-ecosystem protocol implementations
            vlang

            # OCaml/opam — package tooling
            ocaml
            opam

            # Build tooling
            pkg-config
            gnumake
          ];

          shellHook = ''
            echo "developer-ecosystem dev shell — deno + idris2 + zig + julia + coq + gnat + vlang"
          '';
        };
      });
}
