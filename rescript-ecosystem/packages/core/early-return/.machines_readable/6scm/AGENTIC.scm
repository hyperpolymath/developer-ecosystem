;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-early-return

(define agentic-config
  `((version . "1.0.0")
    (project . "rescript-early-return")

    (claude-code
      ((model . "claude-sonnet-4-5-20250929")
       (tools . ("read" "edit" "bash" "grep" "glob"))
       (permissions . "read-all")
       (preferred-style . "technical-with-context")))

    (patterns
      ((code-review
         (focus . ("ppx-correctness" "ast-transformation" "macro-hygiene"))
         (check-for
           ("Verify extension node pattern matching"
            "Ensure generated code is valid ReScript"
            "Check for edge cases in transformation"
            "Validate AST structure preservation"
            "Confirm no variable capture in generated code")))

       (refactoring
         (style . "conservative")
         (preserve . ("PPX API surface" "extension node markers" "transformation semantics"))
         (acceptable . ("internal AST manipulation" "test organization" "documentation structure")))

       (testing
         (strategy . "comprehensive")
         (require
           ("Unit test for each transformation pattern"
            "Integration test with ReScript compiler"
            "Before/after examples for all use cases"
            "Edge case coverage (nested, complex expressions)"))
         (transformation-validation
           ("Parse transformed output with ReScript compiler"
            "Verify semantics match specification"
            "Check for syntax errors in generated code")))

       (documentation
         (format . "asciidoc")
         (include
           ("Clear positioning vs true syntactic sugar"
            "Transformation rules with examples"
            "Cost/benefit analysis with real data"
            "Path to compiler integration if validated"))
         (avoid . ("internal PPX implementation details" "AST structure details")))

       (ppx-development-checklist
         ("Update ppx/ppx_return_sugar.ml with new transformation"
          "Add test case in examples/before and examples/after"
          "Document transformation in docs/TRANSFORMATION-RULES.adoc"
          "Verify dune builds successfully"
          "Run integration tests"
          "Update DESUGARING-SPEC.adoc if semantics change"
          "Add ADR to META.scm for significant decisions"))))

    (constraints
      ((languages
         (primary . "ocaml")
         (target . "rescript")
         (test-runner . "deno")
         (build-system . "dune")
         (config . "nickel")
         (state-files . "guile-scheme"))

       (banned . ("typescript" "node" "npm" "go" "python" "makefile"))

       (ppx-architectural
         ("Never modify original AST structure unnecessarily"
          "Preserve location info for error messages"
          "Use ppxlib's AST builders for correctness"
          "Maintain hygiene - no variable capture"
          "Generate idiomatic ReScript code"
          "Document transformation invariants"))

       (macro-constraints
         ("Explicit markers required (%return.X)"
          "Function body scope only (no loops yet)"
          "Must desugar to standard ReScript"
          "No runtime dependencies"
          "Fail fast with clear error messages"))

       (validation-criteria
         ("Transformed code compiles with ReScript"
          "Semantics match DESUGARING-SPEC.adoc"
          "Error messages point to source location"
          "No accidental variable shadowing"))))

    (workflows
      ((new-transformation-pattern
         (steps
           ("1. Document pattern in DESUGARING-SPEC.adoc"
            "2. Create before/after examples"
            "3. Implement in ppx_return_sugar.ml"
            "4. Add ADR to META.scm explaining choice"
            "5. Test with ReScript compiler"
            "6. Update TRANSFORMATION-RULES.adoc")))

       (issue-8191-engagement
         (steps
           ("1. Monitor discussion for feedback"
            "2. Respond to technical questions"
            "3. Provide usage data from npm/GitHub"
            "4. Share real-world examples"
            "5. Update COST-BENEFIT.adoc with findings")))

       (graduation-to-compiler
         (steps
           ("1. Core team accepts #8191"
            "2. Provide reference implementation (this PPX)"
            "3. Assist with compiler integration"
            "4. Create codemod tool (macro -> sugar)"
            "5. Deprecate macro with migration guide"
            "6. Archive repository after 2 versions")))

       (alpha-release
         (steps
           ("1. Update version in dune-project and package.json"
            "2. Run full check suite (just check-all)"
            "3. Verify all 6 SCM files current"
            "4. Update CHANGELOG.adoc"
            "5. Update STATE.scm completion %"
            "6. Tag release: v0.1.0-alpha.N"
            "7. Publish to opam and npm")))))

    (ai-agent-guidance
      ((when-to-use-ppxlib-builders
         "Always use Ast_builder.Default for constructing AST nodes. Provides location info automatically and ensures well-formed AST.")

       (ast-pattern-matching
         "Use ppxlib.Ast_pattern for matching extension nodes. More robust than manual pattern matching, provides better error messages.")

       (transformation-testing
         "Test transformation by: 1) Create .res file with macro, 2) Run PPX, 3) Parse output with ReScript, 4) Verify compiled JS behavior matches spec.")

       (error-message-quality
         "Use Location.error_extensionf to create errors pointing to original source location. User sees error at %return.X site, not generated code.")

       (ppx-debugging
         "Use dune build --verbose to see PPX invocations. Print AST with Pprintast.expression. Test with minimal failing example.")

       (macro-vs-sugar-guidance
         "Macro: Explicit transformation with markers, available today, limited scope. Sugar: Invisible compiler feature, requires core team, works everywhere. Macro validates demand for sugar.")))))
