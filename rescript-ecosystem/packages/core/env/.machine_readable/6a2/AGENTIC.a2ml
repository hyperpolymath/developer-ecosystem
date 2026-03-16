;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-env

(define agentic-config
  `((version . "1.0.0")

    (project-context
      ((type . "library")
       (language . "ReScript")
       (runtime . ("Deno" "Node.js" "Bun"))
       (purpose . "Type-safe environment variable access")))

    (claude-code
      ((model . "claude-opus-4-5-20251101")
       (tools . ("read" "edit" "bash" "grep" "glob" "write"))
       (permissions . "read-write")))

    (patterns
      ((code-review
        ((focus . ("type-safety" "runtime-compatibility" "error-handling"))
         (style . "thorough")))
       (refactoring
        ((approach . "conservative")
         (preserve . ("public-api" "type-signatures"))))
       (testing
        ((framework . "deno-test")
         (coverage . "comprehensive")
         (style . "behavior-driven")))
       (documentation
        ((format . "asciidoc")
         (examples . "required")
         (api-docs . "jsdoc-style-comments")))))

    (constraints
      ((languages-allowed . ("ReScript" "JavaScript"))
       (languages-banned . ("TypeScript" "Go" "Python"))
       (frameworks-allowed . ("Deno" "Node.js"))
       (package-managers . ("Deno" "JSR"))
       (package-managers-banned . ("npm" "yarn" "pnpm" "bun"))))

    (code-generation
      ((style . "functional")
       (prefer . ("option-types" "pattern-matching" "pipe-operators"))
       (avoid . ("mutation" "any-types" "exceptions-for-control-flow"))))

    (file-patterns
      ((source . "src/**/*.res")
       (interface . "src/**/*.resi")
       (tests . "tests/**/*.res")
       (config . ("deno.json" "rescript.json"))
       (docs . ("*.adoc" "*.md"))))))
