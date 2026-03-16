;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-poly-core

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
       (documentation . "inline-comments")))
    (constraints
      ((languages . ("rescript" "bash"))
       (banned . ("typescript" "go" "python" "makefile" "npm" "node"))))
    (project-specific
      ((module-pattern . "src/{Category}/{Module}.res")
       (test-pattern . "tests/{Module}_test.res")
       (naming . "camelCase for functions, PascalCase for modules")
       (error-handling . "Result types, not exceptions")
       (async-pattern . "async/await with Promise")))))

;; Agent guidance for this project
(define agent-guidance
  `((when-adding-features
      ("Add to appropriate Core or MCP submodule"
       "Follow existing patterns in similar modules"
       "Update PolyCore.res to re-export if public"
       "Add tests in tests/ directory"
       "Update README.adoc with usage examples"))
    (when-fixing-bugs
      ("Reproduce with test first"
       "Fix with minimal changes"
       "Ensure backwards compatibility"))
    (when-refactoring
      ("Preserve public API"
       "Update all call sites"
       "Run full test suite"))
    (code-generation-preferences
      ("Prefer pattern matching over if/else"
       "Use pipe operator for chaining"
       "Explicit type annotations on public functions"
       "Doc comments with /** */ syntax"))))
