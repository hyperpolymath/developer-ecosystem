;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-poly-core

(define agentic-config
  `((version . "1.0.0")
    (project . "rescript-poly-core")
    (claude-code
      ((model . "claude-opus-4-5-20251101")
       (tools . ("read" "edit" "bash" "grep" "glob" "write"))
       (permissions . "read-all")))
    (patterns
      ((code-review . "thorough")
       (refactoring . "conservative")
       (testing . "comprehensive")
       (documentation . "detailed")))
    (constraints
      ((languages . ("rescript" "javascript"))
       (banned . ("typescript" "go" "python" "node" "npm" "bun"))
       (runtime . "deno")))
    (code-generation
      ((style . "functional")
       (error-handling . "result-type")
       (async . "promise-based")
       (testing . "deno-test")))
    (file-patterns
      ((source . "src/**/*.res")
       (tests . "tests/**/*.ts")
       (docs . "**/*.adoc")
       (config . "*.json")))))
