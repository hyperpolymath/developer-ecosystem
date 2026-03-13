;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem position for deno-ecosystem
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "deno-ecosystem")
  (type "monorepo")
  (purpose "Deno runtime interoperability bridges and tools")

  (position-in-ecosystem
    (category "runtime-interop")
    (subcategory "deno-bridges")
    (unique-value ("Cross-runtime bridges" "Idris2 ABI + Zig FFI")))

  (related-projects
    ("language-bridges" sibling-standard "Zig FFI bridges for other languages")
    ("polystack" sibling-standard "Poly-* component collection"))

  (what-this-is
    ("Bridges between Deno and other runtimes/languages")
    ("BEAM, Bun, and V language interop layers"))

  (what-this-is-not
    ("Not a Deno framework or application")
    ("Not a replacement for native Deno APIs")))
