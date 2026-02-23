;; SPDX-License-Identifier: MPL-2.0-or-later
;; META.scm - Meta-level information for techstack-enforcer
;; Media-Type: application/meta+scheme

(meta
  (architecture-decisions
    ((id . "ADR-001")
     (title . "Ada/SPARK for core enforcement engine")
     (status . "accepted")
     (context . "Enforcement engine must be trustworthy — cannot be compromised by the same class of bugs it guards against")
     (decision . "Write core engine in Ada/SPARK with formal verification (gnatprove --level=2)")
     (consequences . "Requires GNAT toolchain. Engine provably free from buffer overflows, null dereferences, undefined behaviour."))

    ((id . "ADR-002")
     (title . "Multi-layer blocking architecture")
     (status . "accepted")
     (context . "Single-layer enforcement (e.g. CI only) can be bypassed. Need absolute blocking at every entry point.")
     (decision . "Enforce at 6 layers: pre-commit, pre-push, CI/CD, file watcher, container guard, commit-msg")
     (consequences . "No single bypass circumvents all layers. Developers cannot accidentally commit banned code."))

    ((id . "ADR-003")
     (title . "Learning mode from security failures")
     (status . "accepted")
     (context . "Rather than just blocking, the tool should educate — recommending languages that eliminate vulnerability classes by design")
     (decision . "Integrate NVD 2.0 CVE API. Map vulnerability types to language design features. Surface recommendations via TUI and JSON API.")
     (consequences . "Tool becomes educational, not just punitive. Gradual adoption path via learning mode."))

    ((id . "ADR-004")
     (title . "Ada/SPARK TUI for rapid management")
     (status . "accepted")
     (context . "Filter management must be fast and keyboard-driven, not require editing config files")
     (decision . "ncurses-based TUI in Ada with vim-style navigation (j/k), modal editing, real-time scanning")
     (consequences . "Quick add/remove/toggle of filters. Mode switching (1-4) for learning/warn/enforce/lockdown."))

    ((id . "ADR-005")
     (title . "TOML configuration format")
     (status . "accepted")
     (context . "Config must be human-readable and machine-parseable")
     (decision . "TOML for configuration (techstack.toml) and definition sets (defsets/*.toml)")
     (consequences . "Easy to edit by hand, easy to generate programmatically, well-supported across toolchains"))

    ((id . "ADR-006")
     (title . "Scheme DSL for policy files")
     (status . "accepted")
     (context . "Composable policy definitions need a structured format with inheritance")
     (decision . "S-expression format: (filterlist ...) with (import), (block), (allow) forms")
     (consequences . "Policies are composable, importable from remote repos, and parseable by existing Scheme tooling")))

  (development-practices
    (code-style
      ("Ada 2022 standard (-gnat2022)"
       "SPARK_Mode on all core/ packages"
       "gnatprove --level=2 for formal verification"
       "Pretty printer: 100-char line width, 3-space indent"))
    (security
      (principle "Defense in depth — multiple independent enforcement layers")
      (principle "The enforcer itself must be formally verified")
      (principle "The best security fix is a language that makes the vulnerability class impossible"))
    (testing
      ("SPARK proofs as primary verification"
       "Integration tests for hook flow"
       "Definition set validation tests"))
    (versioning "SemVer")
    (documentation "AsciiDoc (README.adoc) + Markdown (README.md, docs/)")
    (branching "main for stable"))

  (design-rationale
    ("Core insight: absolute blocking at every layer makes circumvention practically impossible"
     "Ada/SPARK chosen so the enforcer cannot be compromised by memory-safety bugs"
     "Learning mode turns enforcement from punitive to educational"
     "TUI provides rapid management without leaving the terminal"
     "Definition sets allow immediate deployment without configuration"
     "JSON API enables integration with any CI/CD or automation tool")))
