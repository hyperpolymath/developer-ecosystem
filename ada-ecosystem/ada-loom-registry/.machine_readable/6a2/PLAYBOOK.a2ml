;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for ada-loom-registry (Spindle)

(define playbook
  `((version . "1.0.0")
    (procedures
      ((build
         (("update-deps" . "cabal update")
          ("build-all" . "just build")
          ("build-release" . "just build-release")))
       (test
         (("run-tests" . "just test")
          ("run-lint" . "just lint")
          ("check-format" . "just check")))
       (deploy
         (("generate-docs" . "just docs")
          ("release" . "cabal sdist")))
       (rollback
         (("git-revert" . "git revert HEAD")
          ("clean-build" . "just clean")))
       (debug
         (("check-registry" . "cat .spindle/registry.json")
          ("parse-test" . "cabal run spindle -- parse config/build.ncl")
          ("list-entries" . "cabal run spindle -- list")))))
    (alerts
      ((build-failure . "Check GHC version compatibility")
       (test-failure . "Review hlint suggestions")
       (parse-error . "Validate Nickel syntax with nickel check")))
    (contacts
      ((maintainer . "hyperpolymath@users.noreply.github.com")
       (issues . "https://github.com/hyperpolymath/ada-loom-registry/issues")))))
