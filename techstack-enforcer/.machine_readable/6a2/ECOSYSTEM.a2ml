;; SPDX-License-Identifier: MPL-2.0-or-later
;; ECOSYSTEM.scm - Ecosystem position for techstack-enforcer
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "techstack-enforcer")
  (type "policy-enforcement-tool")
  (purpose "Formally verified multi-layer technology stack enforcement — blocks forbidden languages/patterns via git hooks, CI/CD, file watchers, and container guards")

  (position-in-ecosystem
    (category "rsr-enforcement")
    (subcategory "language-policy")
    (unique-value
      "Only tool providing SPARK-verified multi-layer language enforcement with 6 blocking layers"
      "Learning mode analyses CVE patterns to recommend safer languages by design"
      "Ada/SPARK TUI for rapid keyboard-driven filter management"
      "Bridges RSR specifications with automated CI/CD enforcement"
      "Provides preset definition sets (strict/moderate/enterprise) for immediate use"))

  (related-projects
    ((name . "rsr-template-repo")
     (relationship . "should-include-by-default")
     (description . "Template repos should ship with techstack-enforcer config and hooks"))

    ((name . "reposystem")
     (relationship . "validates-policies-for")
     (description . "Reposystem can use techstack-enforcer to audit entire ecosystem"))

    ((name . "gitbot-fleet")
     (relationship . "provides-checks-for")
     (description . "Bots can use enforcer to validate changes before applying"))

    ((name . "scaffoldia")
     (relationship . "validates-templates")
     (description . "Scaffoldia templates should pass techstack-enforcer checks"))

    ((name . "gitvisor")
     (relationship . "integrates-with")
     (description . "GitVisor file watcher triggers techstack-enforcer on file change events"))

    ((name . "rhodibot")
     (relationship . "used-by")
     (description . "Rhodibot uses techstack-enforcer internally for CCCP (banned language) detection"))

    ((name . "panic-attacker")
     (relationship . "complements")
     (description . "panic-attacker scans for security weak points; techstack-enforcer prevents them by language policy")))

  (what-this-is
    "Ada/SPARK formally verified technology stack enforcement engine"
    "Multi-layer blocking: git hooks, CI/CD, file watchers, container guards"
    "Ada/SPARK TUI for rapid keyboard-driven filter management"
    "Learning mode that analyses CVE patterns to recommend safer languages"
    "TOML-based definition sets with severity levels (fatal/block/warn/allow)"
    "Four enforcement modes: learning, warn, enforce, lockdown"
    "JSON API for structured decisions and tool integration"
    "Desktop notification system (notify-send, webhook, syslog)"
    "CI/CD templates for GitLab CI and GitHub Actions"
    "RSR language policy enforcement engine"
    "Self-hostable and reproducible policy checker")

  (what-this-is-not
    "NOT a linter for code quality (use language-specific linters)"
    "NOT a package manager or dependency resolver"
    "NOT a build tool"
    "NOT concerned with code style/formatting (use formatters)"
    "NOT an advisory-only tool — in enforce/lockdown mode, violations are fatal"))
