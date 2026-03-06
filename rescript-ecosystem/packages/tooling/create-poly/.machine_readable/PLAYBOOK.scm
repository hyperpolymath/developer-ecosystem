;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-poly-core

(define playbook
  `((version . "1.0.0")
    (project . "rescript-poly-core")
    (procedures
      ((setup
         (("install-deno" . "curl -fsSL https://deno.land/install.sh | sh")
          ("clone" . "git clone https://github.com/hyperpolymath/rescript-poly-core.git")
          ("build" . "deno task build")))
       (develop
         (("watch" . "deno task dev")
          ("test" . "deno task test")
          ("lint" . "deno task lint")))
       (release
         (("version-bump" . "Update version in deno.json and rescript.json")
          ("changelog" . "Update CHANGELOG.adoc")
          ("build" . "deno task build")
          ("test" . "deno task test")
          ("tag" . "git tag -s v<version>")
          ("publish" . "deno publish")))
       (debug
         (("check-types" . "deno task build")
          ("run-specific-test" . "deno test tests/<file>.ts")
          ("verbose-build" . "rescript build -verbose")))))
    (common-issues
      (("rescript-compile-error"
        (symptoms . "Build fails with type error")
        (diagnosis . "Check ReScript error message")
        (resolution . "Fix type annotations or logic"))
       ("import-error"
        (symptoms . "Module not found at runtime")
        (diagnosis . "Check .res.js file exists")
        (resolution . "Run deno task build first"))))
    (contacts
      ((maintainer . "hyperpolymath")
       (issues . "https://github.com/hyperpolymath/rescript-poly-core/issues")))))
