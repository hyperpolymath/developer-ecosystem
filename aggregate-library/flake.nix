# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Hyperpolymath

# flake.nix - Nix Flakes configuration for aggregate-library
# Fallback package manager (primary is Guix - see guix.scm)

{
  description = "Common Library specification for cross-language programming";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Development tools following language policy
        devTools = with pkgs; [
          # Task runner
          just

          # Allowed runtimes per .claude/CLAUDE.md
          deno                    # Primary JS runtime (replaces Node)
          rustc cargo             # Systems programming
          gleam erlang            # Backend services (BEAM)
          guile                   # Scheme for state files
          nickel                  # Configuration language

          # Validation tools
          yamllint

          # Container tools
          podman

          # Documentation
          asciidoctor
        ];

      in {
        # Development shell
        devShells.default = pkgs.mkShell {
          name = "aggregate-library-dev";

          buildInputs = devTools;

          shellHook = ''
            echo "═══════════════════════════════════════════════════════════"
            echo "  aggregate-library (aLib) Development Environment"
            echo "  Version: 0.1.0 | RSR Compliance: Gold (100/100)"
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            echo "Available commands:"
            echo "  just help     - Show all available tasks"
            echo "  just validate - Validate specifications"
            echo "  just test     - Run all tests"
            echo "  just check    - Full compliance check"
            echo ""
            echo "Language policy: ReScript, Deno, Rust, Gleam (no TS/Node/Go)"
            echo "═══════════════════════════════════════════════════════════"
          '';
        };

        # Package definition
        packages = {
          default = self.packages.${system}.aggregate-library;

          aggregate-library = pkgs.stdenv.mkDerivation {
            pname = "aggregate-library";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = with pkgs; [ just ];

            # Specification-only package - no build required
            dontBuild = true;

            installPhase = ''
              runHook preInstall

              # Install specifications
              mkdir -p $out/share/aggregate-library
              cp -r specs $out/share/aggregate-library/
              cp -r docs $out/share/aggregate-library/ 2>/dev/null || true
              cp -r .well-known $out/share/aggregate-library/

              # Install documentation
              cp README.adoc README.md LICENSE.txt SPEC_FORMAT.md $out/share/aggregate-library/
              cp config.ncl $out/share/aggregate-library/

              # Install validation tools
              mkdir -p $out/bin
              cp justfile $out/share/aggregate-library/

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Common Library specification for cross-language programming";
              longDescription = ''
                aggregate-library (aLib) defines a minimal Common Library specification
                representing the intersection of functionality across 7 programming languages.

                Provides 20 core operations across 6 categories:
                - Arithmetic: add, subtract, multiply, divide, modulo
                - Comparison: less_than, greater_than, equal, not_equal, less_equal, greater_equal
                - Logical: and, or, not
                - String: concat, length, substring
                - Collection: map, filter, fold, contains
                - Conditional: if_then_else
              '';
              homepage = "https://github.com/Hyperpolymath/aggregate-library";
              license = with licenses; [ mit agpl3Plus ];
              maintainers = [ ];
              platforms = platforms.all;
            };
          };

          # Container image for deployment
          container = pkgs.dockerTools.buildLayeredImage {
            name = "aggregate-library";
            tag = "0.1.0";

            contents = [ self.packages.${system}.aggregate-library ];

            config = {
              Labels = {
                "org.opencontainers.image.title" = "aggregate-library";
                "org.opencontainers.image.version" = "0.1.0";
                "org.opencontainers.image.licenses" = "MIT OR AGPL-3.0-or-later";
                "rsr.compliance" = "Gold";
                "rsr.score" = "100/100";
              };
            };
          };
        };

        # Validation checks
        checks = {
          validate = pkgs.runCommand "validate-specs" {
            nativeBuildInputs = [ pkgs.just ];
            src = ./.;
          } ''
            cd $src
            just validate-specs
            touch $out
          '';
        };
      }
    );
}
