;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-poly-core

(define playbook
  `((version . "1.0.0")
    (procedures
      ((build
         (("compile" . "deno task build")
          ("check" . "rescript build")))
       (test
         (("unit" . "deno task test")
          ("coverage" . "deno test --coverage=coverage/")))
       (release
         (("version" . "update deno.json and rescript.json")
          ("tag" . "git tag -s v$VERSION")
          ("publish" . "deno publish")))
       (debug
         (("logs" . "check structured JSON output")
          ("types" . "rescript build for type errors")))))
    (common-issues
      ((build-fails
         ("Ensure @rescript/core is installed"
          "Check ReScript version >= 11"
          "Run rescript clean && rescript build"))
       (import-errors
         ("Use .res.js extension in imports"
          "Check deno.json exports path"))))
    (contacts
      ((maintainer . "hyperpolymath")
       (repo . "github.com/hyperpolymath/rescript-poly-core")))))
