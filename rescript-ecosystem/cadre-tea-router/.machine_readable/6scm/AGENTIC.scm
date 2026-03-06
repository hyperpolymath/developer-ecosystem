;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent config

(define agentic-config
  `((version . "1.0.0")
    (claude-code
      ((model . "claude-opus-4-5-20251101")
       (tools . ("read" "edit" "bash" "grep" "glob"))
       (permissions . "read-all")))
    (patterns
      ((code-review . "thorough")
       (refactoring . "conservative")))
    (constraints
      ((banned . ("typescript" "go" "python" "makefile"))))))
