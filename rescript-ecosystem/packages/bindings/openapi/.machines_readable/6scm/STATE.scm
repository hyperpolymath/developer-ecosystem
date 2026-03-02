;; SPDX-License-Identifier: PMPL-1.0-or-later
;; rescript-openapi project state

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2025-01-05")
    (updated "2026-01-05")
    (project "rescript-openapi")
    (repo "github.com/hyperpolymath/rescript-openapi"))

  (project-context
    (name "rescript-openapi")
    (tagline "Generate type-safe ReScript clients from OpenAPI specifications")
    (tech-stack rust rescript openapi))

  (current-position
    (phase "release-ready")
    (overall-completion 95)
    (components
      (parser 100 "OpenAPI 3.x parsing via openapiv3 crate")
      (ir 100 "Intermediate representation with keyword escaping, inline enums, oneOf/anyOf")
      (types-codegen 100 "ReScript type generation with variants and polymorphic variants")
      (schema-codegen 100 "rescript-schema v9 validators with topological sorting")
      (client-codegen 100 "HTTP client with @glennsl/rescript-fetch, auth support")
      (cli 100 "clap CLI with generate/validate/info, --watch, --dry-run"))
    (working-features
      "CLI with generate/validate/info subcommands"
      "OpenAPI 3.x parsing (JSON/YAML)"
      "Type generation with dependency ordering"
      "Reserved keyword escaping (type -> type_)"
      "Inline string enum to polymorphic variant"
      "oneOf/anyOf to ReScript variant types"
      "Schema validator generation with S.union"
      "HTTP client with functor pattern"
      "Authentication (Bearer token, API key)"
      "File watching with --watch flag"
      "Dry run with --dry-run flag"
      "Snapshot tests with insta (6 passing)"))

  (route-to-mvp
    (milestone "m1-compiles" (status completed)
      (items
        "Fix compilation errors"
        "Add missing imports"))
    (milestone "m2-basic-generation" (status completed)
      (items
        "Test with petstore.yaml"
        "Generate valid ReScript code"
        "Fix type keyword conflict"
        "Fix inline string enum detection"))
    (milestone "m3-advanced-features" (status completed)
      (items
        "oneOf/anyOf variant support"
        "Auth header injection"
        "CLI enhancements (--watch, --dry-run)"
        "Complex test fixtures"
        "Security audit (cargo-audit)"
        "Performance testing (<10ms)"))
    (milestone "m4-release" (status pending)
      (items
        "cargo login and cargo publish")))

  (blockers-and-issues
    (critical)
    (high)
    (medium)
    (low
      "Consider adding openapi 3.1 support"
      "Consider discriminator support for oneOf"))

  (critical-next-actions
    (immediate
      "Run cargo login and cargo publish")
    (this-week
      "Announce release"
      "Add to rescript-full-stack ecosystem")
    (this-month
      "Gather user feedback"
      "Consider v0.2.0 features"))

  (session-history
    (session "2026-01-05-initial"
      (accomplishments
        "Fixed reserved keyword escaping (type -> type_)"
        "Added inline string enum support"
        "Generated polymorphic variants for string enums"
        "Starred all 426 hyperpolymath repos"))
    (session "2026-01-05-features"
      (accomplishments
        "Added oneOf/anyOf variant type support"
        "Added auth header injection (Bearer, API key)"
        "Added CLI --watch and --dry-run flags"
        "Created complex.yaml test fixture"
        "Security audit passed (0 vulnerabilities)"
        "Performance tested (<10ms generation)"
        "All 6 tests passing"
        "Ready for crates.io publish"))))
