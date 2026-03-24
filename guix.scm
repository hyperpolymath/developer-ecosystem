;; SPDX-License-Identifier: MPL-2.0
;; (PMPL-1.0-or-later preferred; MPL-2.0 used for ecosystem compatibility)
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
;;
;; Guix development environment for developer-ecosystem.
;; Usage: guix shell -D -f guix.scm
;;
;; This provides tooling for all sub-ecosystems:
;;   ada, coq, deno, idris2, julia, rescript, v-lang, zig

(use-modules (guix packages)
             (guix build-system gnu)
             (gnu packages node)
             (gnu packages idris)
             (gnu packages zig)
             (gnu packages julia)
             (gnu packages coq)
             (gnu packages ada)
             (gnu packages ocaml)
             (gnu packages pkg-config))

(package
  (name "developer-ecosystem")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (native-inputs
   (list deno
         idris2
         zig
         julia
         coq
         gnat
         opam
         pkg-config))
  (synopsis "Hyperpolymath developer ecosystem monorepo")
  (description
   "Monorepo containing ecosystem tooling for Ada, Coq, Deno, Idris2,
Julia, ReScript, V-lang, and Zig sub-ecosystems with shared FFI
bindings and aggregate library infrastructure.")
  (license #f))
