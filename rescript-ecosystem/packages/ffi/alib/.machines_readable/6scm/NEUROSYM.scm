;; SPDX-License-Identifier: PMPL-1.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for rescript-alib

(define neurosym-config
  `((version . "1.0.0")
    (project . "rescript-alib")

    (symbolic-layer
      ((type . "rescript-type-system")
       (reasoning . "deductive")
       (verification . "compile-time")
       (guarantees
         ("Type safety via branded types"
          "Exhaustive pattern matching"
          "No null/undefined at type level"
          "Result type for explicit error handling"))))

    (neural-layer
      ((llm-guidance
         (model . "claude-sonnet-4-5-20250929")
         (use-cases
           ("Code generation for new branded types"
            "Test case generation from type signatures"
            "Documentation generation from .resi files"
            "Refactoring suggestions maintaining zero-cost"))
         (constraints
           ("Must preserve type safety"
            "Must maintain zero-cost abstractions"
            "Must follow parse-dont-validate"
            "Must not shadow stdlib")))

       (embeddings . false)
       (fine-tuning . false)))

    (integration
      ((type-to-llm
         (workflow
           ("1. LLM reads .resi signature"
            "2. Generates implementation preserving contracts"
            "3. Compiler verifies type correctness"
            "4. Tests verify runtime behavior"))
         (feedback-loop
           "Compiler errors guide LLM corrections"))

       (test-generation
         (from-types
           ("Given Email.t signature"
            "Generate valid/invalid test cases"
            "Ensure boundary condition coverage"
            "Verify error messages"))
         (symbolic-verification
           "ReScript compiler proves exhaustiveness"))

       (property-based-testing
         (future-integration . "fast-check or jsverify")
         (symbolic-constraints
           ("Branded type invariants"
            "Parse-reveal round-trip"
            "Error case coverage"))
         (neural-generation
           "LLM generates diverse test inputs"))

       (formal-verification-target
         (reference . "proven (Idris library)")
         (aspirational
           ("Prove parse-reveal identity"
            "Prove validation completeness"
            "Prove zero-cost via inspection")))))

    (verification-boundaries
      ((compile-time
         (enforced-by . "rescript-compiler")
         (guarantees
           ("Type safety"
            "Exhaustive matching"
            "No shadowing of stdlib")))

       (test-time
         (enforced-by . "deno-test-runner")
         (validates
           ("Parse accepts valid inputs"
            "Parse rejects invalid inputs"
            "Reveal returns original string"
            "Error messages include context")))

       (benchmark-time
         (enforced-by . "deno-bench")
         (proves
           ("Parse overhead <= 5%"
            "Reveal overhead == 0%"
            "Inline optimization successful")))))

    (ai-symbolic-synergy
      ((pattern-discovery
         "LLM identifies common validation patterns across codebases -> Symbolic type system enforces pattern correctness")

       (error-diagnosis
         "Symbolic type error -> LLM suggests fix preserving types -> Compiler validates fix")

       (optimization
         "Symbolic guarantees (type safety) + Neural intuition (when to inline) -> Verified zero-cost abstractions")

       (documentation
         "Symbolic signatures (.resi) + Neural explanation (why this design) -> Comprehensive docs")))))
