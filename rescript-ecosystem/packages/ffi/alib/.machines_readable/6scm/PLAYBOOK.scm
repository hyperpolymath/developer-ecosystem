;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-alib

(define playbook
  `((version . "1.0.0")
    (project . "rescript-alib")

    (procedures
      ((build
         (steps
           ("1. Clean artifacts: just clean"
            "2. Compile ReScript: just build"
            "3. Verify output in src/**/*.res.js"))
         (troubleshooting
           ((issue . "ReScript compiler not found")
            (solution . "Run: npm install -g rescript@latest"))
           ((issue . "Syntax errors in .res files")
            (solution . "Check for missing semicolons, incorrect pattern match"))
           ((issue . "Module not found errors")
            (solution . "Verify rescript.json sources array includes directory"))))

       (test
         (steps
           ("1. Ensure ReScript compiled: just build"
            "2. Run unit tests: just test-unit"
            "3. Run integration tests: just test-integration"
            "4. Check coverage report in console"))
         (troubleshooting
           ((issue . "Deno command not found")
            (solution . "Install Deno: curl -fsSL https://deno.land/install.sh | sh"))
           ((issue . "Import errors for .res.js files")
            (solution . "Run 'just build' first - tests import compiled output"))
           ((issue . "Tests fail with type errors")
            (solution . "Check that branded types are used correctly in tests"))))

       (benchmark
         (steps
           ("1. Compile in production mode: just build"
            "2. Run benchmarks: just bench"
            "3. Verify parse overhead <= 5%"
            "4. Verify reveal overhead == 0%"))
         (troubleshooting
           ((issue . "Benchmark results inconsistent")
            (solution . "Run multiple times, disable other processes, check V8 optimization"))
           ((issue . "Parse overhead exceeds 5%")
            (solution . "Check @inline annotations, verify regex compilation"))
           ((issue . "Reveal overhead non-zero")
            (solution . "Verify %identity external, check for accidental string copying"))))

       (release-alpha
         (steps
           ("1. Update version in rescript.json"
            "2. Run full check: just check"
            "3. Update CHANGELOG.adoc"
            "4. Update STATE.scm completion percentage"
            "5. Commit: git commit -m 'chore: bump to v0.1.0-alpha.N'"
            "6. Tag: git tag v0.1.0-alpha.N"
            "7. Push: git push && git push --tags"
            "8. Publish to npm: npm publish --tag alpha"))
         (rollback
           ("1. Delete tag: git tag -d v0.1.0-alpha.N"
            "2. Unpublish from npm: npm unpublish @hyperpolymath/rescript-alib@0.1.0-alpha.N"
            "3. Revert version: git revert HEAD")))

       (upstream-proposal
         (steps
           ("1. Gather evidence: GitHub issues, discussions, benchmarks"
            "2. Create RFC document in docs/rfc/"
            "3. Post to ReScript forums/Discord"
            "4. Create RFC issue in rescript-lang/rescript-compiler"
            "5. Link to rescript-alib as proof-of-concept"
            "6. Iterate on feedback"
            "7. If accepted: Prepare graduation plan"))
         (graduation-checklist
           ("Confirm upstream implementation matches API"
            "Add deprecation notice to README"
            "Create tombstone file with migration guide"
            "Wait 2 minor versions"
            "Delete implementation"
            "Update CHANGELOG")))

       (debug-type-error
         (steps
           ("1. Read compiler error message carefully"
            "2. Check signature (.resi) matches implementation (.res)"
            "3. Verify branded types not mixed (e.g., Email.t != Slug.t)"
            "4. Use reveal() to unwrap if needed"
            "5. Check for missing @inline or %identity"))
         (common-errors
           ((error . "Type t is not compatible with string")
            (solution . "Use reveal() to unwrap branded type"))
           ((error . "This expression has type Email.t but expected Slug.t")
            (solution . "Branded types are distinct - cannot mix"))
           ((error . "Unbound module Email")
            (solution . "Check rescript.json namespace, verify src/Common/Alib_String.res compiled"))))

       (debug-runtime-error
         (steps
           ("1. Check Deno error output"
            "2. Verify .res.js files exist (run 'just build')"
            "3. Check import paths in .js test files"
            "4. Use console.log in .res files (compiles to console.log)"
            "5. Run tests with --inspect-brk for debugging"))
         (common-errors
           ((error . "Cannot find module .res.js")
            (solution . "Run 'just build' first"))
           ((error . "Validation failed but test expected success")
            (solution . "Check regex pattern, test input format"))
           ((error . "reveal() returns undefined")
            (solution . "Check that parse() succeeded before reveal()")))))

       (onboarding-new-contributor
         (steps
           ("1. Read README.adoc philosophy section"
            "2. Review existing Alib_String implementation"
            "3. Run 'just check' to verify setup"
            "4. Pick an issue labeled 'good-first-issue'"
            "5. Create feature branch: git checkout -b feature/name"
            "6. Implement following agentic checklist in AGENTIC.scm"
            "7. Submit PR with tests and benchmarks")))

       (ci-failure-triage
         (steps
           ("1. Check GitHub Actions workflow log"
            "2. Identify failed step (build/test/bench)"
            "3. Reproduce locally: just check"
            "4. Fix issue"
            "5. Push fix"
            "6. Verify CI green"))
         (common-failures
           ((failure . "ReScript compilation error")
            (solution . "Check syntax in .res files, verify rescript version"))
           ((failure . "Tests fail")
            (solution . "Run 'just test' locally, check for missing files"))
           ((failure . "Benchmark threshold exceeded")
            (solution . "Review recent changes, check for removed @inline"))
           ((failure . "SCM validation failed")
            (solution . "Ensure all 6 SCM files present and valid Scheme"))))))

    (alerts
      ((high-priority
         (trigger . "Benchmark threshold exceeded in CI")
         (response
           ("1. Investigate recent commits"
            "2. Check for removed @inline or %identity"
            "3. Revert if performance regression unexplained"
            "4. Update ADR if intentional tradeoff"))
         (escalation . "Discuss in GitHub issue before merging"))

       (medium-priority
         (trigger . "Test coverage below 90%")
         (response
           ("1. Identify uncovered code paths"
            "2. Add tests or mark as unreachable"
            "3. Update coverage target if justified"))
         (escalation . "Block release until resolved"))

       (low-priority
         (trigger . "Deprecation warning from Deno/ReScript")
         (response
           ("1. Note in GitHub issue"
            "2. Schedule fix in next minor release"
            "3. Update docs if user-facing"))
         (escalation . "None unless breaking change imminent"))))

    (contacts
      ((maintainer . "hyperpolymath")
       (upstream . "rescript-lang/rescript-compiler")
       (community . "ReScript Discord #libraries channel")
       (issue-tracker . "github.com/hyperpolymath/rescript-alib/issues")))))
