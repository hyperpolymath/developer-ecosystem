; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2025 Hyperpolymath
;
; AGENTIC.scm - AI agent patterns and autonomous operation rules
; Media-Type: application/vnd.hyperpolymath.agentic+scm

(agentic
  (version "1.0.0")
  (project "rescript-full-stack")

  (agent-context
    (project-type "ecosystem-documentation")
    (primary-language "ReScript")
    (runtime "Deno")
    (complexity-level "high")
    (autonomous-operations-allowed #t))

  (operational-boundaries
    (allowed-actions
      ("Read and analyze project documentation")
      ("Update STATE.scm with progress")
      ("Generate ReScript code samples")
      ("Create integration examples")
      ("Update ROADMAP.adoc priorities")
      ("Add new component documentation")
      ("Fix AsciiDoc formatting issues"))

    (requires-approval
      ("Changing MoSCoW priorities")
      ("Removing components from scope")
      ("Modifying architecture decisions")
      ("Adding new stack layers")
      ("Deprecating community components"))

    (prohibited-actions
      ("Creating TypeScript files")
      ("Adding Node.js dependencies")
      ("Modifying LICENSE")
      ("Changing dual-license terms")
      ("Adding infrastructure bindings")))

  (code-generation-rules
    (language-requirements
      (primary "ReScript")
      (allowed "Rust" "Bash" "AsciiDoc")
      (forbidden "TypeScript" "Python" "Go" "Java"))

    (rescript-conventions
      (output-format "es6")
      (file-extension ".res")
      (interface-files "required for public APIs")
      (stdlib "@rescript/core"))

    (pattern-preferences
      (state-management "TEA")
      (routing "cadre-tea-router")
      (validation "rescript-schema")
      (http "Deno.serve or rescript-wasm-runtime")))

  (documentation-patterns
    (format-preference
      (primary "AsciiDoc")
      (secondary "inline ReScript comments")
      (avoid "Markdown for main docs"))

    (structure-requirements
      ("SPDX headers required")
      ("Examples must be complete and runnable")
      ("Integration patterns must show both components")
      ("Gap documentation must include rationale")))

  (session-protocols
    (on-start
      ("Read STATE.scm for current status")
      ("Check ROADMAP.adoc for priorities")
      ("Review ECOSYSTEM.scm for context"))

    (during-session
      ("Update STATE.scm as work completes")
      ("Track blockers discovered")
      ("Note integration opportunities"))

    (on-end
      ("Summarize accomplishments in STATE.scm")
      ("Update blockers-and-issues")
      ("Flag any priority changes needed")))

  (quality-gates
    (code-samples
      ("Must compile with latest ReScript")
      ("Must follow hyperpolymath conventions")
      ("Must include type annotations"))

    (documentation
      ("Must use proper AsciiDoc syntax")
      ("Must include SPDX headers")
      ("Must cross-reference related components"))

    (integration-examples
      ("Must show realistic use cases")
      ("Must handle error cases")
      ("Must follow TEA patterns where applicable"))))
