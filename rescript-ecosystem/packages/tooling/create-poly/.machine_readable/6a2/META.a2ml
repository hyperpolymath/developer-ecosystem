;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information for rescript-poly-core
;; Media-Type: application/meta+scheme

(meta
  (architecture-decisions
    (("adr-001-rescript-only"
      (status . "accepted")
      (context . "Need type-safe language that compiles to JS")
      (decision . "Use ReScript exclusively, no TypeScript")
      (rationale . "ReScript provides stronger type safety and better performance"))
     ("adr-002-deno-runtime"
      (status . "accepted")
      (context . "Need JavaScript runtime for execution")
      (decision . "Use Deno, not Node.js or Bun")
      (rationale . "Deno has better security model, built-in TypeScript, and modern APIs"))
     ("adr-003-zero-deps"
      (status . "accepted")
      (context . "Managing dependencies is complex and risky")
      (decision . "Only depend on @rescript/core")
      (rationale . "Minimizes supply chain risk and simplifies maintenance"))
     ("adr-004-mcp-first"
      (status . "accepted")
      (context . "Building AI tools requires MCP infrastructure")
      (decision . "Include MCP protocol and server support in core")
      (rationale . "MCP is fundamental to the ecosystem's purpose"))))

  (development-practices
    (code-style
      (("uncurried-mode" . "Always use @@uncurried")
       ("pipe-first" . "Use -> operator for chaining")
       ("pattern-matching" . "Prefer switch over if/else")
       ("doc-comments" . "All public functions documented")))
    (security
      (principle "Defense in depth")
      (requirements
        ("no-eval" . "Never use eval or Function constructor")
        ("no-http" . "HTTPS only, no plain HTTP")
        ("no-secrets" . "No hardcoded secrets or keys")
        ("input-validation" . "Validate all external input")))
    (testing
      (framework "deno-test")
      (coverage-target "80%")
      (types ("unit" "integration")))
    (versioning "SemVer")
    (documentation "AsciiDoc")
    (branching "main for stable"))

  (design-rationale
    (("result-over-exceptions"
      (principle . "Explicit error handling")
      (implementation . "Result type for all fallible operations"))
     ("composition-over-inheritance"
      (principle . "Functional composition")
      (implementation . "Pipe-friendly function signatures"))
     ("explicit-over-implicit"
      (principle . "No hidden magic")
      (implementation . "All behavior visible in type signatures")))))
