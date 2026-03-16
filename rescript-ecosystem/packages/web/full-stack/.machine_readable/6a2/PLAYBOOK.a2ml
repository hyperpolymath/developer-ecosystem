; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2025 Hyperpolymath
;
; PLAYBOOK.scm - Operational runbook for project maintenance
; Media-Type: application/vnd.hyperpolymath.playbook+scm

(playbook
  (version "1.0.0")
  (project "rescript-full-stack")

  (runbooks
    (add-new-component
      (description "Add a new component to the ecosystem map")
      (steps
        (step 1 "Determine component category (presentation/data/runtime/network/persistence)")
        (step 2 "Add entry to README.adoc in appropriate section")
        (step 3 "Add entry to COMPONENTS.adoc with features list")
        (step 4 "Update ROADMAP.adoc if component fills a gap")
        (step 5 "Update STATE.scm components section")
        (step 6 "Update ECOSYSTEM.scm related-projects"))
      (validation
        ("Component appears in correct category")
        ("Links are valid GitHub URLs")
        ("Status is one of: active, in-development, planned, community")))

    (update-ecosystem-status
      (description "Update component status as development progresses")
      (steps
        (step 1 "Update status in README.adoc table")
        (step 2 "Update status in ROADMAP.adoc")
        (step 3 "Update STATE.scm current-position")
        (step 4 "Update completion percentage if significant change")
        (step 5 "Move blockers if resolved"))
      (validation
        ("Status consistent across all files")
        ("Completion percentage reflects reality")))

    (add-architecture-decision
      (description "Document a new architectural decision")
      (steps
        (step 1 "Create ADR entry in META.scm architecture-decisions")
        (step 2 "Use format: adr-NNN with title, status, date, context, decision, consequences")
        (step 3 "Add to ROADMAP.adoc Decision Log if user-facing")
        (step 4 "Update design-rationale if adds new why-X"))
      (validation
        ("ADR has all required fields")
        ("Consequences include both positive and negative")))

    (evaluate-community-component
      (description "Evaluate a community component for recommendation")
      (steps
        (step 1 "Check maintenance status (last commit, open issues)")
        (step 2 "Review type safety (proper .resi files)")
        (step 3 "Check Deno compatibility")
        (step 4 "Test with current rescript version")
        (step 5 "Document in COMPONENTS.adoc with honest assessment"))
      (validation
        ("Evaluation includes maintenance assessment")
        ("Deno compatibility noted")
        ("Alternatives documented if issues found")))

    (fill-ecosystem-gap
      (description "Plan work to fill an identified gap")
      (steps
        (step 1 "Move from Gaps section to In Development in README.adoc")
        (step 2 "Create GitHub repo if hyperpolymath-owned")
        (step 3 "Add to ECOSYSTEM.scm related-projects")
        (step 4 "Update STATE.scm milestones")
        (step 5 "Track in blockers-and-issues if dependencies exist"))
      (validation
        ("Gap removed from Gaps section")
        ("New component has consistent status everywhere"))))

  (incident-response
    (broken-community-dependency
      (severity "high")
      (detection "CI fails or runtime errors reported")
      (response
        (step 1 "Identify breaking change or deprecation")
        (step 2 "Check for maintained fork or alternative")
        (step 3 "Update COMPONENTS.adoc with warning")
        (step 4 "Consider building hyperpolymath replacement")
        (step 5 "Update ROADMAP.adoc priorities if needed")))

    (rescript-breaking-change
      (severity "critical")
      (detection "New ReScript version breaks components")
      (response
        (step 1 "Document breaking changes in ADR")
        (step 2 "Test all hyperpolymath components")
        (step 3 "Update compatibility notes in README.adoc")
        (step 4 "Coordinate updates across repos")))

    (security-vulnerability
      (severity "critical")
      (detection "Security advisory or vulnerability scan")
      (response
        (step 1 "Assess impact on stack components")
        (step 2 "Update affected components immediately")
        (step 3 "Notify users via SECURITY.md update")
        (step 4 "Document in session-history"))))

  (maintenance-schedules
    (weekly
      ("Review GitHub issues on all hyperpolymath repos")
      ("Check for new community components"))

    (monthly
      ("Update completion percentages")
      ("Review and prioritize gaps")
      ("Check community component health"))

    (quarterly
      ("Full ROADMAP.adoc review")
      ("Evaluate MoSCoW priorities")
      ("Update architecture decisions if needed"))))
