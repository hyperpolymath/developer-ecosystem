;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information for deno-ecosystem
;; Media-Type: application/meta+scheme

(meta
  (architecture-decisions
    ("ADR-001" "Monorepo consolidation"
      (status "accepted")
      (context "Four Deno interop repos consolidated into single monorepo")
      (decision "Use projects/ subdirectory for each component")
      (consequences ("Simpler discovery" "Shared CI/CD" "Single RSR template"))))

  (development-practices
    (code-style ("ReScript for application code" "Idris2 for ABI" "Zig for FFI"))
    (security
      (principle "Defense in depth"))
    (testing ())
    (versioning "SemVer")
    (documentation "AsciiDoc")
    (branching "main for stable"))

  (design-rationale
    ("Deno bridges share common patterns and ABI definitions"
     "Consolidation reduces RSR template duplication")))
