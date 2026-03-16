;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-alib

(define agentic-config
  `((version . "1.0.0")
    (project . "rescript-alib")

    (claude-code
      ((model . "claude-sonnet-4-5-20250929")
       (tools . ("read" "edit" "bash" "grep" "glob"))
       (permissions . "read-all")
       (preferred-style . "concise-technical")))

    (patterns
      ((code-review
         (focus . ("type-safety" "zero-cost-abstractions" "parse-dont-validate"))
         (check-for
           ("Ensure @inline on hot paths"
            "Verify %identity safety invariants"
            "Confirm private string in signature, string in implementation"
            "Validate regex patterns in branded types"
            "Check for Belt/Js shadowing risks")))

       (refactoring
         (style . "conservative")
         (preserve . ("public API surface" "zero-cost guarantees" "type safety"))
         (acceptable . ("internal implementation details" "test organization")))

       (testing
         (strategy . "comprehensive")
         (require
           ("Unit test for every validation function"
            "Benchmark for every zero-cost claim"
            "Integration test for layer interaction"))
         (benchmark-threshold
           ((parse-overhead . "5%")
            (reveal-overhead . "0%"))))

       (documentation
         (format . "asciidoc")
         (include
           ("Philosophy explanation"
            "Working code examples"
            "Performance characteristics"
            "Migration guide when deprecated"))
         (avoid . ("implementation details" "private APIs")))

       (new-module-checklist
         ("Create .resi signature file"
          "Implement with @inline annotations"
          "Write unit tests (90%+ coverage)"
          "Add benchmarks for performance claims"
          "Document in README.adoc"
          "Update STATE.scm"
          "Verify no stdlib shadowing"))))

    (constraints
      ((languages
         (primary . "rescript")
         (test-runner . "deno")
         (config . "nickel")
         (state-files . "guile-scheme"))

       (banned . ("typescript" "node" "npm" "go" "python" "makefile"))

       (architectural
         ("Never shadow Belt or Js modules"
          "All exports must be under Alib namespace"
          "Common layer must work in Melange"
          "Zero runtime dependencies"
          "Parse, don't validate pattern required"
          "@inline required for hot paths"))

       (performance
         ("Parse overhead <= 5% vs plain string"
          "Reveal overhead must be 0%"
          "No function call overhead after inlining"
          "Type safety must be compile-time only"))

       (graduation
         ("Delete modules that land upstream"
          "Keep tombstone with migration guide"
          "Update docs to point to stdlib"
          "Announce in CHANGELOG with 2-version warning"))))

    (workflows
      ((new-feature
         (steps
           ("1. Create .resi with type signature"
            "2. Implement with zero-cost abstractions"
            "3. Write unit tests"
            "4. Add benchmarks"
            "5. Update README and STATE.scm"
            "6. Verify CI passes")))

       (upstream-proposal
         (steps
           ("1. Gather usage evidence from issues/discussions"
            "2. Document performance benchmarks"
            "3. Create RFC in ReScript repo"
            "4. Reference rescript-alib as proof-of-concept"
            "5. Iterate on feedback")))

       (graduation
         (steps
           ("1. Confirm feature landed in ReScript stdlib"
            "2. Add deprecation notice to README"
            "3. Create tombstone file with migration guide"
            "4. Delete implementation after 2 minor versions"
            "5. Update CHANGELOG")))

       (alpha-release
         (steps
           ("1. Update version in rescript.json"
            "2. Run full check suite (just check)"
            "3. Update CHANGELOG.adoc"
            "4. Update STATE.scm completion %"
            "5. Tag release: v0.1.0-alpha.N"
            "6. Publish to npm (for ReScript package manager)")))))

    (ai-agent-guidance
      ((when-to-inline
         "Use @inline on: parse functions, reveal functions, hot path helpers. Omit on: test utilities, error constructors, rarely-called setup.")

       (when-to-use-external
         "Use %identity external for: reveal() unwrapping branded types, zero-cost casts with proven invariants. Always add SAFETY comment explaining why cast is sound.")

       (regex-validation-pattern
         "Use %re(\"/pattern/\") syntax for compile-time regex. Prefer strict validation - false negatives better than false positives for branded types.")

       (error-handling-style
         "Return result<t, error> from parse(). Error variant includes field name and invalid input for debugging. Never throw exceptions.")

       (functor-usage
         "Use Make functor for branded types. Takes Brand module (name + validate), returns S signature (t, parse, reveal). Enables infinite type variations from single implementation.")

       (layer-selection
         "Common: ReScript+Melange compatible, no platform-specific APIs. Specific: ReScript-only features (e.g., async/await sugar). Compat: Adapter shims for migration pain.")))))
