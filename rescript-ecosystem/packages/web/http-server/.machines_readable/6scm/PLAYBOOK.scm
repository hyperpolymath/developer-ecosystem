;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-http-server

(define playbook
  `((version . "1.0.0")
    (project . "rescript-http-server")

    (procedures
      ((build
         (steps
           (("compile" . "deno task build")
            ("verify" . "Check src/HttpServer.res.js exists")))
         (success-criteria . "No compiler errors, .res.js file generated"))

       (test
         (steps
           (("unit" . "deno test tests/")
            ("integration" . "deno test --allow-net tests/integration/")))
         (success-criteria . "All tests pass"))

       (release
         (steps
           (("version" . "Update version in deno.json and STATE.scm")
            ("changelog" . "Update ROADMAP.adoc with completed features")
            ("tag" . "git tag v$VERSION")
            ("push" . "git push origin main --tags")))
         (success-criteria . "Tag pushed, version updated"))

       (dev-server
         (steps
           (("watch" . "deno task dev")
            ("example" . "deno run --allow-net examples/basic.res.js")))
         (notes . "Watch mode rebuilds on file changes"))

       (clean
         (steps
           (("artifacts" . "deno task clean")
            ("cache" . "rm -rf lib/")))
         (notes . "Removes compiled JavaScript and build cache"))))

    (common-issues
      ((issue . "Compiler error: Unbound module Fetch")
       (cause . "Missing @rescript/core dependency")
       (fix . "Add @rescript/core to bs-dependencies in rescript.json"))

      ((issue . "Runtime error: Deno is not defined")
       (cause . "Running with Node.js instead of Deno")
       (fix . "Use deno run instead of node"))

      ((issue . "Type error in handler")
       (cause . "Handler not returning promise<response>")
       (fix . "Ensure handler is async or returns promise explicitly")))

    (alerts
      ((security . "Monitor Deno security advisories")
       (dependencies . "Check @rescript/core updates monthly")))

    (contacts
      ((maintainer . "hyperpolymath")
       (issues . "github.com/hyperpolymath/rescript-http-server/issues")
       (ecosystem . "github.com/hyperpolymath/rescript-full-stack")))))
