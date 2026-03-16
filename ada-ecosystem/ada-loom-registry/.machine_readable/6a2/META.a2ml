;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information for ada-loom-registry (Spindle)
;; Media-Type: application/meta+scheme

(meta
  (architecture-decisions
    (adr
      (id "0001")
      (title "Adopt Rhodium Standard")
      (status "accepted")
      (context "Project documentation and compliance tracking")
      (decision "Use Rhodium Standard Silver level for documentation"))
    (adr
      (id "0002")
      (title "Nickel Parser Integration")
      (status "accepted")
      (context "Configuration file parsing strategy")
      (decision "Use Haskell with hnickel library for type-safe Nickel parsing")))

  (development-practices
    (code-style
      (language "Haskell")
      (formatter "ormolu")
      (linter "hlint")
      (extensions "OverloadedStrings" "DeriveGeneric" "DeriveAnyClass")
      (warnings "-Wall" "-Wcompat" "-Widentities" "-Wincomplete-record-updates"))
    (security
      (principle "Defense in depth")
      (validation "Type-safe parsing via Aeson")
      (file-access "Validate paths before reading")
      (secrets "No hardcoded credentials"))
    (testing
      (framework "HSpec")
      (property-testing "QuickCheck")
      (coverage-target "80%")
      (test-types "unit" "integration" "golden"))
    (versioning "SemVer")
    (documentation "AsciiDoc")
    (branching "main for stable"))

  (design-rationale
    (why-haskell
      "Type safety, GHC WASM support, strong ecosystem for parsing")
    (why-nickel
      "Contract-based configuration with rich type system")
    (why-aeson-bridge
      "Standard JSON serialization enables interop with Nickel's JSON export")
    (why-registry
      "Track validated configurations with metadata and timestamps")))
