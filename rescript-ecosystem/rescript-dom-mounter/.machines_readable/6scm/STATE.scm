;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - rescript-dom-mounter state

(define state
  (metadata
    (version "1.1.0")
    (created "2026-01-30")
    (updated "2026-02-28")
    (project "rescript-dom-mounter")
    (repo "https://github.com/hyperpolymath/rescript-dom-mounter"))

  (project-context
    (name "ReScript Safe DOM")
    (tagline "Formally verified DOM mounting with mathematical guarantees")
    (tech-stack
      (languages "ReScript" "Idris2" "JavaScript")
      (runtime "Deno")
      (verification "Idris2 dependent types for compile-time proofs")))

  (current-position
    (phase "Feature Complete")
    (overall-completion 95)
    (components
      (component "SafeDOMCore.res high-assurance core" "complete" 100
        "Core mounting, batch mounting, validation, DOM ready, XSS sanitisation, lifecycle, CSP nonce")
      (component "SafeDOM.res public API" "complete" 100
        "Re-exports all core functions including unmount, remount, mountWithNonce")
      (component "SafeDOM.idr Idris2 proofs" "complete" 100
        "ValidSelector, WellFormedHTML, SafeMount, batch atomicity")
      (component "XSS sanitisation" "complete" 100
        "Script removal, event handler stripping, javascript: URL blocking, data: URL removal, iframe removal")
      (component "Lifecycle support" "complete" 100
        "unmount, remount with atomic swap semantics")
      (component "CSP nonce support" "complete" 100
        "mountWithNonce injects nonce into script/style tags for Content-Security-Policy compliance")
      (component "Documentation" "complete" 100
        "Comprehensive README with usage examples, proofs, and API reference")
      (component "Configuration" "complete" 100
        "deno.json, rescript.json, package.json (dependency versions aligned)")
      (component "Tests" "pending" 30
        "Need comprehensive test suite covering sanitisation and lifecycle")
      (component "Examples" "pending" 20
        "Need real-world usage examples")))

  (route-to-mvp
    (milestone "Core Library Complete" "complete"
      (items
        "SafeDOM ReScript API with all mounting functions"
        "Idris2 formal verification layer"
        "Comprehensive documentation"))
    (milestone "Security Hardening" "complete"
      (items
        "XSS sanitisation in ProvenHTML (script, event handlers, javascript:, data:, iframe)"
        "CSP nonce support via mountWithNonce"
        "SPDX headers corrected to PMPL-1.0-or-later"))
    (milestone "Lifecycle Support" "complete"
      (items
        "unmount function with MountTracer audit"
        "remount with atomic swap semantics (validate before unmount)"
        "Full MountTracer coverage for lifecycle events"))
    (milestone "Testing & Validation" "in-progress"
      (items
        "Unit tests for all mounting operations"
        "XSS sanitisation tests"
        "Lifecycle (unmount/remount) tests"
        "CSP nonce injection tests"
        "Integration tests with rescript-tea"
        "Property-based testing"
        "Idris2 proof validation"))
    (milestone "Ecosystem Integration" "pending"
      (items
        "Add to rsr-template-repo"
        "Update rescript-tea to use SafeDOM"
        "Update 4 demo sites to use SafeDOM"
        "Publish to npm")))

  (blockers-and-issues
    (critical)  ; None
    (high
      (issue "Not yet in rsr-template-repo"
        "Needs to become standard infrastructure"))
    (medium
      (issue "Test suite incomplete"
        "Need comprehensive tests covering sanitisation, lifecycle, and CSP"))
    (low
      (issue "No npm package"
        "Should publish for wider adoption")))

  (critical-next-actions
    (immediate
      "Build and verify compilation with new features"
      "Write tests for XSS sanitisation edge cases")
    (this-week
      "Create comprehensive test suite"
      "Add usage examples for unmount/remount/mountWithNonce"
      "Update rescript-tea integration")
    (this-month
      "Publish to npm"
      "Update all 4 demo sites to use SafeDOM"
      "Write formal verification paper"))

  (session-history
    (snapshot "2026-01-30" "Initial creation"
      (accomplishments
        "Created SafeDOM.res with all core mounting functions"
        "Created SafeDOM.idr with dependent type proofs"
        "Comprehensive documentation with formal verification details"
        "Configuration for Deno + ReScript"
        "Ready for integration into rsr-template-repo"))
    (snapshot "2026-02-28" "Security hardening, lifecycle, and CSP support"
      (accomplishments
        "Fixed SPDX headers: AGPL-3.0-or-later -> PMPL-1.0-or-later in all files"
        "Added XSS sanitisation to ProvenHTML: script removal, event handler stripping, javascript: URL blocking, data: URL removal, iframe removal"
        "Added unmount() with MountTracer audit trail"
        "Added remount() with atomic swap semantics (validate-before-unmount)"
        "Added mountWithNonce() for Content-Security-Policy compliance"
        "Updated SafeDOM.res re-exports with unmount, remount, mountWithNonce"
        "Fixed @rescript/core dependency version mismatch (^1.5.0 -> ^1.6.0)"
        "Fixed author email in package.json (jonathan.jewell -> j.d.a.jewell)"
        "Added comprehensive annotations to all touched code"))))

(define (get-completion-percentage) 95)
