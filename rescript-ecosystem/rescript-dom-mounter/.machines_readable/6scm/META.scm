;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - rescript-dom-mounter meta information

(define meta
  (architecture-decisions
    (adr "adr-001"
      (status "accepted")
      (date "2026-01-30")
      (context
        "DOM mounting is error-prone: null pointers, invalid selectors, malformed HTML."
        "Traditional solutions use runtime checks which add overhead and can fail.")
      (decision
        "Use Idris2 dependent types to prove DOM operations safe at compile time."
        "Create ReScript bindings that expose formally verified API."
        "Proofs erased at compile time—zero runtime overhead.")
      (consequences
        "Positive: Impossible to have DOM mounting crashes"
        "Positive: Zero runtime cost"
        "Positive: Type-safe API"
        "Negative: Requires Idris2 toolchain (mitigated by pre-compiled proofs)"))

    (adr "adr-002"
      (status "accepted")
      (date "2026-01-30")
      (context
        "Need to choose between runtime validation vs compile-time proofs.")
      (decision
        "Use compile-time proofs via Idris2 dependent types."
        "ValidSelector, WellFormedHTML, SafeMount are proven at type level."
        "Errors caught during compilation, not runtime.")
      (consequences
        "Positive: Catches errors before deployment"
        "Positive: Better developer experience (IDE feedback)"
        "Negative: Steeper learning curve (acceptable for infrastructure)"))

    (adr "adr-003"
      (status "accepted")
      (date "2026-01-30")
      (context
        "Should this be in rsr-template-repo or separate?")
      (decision
        "Separate repository for SafeDOM, then include in rsr-template-repo."
        "This allows independent versioning and wider adoption.")
      (consequences
        "Positive: Reusable across projects"
        "Positive: Clear separation of concerns"
        "Positive: Can publish to npm independently")))

  (development-practices
    (code-style
      "ReScript conventions for API layer"
      "Idris2 conventions for proof layer"
      "No Obj.magic except where proven safe"
      "Comprehensive type annotations")

    (security
      "All inputs validated through dependent types"
      "Bounded operations (1MB HTML, 255 char selectors)"
      "No eval or Function constructor"
      "Defense in depth even with formal proofs")

    (testing
      "Unit tests for ReScript API"
      "Property-based tests for validation"
      "Idris2 type-checking validates proofs"
      "Integration tests with rescript-tea")

    (versioning
      "Semantic versioning (MAJOR.MINOR.PATCH)"
      "Breaking changes only for Major (proofs are stable)")

    (documentation
      "README.adoc with formal verification explanations"
      "Inline documentation for all proofs"
      "Usage examples for each API function"
      "Comparison with unsafe alternatives")

    (branching
      "main - production-ready with proofs"
      "feature/* - new features"
      "proof/* - new formal proofs"))

  (design-rationale
    (why-idris2
      "Dependent types allow compile-time proofs"
      "Totality checking ensures proofs terminate"
      "Type erasure means zero runtime cost"
      "Best-in-class for formal verification")

    (why-rescript
      "Excellent JavaScript interop"
      "Type-safe without TypeScript ceremony"
      "Fast compilation, small bundles"
      "Good fit for DOM manipulation")

    (why-separate-repo
      "Independent versioning"
      "Reusable infrastructure"
      "Clear ownership and maintenance"
      "Can be published to npm")

    (why-agpl
      "Infrastructure should remain free"
      "Encourage contributions back"
      "Protect users from proprietary forks"
      "Consistent with proven library")

    (why-mandatory
      "DOM mounting is critical path"
      "Errors here crash entire application"
      "Formal verification eliminates entire class of bugs"
      "Should be default, not optional")))
