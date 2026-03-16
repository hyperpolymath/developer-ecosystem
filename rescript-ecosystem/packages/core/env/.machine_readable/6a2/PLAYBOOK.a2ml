;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-env

(define playbook
  `((version . "1.0.0")

    (project . "rescript-env")

    (procedures
      ((build
        (("compile" . "just build")
         ("watch" . "just dev")
         ("clean" . "just clean")))

       (test
        (("run" . "just test")
         ("verbose" . "just test-verbose")))

       (release
        (("1-update-version" . "Edit deno.json version")
         ("2-update-changelog" . "Update CHANGELOG.adoc")
         ("3-update-state" . "Update .machine_readable/STATE.scm")
         ("4-commit" . "git commit -am 'chore: release vX.Y.Z'")
         ("5-tag" . "git tag vX.Y.Z")
         ("6-push" . "git push && git push --tags")
         ("7-publish" . "deno publish")))

       (debug
        (("type-errors" . "just build 2>&1 | head -50")
         ("runtime-check" . "Check globalThis.Deno or globalThis.process")))))

    (alerts
      ((ci-failure . "Check GitHub Actions")
       (type-error . "Run just build for details")))

    (contacts
      ((maintainer . "hyperpolymath")
       (email . "hyperpolymath@proton.me")
       (github . "https://github.com/hyperpolymath/rescript-env")))))
