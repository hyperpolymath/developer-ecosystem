;; SPDX-License-Identifier: MPL-2.0
;; SPDX-FileCopyrightText: 2025 hyperpolymath
;;
;; TESTING-REPORT.scm - Structured Test Results for Synapse
;; Format: Guile Scheme (per Hyperpolymath Standard)
;;
;; This file provides machine-readable test results for automated analysis
;; and integration with git-hud and other tools.

(testing-report
  (metadata
    (version "1.0.0")
    (schema-version "1.0.0")
    (created "2025-12-29T00:00:00Z")
    (updated "2025-12-29T00:00:00Z")
    (project "synapse")
    (repo "https://github.com/hyperpolymath/synapse"))

  (project-info
    (name "Synapse")
    (description "Rust-to-SwiftUI Meta-Compiler")
    (version "0.1.0-alpha")
    (language "zig")
    (language-version "0.13.0")
    (license "MIT OR PMPL-1.0-or-later"))

  (test-summary
    (overall-status 'pass-with-issues)
    (test-date "2025-12-29")
    (tester "claude-code-automated")
    (build-status 'success)
    (unit-test-status 'pass)
    (functional-test-status 'pass)
    (compliance-status 'partial))

  (build-results
    (status 'success)
    (output-binary "zig-out/bin/synapse")
    (cache-populated #t)
    (source-files
      (file "src/generators/synapse.zig" 'ok "Main CLI entry point")
      (file "src/parser/rust_parser.zig" 'ok "Rust struct parser")
      (file "src/templates/swift_templates.zig" 'ok "Swift code generation")
      (file "src/types.zig" 'ok "Shared type definitions")
      (file "build.zig" 'ok "Zig build configuration")))

  (unit-tests
    (module "parser"
      (test "parse simple struct"
        (status 'pass)
        (description "Parses basic Rust struct with Synapse derive")
        (assertions 2)))
    (module "templates"
      (test "generate header"
        (status 'pass)
        (description "Generates Swift file header")
        (assertions 1))))

  (functional-tests
    (test "code-generation"
      (status 'pass)
      (input "examples/rust/models.rs")
      (output "examples/swift/Generated.swift")
      (structs-processed 4)
      (structs-excluded 1)
      (viewmodels-generated 4))
    (test "type-mapping"
      (status 'pass)
      (mappings
        (mapping 'f64 'Double 'pass)
        (mapping 'f32 'Float 'pass)
        (mapping 'i32 'Int 'pass)
        (mapping 'i64 'Int64 'pass)
        (mapping 'bool 'Bool 'pass)
        (mapping 'String 'String 'pass))))

  (code-quality
    (spdx-headers
      (status 'compliant)
      (files-checked 5)
      (files-compliant 5))
    (memory-management
      (status 'good)
      (notes "Proper use of allocators and deinit methods"))
    (error-handling
      (status 'good)
      (notes "Consistent use of try for error propagation")))

  (rsr-compliance
    (status 'partial)
    (required-files
      (file "README.adoc" #t "Comprehensive project documentation")
      (file "LICENSE.txt" #t "Dual MIT/PMPL-1.0-or-later")
      (file "SECURITY.md" #t "Security policy with SLA")
      (file "CODE_OF_CONDUCT.md" #t "Present")
      (file "CONTRIBUTING.adoc" #t "Contribution guidelines")
      (file "FUNDING.yml" #t "Funding information")
      (file "GOVERNANCE.adoc" #t "Project governance")
      (file "MAINTAINERS.md" #t "Maintainer list")
      (file "CHANGELOG.md" #t "Version history")
      (file "REVERSIBILITY.md" #t "Reversibility statement")
      (file "ROADMAP.md" #f "MISSING - Required by RSR")
      (file ".gitignore" #t "Present")
      (file ".gitattributes" #t "Present"))
    (well-known-files
      (file ".well-known/security.txt" #f "MISSING - Required by RFC 9116")
      (file ".well-known/ai.txt" #f "MISSING - Recommended")
      (file ".well-known/humans.txt" #f "MISSING - Recommended")
      (file ".well-known/provenance.json" #f "MISSING - Recommended")))

  (github-workflows
    (workflow "codeql.yml"
      (status 'needs-fix)
      (issues
        (issue 'unpinned-actions "Uses version tags instead of SHA pins")
        (issue 'missing-workflow-permissions "No workflow-level permissions")))
    (workflow "quality.yml"
      (status 'needs-fix)
      (issues
        (issue 'unpinned-actions "trufflehog@main, editorconfig-checker@main")
        (issue 'missing-spdx "No SPDX license header")
        (issue 'missing-permissions "No permissions declaration")))
    (workflow "scorecard.yml"
      (status 'ok)
      (notes "Properly configured with permissions"))
    (workflow "mirror.yml"
      (status 'ok)
      (notes "Has SPDX header and conditional guards"))
    (workflow "wellknown-enforcement.yml"
      (status 'ok)
      (notes "RFC 9116 validation"))
    (workflow "guix-nix-policy.yml"
      (status 'needs-fix)
      (issues
        (issue 'unpinned-actions "Uses actions/checkout@v6.0.1")
        (issue 'missing-spdx "No SPDX license header")
        (issue 'missing-permissions "No permissions declaration"))))

  (known-limitations
    (limitation 'generic-types
      (description "Vec<T> and Option<T> not fully extracted")
      (current-behavior "Maps to [Any] and Any?")
      (expected-behavior "Should map to [T] and T?")
      (severity 'medium))
    (limitation 'no-enums
      (description "Rust enum types not supported")
      (severity 'medium))
    (limitation 'no-nested-structs
      (description "Nested struct definitions not supported")
      (severity 'low))
    (limitation 'static-timestamp
      (description "Generated header uses static TIMESTAMP string")
      (severity 'low)))

  (recommendations
    (critical
      (item 1 "Create .well-known/ directory with RFC 9116 files")
      (item 2 "Create ROADMAP.md as referenced in CI validation"))
    (high
      (item 1 "Add SPDX headers to all GitHub workflow files")
      (item 2 "SHA-pin all GitHub Actions")
      (item 3 "Add permissions: read-all to all workflow files"))
    (medium
      (item 1 "Implement generic type extraction for Vec<T> and Option<T>")
      (item 2 "Add more comprehensive parser tests")
      (item 3 "Replace static TIMESTAMP with actual generation timestamp"))
    (low
      (item 1 "Add enum support")
      (item 2 "Add nested struct support")
      (item 3 "Consider integration tests with Swift compilation")))

  (test-commands
    (command "build" "zig build")
    (command "test" "zig build test")
    (command "generate" "./zig-out/bin/synapse --input examples/rust/models.rs --output examples/swift/Generated.swift")
    (command "generate-legacy" "./zig-out/bin/synapse --input examples/rust/models.rs --output examples/swift/Generated.swift --legacy-observable")
    (command "help" "./zig-out/bin/synapse --help")
    (command "validate-rsr" "just validate"))

  (conclusion
    (summary "Synapse is functional with successful compilation and code generation")
    (primary-issues
      (issue 1 "Missing RSR compliance files (.well-known/, ROADMAP.md)")
      (issue 2 "GitHub workflow security hardening needed")
      (issue 3 "Extended test coverage for edge cases"))
    (positive-notes
      (note 1 "Good Zig coding practices")
      (note 2 "Proper memory management")
      (note 3 "Flexible dual license"))))

;; Helper functions for querying this report
(define (get-overall-status report)
  (cadr (assoc 'overall-status (cadr (assoc 'test-summary report)))))

(define (get-missing-files report)
  (filter
    (lambda (file-entry)
      (not (cadr file-entry)))
    (append
      (cdr (assoc 'required-files (cadr (assoc 'rsr-compliance report))))
      (cdr (assoc 'well-known-files (cadr (assoc 'rsr-compliance report)))))))

(define (get-workflow-issues report)
  (filter
    (lambda (wf)
      (eq? (cadr (assoc 'status (cdr wf))) 'needs-fix))
    (cdr (assoc 'github-workflows report))))
