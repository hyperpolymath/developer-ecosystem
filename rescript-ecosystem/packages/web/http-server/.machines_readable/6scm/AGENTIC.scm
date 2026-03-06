;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-http-server

(define agentic-config
  `((version . "1.0.0")
    (project . "rescript-http-server")

    (claude-code
      ((model . "claude-opus-4-5-20251101")
       (tools . ("read" "edit" "bash" "grep" "glob" "write"))
       (permissions . "read-all")
       (context-files . ("src/HttpServer.res"
                         "src/HttpServer.resi"
                         "README.adoc"
                         "ROADMAP.adoc"))))

    (patterns
      ((code-review . "thorough")
       (refactoring . "conservative")
       (testing . "comprehensive")
       (documentation . "asciidoc-preferred")))

    (constraints
      ((languages . ("rescript" "javascript"))
       (banned . ("typescript" "go" "python" "node"))
       (runtime . "deno-only")
       (style . "functional-first")))

    (task-guidance
      ((adding-routes .
        "Add route helpers in HttpServer.res, expose in .resi, document in README")
       (adding-middleware .
        "Follow cors/logging pattern. Async function wrapping handler.")
       (bug-fixes .
        "Check both .res and .resi for type consistency")
       (new-features .
        "Update ROADMAP.adoc, STATE.scm, and README.adoc")))

    (code-patterns
      ((handlers . "async request => response")
       (middleware . "(request, handler) => promise<response>")
       (ffi . "@val @scope(\"Deno\") external")
       (error-handling . "Result or Option types, try/catch at boundaries")))

    (testing-guidance
      ((framework . "Deno.test")
       (location . "tests/")
       (naming . "*_test.res")
       (run . "deno test --allow-net")))))
