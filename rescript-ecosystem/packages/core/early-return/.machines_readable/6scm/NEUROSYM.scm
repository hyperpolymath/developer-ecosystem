;; SPDX-License-Identifier: PMPL-1.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for rescript-early-return

(define neurosym-config
  `((version . "1.0.0")
    (project . "rescript-early-return")

    (symbolic-layer
      ((type . "ppx-ast-transformation")
       (reasoning . "syntactic-rewriting")
       (verification . "rescript-compiler")
       (guarantees
         ("Transformed code type-checks"
          "Semantics preserved during transformation"
          "Source locations maintained for errors"
          "No variable capture (hygiene)"
          "Terminating transformation (no infinite loops)"))))

    (neural-layer
      ((llm-guidance
         (model . "claude-sonnet-4-5-20250929")
         (use-cases
           ("PPX transformation pattern generation"
            "Test case generation from transformation spec"
            "Documentation generation from AST patterns"
            "Error message improvements"
            "Cost/benefit analysis data collection"))
         (constraints
           ("Must generate valid OCaml for PPX"
            "Must preserve ReScript semantics"
            "Must maintain AST hygiene"
            "Must not introduce variable capture")))

       (embeddings . false)
       (fine-tuning . false)))

    (integration
      ((symbolic-ast-to-llm
         (workflow
           ("1. LLM reads DESUGARING-SPEC.adoc transformation rules"
            "2. Generates PPX code using ppxlib patterns"
            "3. Dune compiles PPX"
            "4. ReScript compiler validates transformed output"
            "5. Tests verify semantic preservation"))
         (feedback-loop
           ("OCaml compiler errors guide PPX corrections"
            "ReScript compiler errors guide transformation fixes"
            "Runtime tests validate semantics")))

       (transformation-verification
         (symbolic-phase
           ("PPX transforms AST: %return.X -> standard ReScript"
            "ReScript compiler proves type correctness"
            "Pattern exhaustiveness checked"
            "No undefined behavior"))
         (neural-phase
           ("LLM generates edge case tests"
            "LLM suggests transformation optimizations"
            "LLM documents transformation rationale"))
         (hybrid-validation
           "Symbolic: Compiler proves correctness. Neural: LLM finds edge cases compiler can't anticipate."))

       (demand-validation
         (symbolic-metrics
           ("Download count from npm"
            "GitHub stars/forks"
            "Issue count and sentiment"
            "ReScript compiler compatibility"))
         (neural-analysis
           ("LLM analyzes user feedback from issues"
            "Sentiment analysis of community discussions"
            "Pattern recognition: which use cases most common"
            "Recommendation: pursue #8191 or stay macro"))
         (decision-framework
           ("If symbolic metrics strong + neural sentiment positive -> Propose #8191"
            "If symbolic metrics weak -> Gather more data"
            "If neural sentiment negative -> Pivot approach")))

       (cost-benefit-reasoning
         (symbolic-facts
           ("Macro: Available today, explicit markers, optional"
            "Sugar: Requires compiler change, invisible, everywhere"
            "Macro: Limited scope (function bodies)"
            "Sugar: Full scope (loops, async, try/catch)"))
         (neural-judgment
           ("When is macro 'good enough'?"
            "When does sugar justify implementation cost?"
            "Which patterns demand compiler support?"
            "User empathy: frustration vs pragmatism"))
         (hybrid-decision
           "Symbolic framework + Neural judgment -> Actionable recommendation in COST-BENEFIT.adoc")))

    (verification-boundaries
      ((compile-time-ppx
         (enforced-by . "ocaml-compiler-and-dune")
         (guarantees
           ("Well-formed AST output"
            "No OCaml syntax errors"
            "Correct ppxlib usage")))

       (compile-time-rescript
         (enforced-by . "rescript-compiler")
         (validates
           ("Generated ReScript is valid"
            "Type safety preserved"
            "No undefined references"
            "Pattern exhaustiveness")))

       (test-time
         (enforced-by . "integration-tests")
         (validates
           ("Transformation semantics correct"
            "Early return behavior matches spec"
            "Error cases handled properly"
            "No runtime exceptions from generated code")))

       (usage-time
         (enforced-by . "community-feedback")
         (measures
           ("Adoption rate"
            "User satisfaction"
            "Bug reports"
            "Feature requests"
            "Sentiment in #8191 discussion")))))

    (ai-symbolic-synergy
      ((ppx-development
         "LLM generates PPX patterns -> OCaml compiler validates -> ppxlib ensures correctness")

       (transformation-design
         "Symbolic spec (DESUGARING-SPEC.adoc) defines rules -> LLM implements PPX -> Compiler validates output")

       (demand-validation-loop
         "Symbolic metrics (downloads, stars) + Neural analysis (sentiment, feedback) -> Decision: pursue #8191 or stay macro")

       (documentation-quality
         "Symbolic transformation rules + Neural explanations (why this design) -> Clear docs for users and core team")

       (community-engagement
         "Symbolic evidence (usage stats) + Neural persuasion (user stories) -> Convincing case for #8191 acceptance")))))
