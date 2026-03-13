;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Project metadata and architectural decisions

(define project-meta
  `((version . "0.5.0")
    (architecture-decisions
      ((ADR-001
         ((title . "ReScript over TypeScript for implementation")
          (status . "accepted")
          (date . "2026-01-10")
          (context . "The evangeliser teaches ReScript to JS developers. Using ReScript for the tool itself demonstrates dogfooding and proves ReScript is production-ready.")
          (decision . "All application code written in ReScript 12.2. No TypeScript permitted.")
          (consequences . "Smaller contributor pool but stronger credibility. Forces us to solve real ReScript development challenges.")))
       (ADR-002
         ((title . "Regex-based pattern detection over AST parsing")
          (status . "accepted")
          (date . "2026-02-15")
          (context . "Pattern detection needs to identify JS idioms. AST parsing (Babel, tree-sitter) provides precision but adds heavy dependencies. Regex matching is simpler and sufficient for educational pattern identification.")
          (decision . "Use regex-based scanning for pattern detection. AST parsing may be added later as a complement.")
          (consequences . "Simpler implementation, zero heavy dependencies. Some false positives possible but acceptable for educational use. Faster scanning.")))
       (ADR-003
         ((title . "Celebrate/minimize/better narrative framework")
          (status . "accepted")
          (date . "2026-01-10")
          (context . "Developer education tools often shame users for 'bad' code. This discourages learning and creates hostility.")
          (decision . "All narratives follow the celebrate/minimize/better pattern: acknowledge what JS does well, gently note limitations, show how ReScript improves it.")
          (consequences . "Welcoming tone encourages adoption. More complex narrative generation but better educational outcomes.")))
       (ADR-004
         ((title . "Makaton-inspired glyph system for visual learning")
          (status . "accepted")
          (date . "2026-01-10")
          (context . "Code concepts can be represented visually to aid comprehension across language barriers. Makaton sign language uses simple symbols for complex concepts.")
          (decision . "21 glyph categories with visual symbols representing code concepts (shield for null safety, branch for pattern matching, etc.)")
          (consequences . "More accessible to visual learners and non-native English speakers. Unique differentiator from other educational tools.")))
       (ADR-005
         ((title . "Deno runtime, no npm")
          (status . "accepted")
          (date . "2026-01-10")
          (context . "Per hyperpolymath RSR policy, npm/Node.js are banned. Deno provides a secure runtime with built-in TypeScript support (unused) and excellent permissions model.")
          (decision . "Deno as sole runtime. No package.json for runtime deps. No node_modules.")
          (consequences . "Aligns with ecosystem standards. Deno's --allow-read permission model fits the scanner's file-reading needs.")))))
    (development-practices
      ((code-style . "rescript-standard")
       (testing . "deno-test-runner")
       (documentation . "asciidoc")
       (security . "openssf-scorecard")
       (versioning . "semver")
       (branching . "trunk-based")
       (ci . "12 github-actions workflows")
       (license . "PMPL-1.0-or-later")))
    (design-rationale
      ((philosophy . "Celebrate good, minimize bad, show better")
       (target-audience . "JavaScript developers curious about ReScript")
       (approach . "Progressive disclosure through RAW -> FOLDED -> GLYPHED view layers")
       (tone . "Encouraging, never shaming")))))
