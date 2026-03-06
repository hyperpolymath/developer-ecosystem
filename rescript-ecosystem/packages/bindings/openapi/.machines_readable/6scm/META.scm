;; SPDX-License-Identifier: PMPL-1.0-or-later
;; rescript-openapi meta information

(meta
  (version "1.0")

  (architecture-decisions
    (adr-001
      (status accepted)
      (date "2025-01-05")
      (title "Use Rust for code generation")
      (context "Need a fast, reliable CLI tool for codegen")
      (decision "Implement in Rust using openapiv3 crate")
      (consequences
        "Fast parsing and generation"
        "Single binary distribution"
        "Follows Hyperpolymath RSR (Rust for CLI tools)"))

    (adr-002
      (status accepted)
      (date "2025-01-05")
      (title "Generate rescript-schema validators")
      (context "Need runtime validation of API responses")
      (decision "Generate rescript-schema code alongside types")
      (consequences
        "Type-safe JSON parsing"
        "Runtime validation catches API mismatches"
        "Adds rescript-schema as runtime dependency"))

    (adr-003
      (status accepted)
      (date "2025-01-05")
      (title "Pluggable HTTP backend via functor")
      (context "Different environments need different HTTP implementations")
      (decision "Use module functor pattern with HttpClient signature")
      (consequences
        "Users can plug in any HTTP library"
        "Easy mocking for tests"
        "Default FetchClient works out of the box"))

    (adr-004
      (status accepted)
      (date "2025-01-05")
      (title "Polymorphic variants for enums")
      (context "OpenAPI string enums need ReScript representation")
      (decision "Use polymorphic variants for better JSON interop")
      (consequences
        "Cleaner JSON serialization"
        "Works well with rescript-schema"
        "Consistent with ReScript idioms")))

  (development-practices
    (code-style "rustfmt for Rust, rescript-format for generated code")
    (security "PMPL-1.0-or-later, OpenSSF Scorecard compliance")
    (testing "Snapshot tests with insta crate")
    (versioning "SemVer")
    (documentation "README.adoc, inline rustdoc")
    (branching "trunk-based development"))

  (design-rationale
    (why-rust "RSR mandates Rust for CLI tools; fast, single binary")
    (why-functor "OCaml/ReScript pattern for DI without runtime overhead")
    (why-schema "DZakh's rescript-schema is the best validation library")
    (why-not-typescript "RSR bans TypeScript; ReScript is the target")))
