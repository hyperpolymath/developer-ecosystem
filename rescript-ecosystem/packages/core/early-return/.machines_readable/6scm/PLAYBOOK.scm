;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-early-return

(define playbook
  `((version . "1.0.0")
    (project . "rescript-early-return")

    (procedures
      ((build-ppx
         (steps
           ("1. Navigate to ppx directory: cd ppx"
            "2. Build with dune: dune build"
            "3. Verify output in _build/default/"))
         (troubleshooting
           ((issue . "Dune command not found")
            (solution . "Install opam, then: opam install dune"))
           ((issue . "OCaml version mismatch")
            (solution . "Check ppx/dune-project for required OCaml version, use opam switch"))
           ((issue . "Missing ppxlib dependency")
            (solution . "Install ppxlib: opam install ppxlib"))))

       (test-ppx
         (steps
           ("1. Build PPX: just build"
            "2. Compile test cases in examples/"
            "3. Verify transformation matches expected output"
            "4. Run integration tests: just test"))
         (troubleshooting
           ((issue . "Transformation output incorrect")
            (solution . "Check ppx/ppx_return_sugar.ml pattern matching logic"))
           ((issue . "AST errors")
            (solution . "Verify ppxlib version compatibility, check Parsetree structure"))))

       (release-alpha
         (steps
           ("1. Update version in ppx/dune-project and package.json"
            "2. Run full check: just check-all"
            "3. Update CHANGELOG.adoc"
            "4. Update STATE.scm completion percentage"
            "5. Commit: git commit -m 'chore: bump to v0.1.0-alpha.N'"
            "6. Tag: git tag v0.1.0-alpha.N"
            "7. Push: git push && git push --tags"
            "8. Publish PPX to opam repository"))
         (rollback
           ("1. Delete tag: git tag -d v0.1.0-alpha.N"
            "2. Revert version: git revert HEAD")))

       (compiler-proposal
         (steps
           ("1. Gather usage statistics from npm downloads"
            "2. Collect user feedback from GitHub issues"
            "3. Document performance impact (if any)"
            "4. Create RFC in docs/rfc/"
            "5. Post to ReScript forums linking to this library"
            "6. Create issue in rescript-lang/rescript-compiler referencing #8191"
            "7. Link macro as proof-of-concept and demand validation"
            "8. Iterate on feedback from core team"))
         (success-criteria
           ("10+ production projects using macro"
            "Positive community sentiment (>70%)"
            "Clear patterns emerged"
            "No major blockers identified"))
         (graduation-plan
           ("If #8191 accepted:"
            "1. Wait for compiler implementation"
            "2. Create codemod tool (macro -> sugar)"
            "3. Add deprecation notice to README"
            "4. Maintain for 2 versions during migration"
            "5. Archive repository with tombstone")))

       (debug-transformation
         (steps
           ("1. Use dune's ppx debugging: dune build --verbose"
            "2. Print AST before/after: ppxlib.metaquot_lifters"
            "3. Check pattern matching in ppx_return_sugar.ml"
            "4. Verify extension node marker matches (%return.X)"
            "5. Test with minimal example"))
         (common-errors
           ((error . "Extension node not recognized")
            (solution . "Check extension name matches pattern, verify ppxlib registration"))
           ((error . "Type error after transformation")
            (solution . "Verify generated code is valid ReScript, check desugar rules"))
           ((error . "Multiple transformations conflict")
            (solution . "Ensure transformation order is correct, check for recursive application"))))

       (onboarding-new-contributor
         (steps
           ("1. Read README.adoc and docs/DESUGARING-SPEC.adoc"
            "2. Review examples/before and examples/after"
            "3. Study ppx/ppx_return_sugar.ml structure"
            "4. Run 'just check-all' to verify setup"
            "5. Pick an issue labeled 'good-first-issue'"
            "6. Create feature branch: git checkout -b feature/name"
            "7. Implement following AGENTIC.scm guidelines"
            "8. Submit PR with tests and documentation")))

       (ci-failure-triage
         (steps
           ("1. Check GitHub Actions workflow log"
            "2. Identify failed step (build/test/lint)"
            "3. Reproduce locally: just check-all"
            "4. Fix issue"
            "5. Push fix"
            "6. Verify CI green"))
         (common-failures
           ((failure . "PPX compilation error")
            (solution . "Check OCaml syntax in ppx_return_sugar.ml, verify dune config"))
           ((failure . "Transformation tests fail")
            (solution . "Update examples/ output to match new transformation"))
           ((failure . "SCM validation failed")
            (solution . "Ensure all 6 SCM files present and valid Scheme")))))

      (issue-8191-tracking
        (steps
          ("1. Monitor rescript-lang/rescript-compiler#8191 for updates"
           "2. Gather usage metrics: npm downloads, GitHub stars, issues"
           "3. Document user feedback in GitHub Discussions"
           "4. Update COST-BENEFIT.adoc with real-world data"
           "5. Respond to core team questions promptly"))
        (decision-points
          ("If accepted: Begin graduation planning"
           "If rejected: Continue as standalone macro"
           "If deferred: Gather more evidence, iterate"))))

    (alerts
      ((high-priority
         (trigger . "PPX transformation produces invalid ReScript")
         (response
           ("1. Revert recent PPX changes"
            "2. Add regression test"
            "3. Fix transformation logic"
            "4. Verify with comprehensive test suite"))
         (escalation . "Block releases until fixed"))

       (medium-priority
         (trigger . "#8191 closed as won't-fix")
         (response
           ("1. Acknowledge in README"
            "2. Continue as standalone macro"
            "3. Focus on improving macro UX"
            "4. Document decision in META.scm"))
         (escalation . "None - pivot to long-term macro support"))

       (low-priority
         (trigger . "New ppxlib version released")
         (response
           ("1. Test compatibility"
            "2. Update opam dependencies if needed"
            "3. Run full test suite"))
         (escalation . "None unless breaking changes"))))

    (contacts
      ((maintainer . "hyperpolymath")
       (upstream . "rescript-lang/rescript-compiler")
       (community . "ReScript Discord #tooling channel")
       (issue-tracker . "github.com/hyperpolymath/rescript-early-return/issues")
       (related-issue . "rescript-lang/rescript-compiler#8191")))))
