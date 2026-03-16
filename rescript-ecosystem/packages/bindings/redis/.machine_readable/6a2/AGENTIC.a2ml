;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-redis

(define agentic-config
  `((version . "1.0.0")
    (claude-code
      ((model . "claude-opus-4-5-20251101")
       (tools . ("read" "edit" "bash" "grep" "glob"))
       (permissions . "read-all")))
    (patterns
      ((code-review . "thorough")
       (refactoring . "conservative")
       (testing . "comprehensive")
       (documentation . "detailed")))
    (constraints
      ((languages . ("rescript" "javascript"))
       (banned . ("typescript" "go" "python" "node"))))
    (project-specific
      ((runtime . "deno")
       (package-manager . "deno")
       (test-command . "deno task test")
       (build-command . "deno task build")
       (formatting . "rescript-format")))))
