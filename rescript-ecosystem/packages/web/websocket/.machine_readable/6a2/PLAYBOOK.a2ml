;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-websocket

(define playbook
  `((version . "1.0.0")
    (procedures
      ((build . (("compile" . "just build")
                 ("watch" . "just dev")))
       (test . (("unit" . "just test")
                ("coverage" . "just test-coverage")))
       (release . (("build" . "just build-release")
                   ("publish" . "deno publish")))
       (debug . (("repl" . "deno repl")
                 ("inspect" . "deno run --inspect")))))
    (alerts
      ((build-failure . "Check ReScript compiler output")
       (test-failure . "Review test logs")))
    (contacts
      ((maintainer . "hyperpolymath@proton.me")
       (issues . "github.com/hyperpolymath/rescript-websocket/issues")))))
