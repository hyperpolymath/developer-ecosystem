;; SPDX-License-Identifier: MPL-2.0-or-later
;; STATE.scm - Project state for techstack-enforcer
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.2.0")
    (schema-version "1.0")
    (created "2026-01-03")
    (updated "2026-02-19")
    (project "techstack-enforcer")
    (repo "github.com/hyperpolymath/techstack-enforcer"))

  (project-context
    (name "techstack-enforcer")
    (tagline "Formally verified multi-layer technology stack enforcement — blocks by every possible means")
    (tech-stack ("Ada" "SPARK" "TOML" "Guile Scheme")))

  (current-position
    (phase "active-implementation")
    (overall-completion 45)
    (components
      ((name . "Ada/SPARK Core Engine")
       (status . "in-progress")
       (completion . 55)
       (description . "SPARK-verified enforcement engine: types, patterns, defsets, JSON I/O. 14 Ada files present."))

      ((name . "Ada/SPARK TUI")
       (status . "in-progress")
       (completion . 40)
       (description . "ncurses-based keyboard-driven filter management interface. View modes, keybindings defined."))

      ((name . "Learning Mode")
       (status . "in-progress")
       (completion . 30)
       (description . "CVE-to-language recommendation engine. NVD 2.0 API integration configured. Pattern database planned."))

      ((name . "Definition Sets")
       (status . "complete")
       (completion . 100)
       (description . "strict.toml, moderate.toml, enterprise.toml presets with severity levels"))

      ((name . "Git Hook Integration")
       (status . "in-progress")
       (completion . 40)
       (description . "Pre-commit, pre-push, commit-msg hooks. Install scripts present."))

      ((name . "Notification System")
       (status . "planned")
       (completion . 15)
       (description . "Desktop (notify-send), log, webhook, syslog channels. Config scaffolded in techstack.toml."))

      ((name . "CI/CD Templates")
       (status . "complete")
       (completion . 100)
       (description . "GitLab CI and GitHub Actions templates with learning, check, audit, decide jobs"))

      ((name . "Documentation")
       (status . "complete")
       (completion . 100)
       (description . "README.md, README.adoc, 8 docs/ files, CLI reference, TUI guide"))

      ((name . "Idris2 ABI / Zig FFI")
       (status . "planned")
       (completion . 0)
       (description . "Idris2 ABI definitions and Zig FFI bridge per hyperpolymath standard"))

      ((name . "Ecosystem Integration")
       (status . "in-progress")
       (completion . 35)
       (description . "ECOSYSTEM.scm populated, GitVisor integration designed, reposystem registration pending")))

    (working-features
      ("TOML definition set parsing"
       "Three preset definition sets (strict/moderate/enterprise)"
       "Pattern matching for file types with glob syntax"
       "Severity levels (fatal/block/warn/allow)"
       "Four enforcement modes (learning/warn/enforce/lockdown)"
       "JSON API for structured decisions"
       "CLI audit and check commands"
       "CI/CD templates for GitLab and GitHub")))

  (route-to-mvp
    (milestones
      ((name . "v0.1.0 - Core Enforcement")
       (items
         ("SPARK-verify all core/ packages"
          "Git hooks working end-to-end"
          "Notification system (desktop + log)"
          "Install script for multi-repo deployment")))
      ((name . "v0.2.0 - TUI + Learning")
       (items
         ("Complete TUI with all keybindings"
          "Learning mode CVE integration"
          "Pattern database persistence"
          "Webhook notifications")))
      ((name . "v1.0.0 - Production Ready")
       (items
         ("Idris2 ABI definitions"
          "Zig FFI bridge"
          "File watcher (GitVisor) integration"
          "Container build guard"
          "Published GitHub Action"
          "Comprehensive test suite")))))

  (blockers-and-issues
    (critical)
    (high
      ("SPARK verification not yet run on all packages"))
    (medium
      ("Notification system only scaffolded in config"
       "Learning mode CVE API integration not tested"))
    (low
      ("Idris2 ABI not yet started")))

  (critical-next-actions
    (immediate
      ("Run gnatprove on core/ packages"
       "Complete pre-commit hook end-to-end flow"))
    (this-week
      ("Implement notify-send integration"
       "Test learning mode CVE API calls"))
    (this-month
      ("Complete TUI implementation"
       "GitVisor file watcher integration")))

  (session-history
    (("2026-02-19" "Renamed techstack-filterlist to techstack-enforcer, rewrote docs with full architecture intent"))))
