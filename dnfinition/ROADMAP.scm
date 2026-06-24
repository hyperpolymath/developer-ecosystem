;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; SPDX-License-Identifier: MPL-2.0
;; ROADMAP.scm - Detailed path from 0.0.4 to 1.0.0

(define roadmap
  '((document-info
     (version . "1.0")
     (created . "2025-12-30")
     (purpose . "Define the complete path to 1.0.0 production release"))

    ;; What 1.0.0 means for dnfinition
    (vision-1-0-0
     (tagline
      "A universal package manager with guaranteed reversibility")

     (core-guarantees
      ((reversibility
        "Every operation can be completely undone within retention window"
        "Atomic transaction-snapshot linkage ensures consistency"
        "SPARK-proven safety properties on rollback paths")

       (safety
        "No operation can brick the system"
        "Formal verification of critical state transitions"
        "Defense-in-depth input validation")

       (universality
        "Works across DNF, rpm-ostree, flatpak, and language managers"
        "Single interface, consistent semantics"
        "Respects backend-native transactions where available")))

     (why-1-0-0-matters
      "1.0.0 is the first version safe for production Fedora Silverblue/Workstation use."
      "It represents complete, verified, tested functionality - not just features existing."
      "Users can trust that 'dnf install X' via dnfinition will never leave their system unrecoverable."))

    ;; Current position
    (current-state
     (version . "0.0.4")
     (completion . 55)
     (strengths
      ("Build system and CI complete"
       "Type system well-defined"
       "Ada-Elixir IPC protocol established (GNATCOLL.JSON)"
       "Transaction-snapshot atomicity designed and wired"
       "SPARK_Mode declared on safety-critical modules"))

     (weaknesses
      ("Shell injection vulnerability in filesystem commands"
       "SPARK proofs never run"
       "No E2E integration test Ada↔Elixir"
       "Backends mostly stubs"
       "Download manager disconnected from mirror optimizer")))

    ;; Milestone definitions
    (milestones

     ;; ========== 0.0.5 - SECURITY HARDENING ==========
     ((version . "0.0.5")
      (name . "Security Hardening")
      (theme . "Fix all security vulnerabilities and run SPARK proofs")
      (target-completion . 65)

      (requirements
       ((security
         (shell-escape
          "Create shell_escape utility in Ada"
          "Apply to btrfs_snapshots.adb, zfs_snapshots.adb, lvm_snapshots.adb"
          "Escape: spaces, quotes, semicolons, pipes, backticks, $, newlines"
          "Test with adversarial path inputs")

         (input-validation
          "Validate all IPC JSON structure before processing"
          "Bound string lengths per META.scm security-requirements"
          "Reject malformed transaction/snapshot IDs"))

        (formal-verification
         (spark-proofs
          "Run gnatprove on rollback_engine.ads/adb"
          "Run gnatprove on snapshot_manager.ads/adb"
          "Run gnatprove on transaction_log.ads/adb"
          "Document any unprovable contracts with justification")

         (contracts
          "Pre/Post conditions on all public subprograms"
          "Data flow contracts (Global, Depends)"
          "Type invariants on critical records"))

        (testing
         (unit-tests
          "Shell escape edge cases"
          "JSON parsing malformed input"
          "Transaction ID overflow"))))

      (deliverables
       ("src/security/shell_escape.ads"
        "src/security/shell_escape.adb"
        "Updated btrfs/zfs/lvm_snapshots with escaping"
        "gnatprove report for safety-critical modules"
        "tests/security/shell_escape_test.adb"))

      (blockers nil)
      (estimated-complexity . "medium"))

     ;; ========== 0.0.6 - INTEGRATION TESTING ==========
     ((version . "0.0.6")
      (name . "Integration Testing")
      (theme . "End-to-end verification of Ada↔Elixir communication")
      (target-completion . 72)

      (requirements
       ((ipc-testing
         (protocol-compliance
          "Test all IPC operations: begin_tx, add_op, commit_tx, fail_tx"
          "Test snapshot operations: create, list, get, delete"
          "Test package operations: store, get, list"
          "Verify JSON schema matches both sides")

         (error-paths
          "Elixir crashes mid-transaction"
          "Ada sends malformed JSON"
          "Pipe disconnection during operation"
          "Timeout handling"))

        (reversibility-chain
         (full-cycle
          "install → transaction → snapshot → verify → undo → verify"
          "Confirm system state restored exactly"
          "Verify transaction log records all operations")

         (edge-cases
          "Rollback during in-progress transaction"
          "Rollback when snapshot storage full"
          "Concurrent transaction attempts"))))

      (deliverables
       ("tests/integration/ipc_protocol_test.exs"
        "tests/integration/ada_elixir_e2e.adb"
        "tests/integration/reversibility_chain_test.adb"
        "CI workflow for integration tests"))

      (blockers ("0.0.5 security fixes must be complete"))
      (estimated-complexity . "high"))

     ;; ========== 0.0.7 - BACKEND COMPLETION ==========
     ((version . "0.0.7")
      (name . "Backend Completion")
      (theme . "Complete DNF and rpm-ostree backend implementations")
      (target-completion . 80)

      (requirements
       ((dnf-backend
         (core-operations
          "Implement Install_Package via dnf5 CLI"
          "Implement Remove_Package via dnf5 CLI"
          "Implement Upgrade_Package via dnf5 CLI"
          "Implement query operations (Search, Get_Info, List_Installed)")

         (transaction-support
          "Map DNF transactions to dnfinition transactions"
          "Handle partial transaction failures"
          "Implement Preview_* operations"))

        (rpm-ostree-backend
         (layered-packages
          "Implement Install (rpm-ostree install)"
          "Implement Remove (rpm-ostree uninstall)"
          "Implement Upgrade (rpm-ostree upgrade)")

         (native-rollback
          "Map rpm-ostree deployments to snapshots"
          "Implement rollback via rpm-ostree rollback"
          "Handle staged deployments"))

        (backend-detection
         (auto-select
          "Detect if running on Silverblue vs Workstation"
          "Choose rpm-ostree or dnf appropriately"
          "Allow user override"))))

      (deliverables
       ("src/backends/dnf/dnf_backend.adb - complete implementation"
        "src/backends/rpm_ostree/rpm_ostree_backend.adb - complete implementation"
        "tests/backends/dnf_backend_test.adb"
        "tests/backends/rpm_ostree_test.adb"))

      (blockers ("0.0.6 integration testing must validate IPC"))
      (estimated-complexity . "high"))

     ;; ========== 0.0.8 - FULL REVERSIBILITY ==========
     ((version . "0.0.8")
      (name . "Full Reversibility")
      (theme . "Complete the reversibility chain with verified rollback")
      (target-completion . 87)

      (requirements
       ((rollback-engine
         (implementation
          "Complete Rollback_To_Snapshot"
          "Complete Rollback_Transaction"
          "Complete Rollback_To_Time"
          "Implement Emergency_Rollback")

         (verification
          "SPARK proof of rollback correctness"
          "Verify_System_State implementation"
          "Can_Safely_Rollback implementation"))

        (snapshot-manager
         (lifecycle
          "Automatic snapshot creation before transactions"
          "Retention policy enforcement"
          "Space management and pruning")

         (filesystem-integration
          "btrfs snapshot creation and rollback"
          "zfs snapshot creation and rollback"
          "lvm snapshot creation and rollback"
          "Fallback for non-snapshot filesystems"))

        (transaction-log
         (persistence
          "Survive process crashes"
          "Survive system crashes (via Elixir/CubDB)"
          "Journal replay on startup"))))

      (deliverables
       ("src/reversibility/rollback_engine.adb - complete implementation"
        "src/reversibility/snapshot_manager.adb - complete implementation"
        "gnatprove report for rollback_engine"
        "tests/reversibility/rollback_scenarios.adb"))

      (blockers ("0.0.7 backends must be functional"))
      (estimated-complexity . "very-high"))

     ;; ========== 0.0.9 - DOWNLOAD INTEGRATION ==========
     ((version . "0.0.9")
      (name . "Download Integration")
      (theme . "Connect download manager with mirror optimizer")
      (target-completion . 92)

      (requirements
       ((mirror-optimizer
         (selection
          "Geographic proximity scoring"
          "Historical latency tracking"
          "Bandwidth estimation"
          "Failover logic"))

        (download-manager
         (pipeline
          "Use optimizer-selected mirrors"
          "Parallel chunk downloading"
          "Resume interrupted downloads"
          "Integrity verification (SHA256)"))

        (http-security
         (owasp-compliance
          "All OWASP security headers"
          "TLS 1.2+ only"
          "Certificate verification"
          "No MD5/SHA1 for integrity"))))

      (deliverables
       ("Integration of download/manager.ex with mirror/optimizer.ex"
        "Download resume capability"
        "Mirror failover tests"
        "HTTP security audit report"))

      (blockers ("0.0.8 reversibility for download rollback"))
      (estimated-complexity . "medium"))

     ;; ========== 0.1.0 - ALPHA RELEASE ==========
     ((version . "0.1.0")
      (name . "Alpha Release")
      (theme . "Feature-complete, ready for adventurous testing")
      (target-completion . 95)

      (requirements
       ((cli-completion
         (all-commands
          "install, remove, upgrade, downgrade"
          "search, info, list"
          "undo, history, snapshot"
          "config, clean, autoremove"))

        (documentation
         (user-docs
          "Installation guide"
          "Usage examples"
          "Undo/rollback guide")

         (developer-docs
          "Architecture overview"
          "Backend implementation guide"
          "IPC protocol specification"))

        (packaging
         (guix
          "guix.scm for building"
          "Guix package definition")
         (rpm
          "spec file for Fedora"))))

      (deliverables
       ("Complete CLI with help text"
        "README.adoc with examples"
        "ARCHITECTURE.adoc"
        "guix.scm"
        "packaging/dnfinition.spec"))

      (blockers ("0.0.9 all core features working"))
      (estimated-complexity . "medium"))

     ;; ========== 0.2.0 - BETA RELEASE ==========
     ((version . "0.2.0")
      (name . "Beta Release")
      (theme . "Stability and real-world testing")
      (target-completion . 97)

      (requirements
       ((stability
         (stress-testing
          "1000+ package operations"
          "Concurrent usage simulation"
          "Low disk space scenarios"
          "Memory pressure testing")

         (edge-cases
          "Network failures mid-download"
          "Filesystem full during snapshot"
          "Process killed mid-transaction"))

        (usability
         (error-messages
          "Clear, actionable error text"
          "Recovery suggestions"
          "Diagnostic information")

         (performance
          "Startup time < 500ms"
          "Transaction overhead < 5%"
          "Snapshot creation < 10s"))

        (community
         (feedback
          "Issue tracker setup"
          "Contributing guide"
          "Code of conduct"))))

      (deliverables
       ("Stress test suite"
        "Performance benchmarks"
        "CONTRIBUTING.adoc"
        "CODE_OF_CONDUCT.adoc"))

      (blockers ("0.1.0 feature complete"))
      (estimated-complexity . "medium"))

     ;; ========== 0.5.0 - RELEASE CANDIDATE ==========
     ((version . "0.5.0")
      (name . "Release Candidate")
      (theme . "Production-ready candidate")
      (target-completion . 99)

      (requirements
       ((final-verification
         (security-audit
          "Third-party code review"
          "Dependency audit"
          "CVE scan")

         (formal-proof
          "All SPARK_Mode modules proven"
          "No unproven assertions without justification")

         (compatibility
          "Fedora Workstation 40+"
          "Fedora Silverblue 40+"
          "RHEL 9+"))

        (release-prep
         (changelog
          "Complete CHANGELOG.md"
          "Migration guide from dnf")

         (ci-cd
          "Automated release workflow"
          "Copr/OBS packaging"))))

      (deliverables
       ("Security audit report"
        "Full gnatprove report"
        "CHANGELOG.md"
        "Release automation"))

      (blockers ("0.2.0 stability proven"))
      (estimated-complexity . "high"))

     ;; ========== 1.0.0 - PRODUCTION RELEASE ==========
     ((version . "1.0.0")
      (name . "Production Release")
      (theme . "Stable, verified, production-ready")
      (target-completion . 100)

      (requirements
       ((quality-gates
         (all-tests-pass . "100% test pass rate")
         (all-proofs-pass . "All SPARK proofs verified")
         (no-known-vulnerabilities . "No open CVEs")
         (performance-targets-met . "All benchmarks within targets")
         (documentation-complete . "All docs reviewed and published"))

        (guarantees
         (api-stability
          "Semantic versioning from 1.0.0 forward"
          "No breaking changes without major version bump")

         (support
          "Bug fixes for 1.x line"
          "Security patches backported"))))

      (deliverables
       ("Tagged release v1.0.0"
        "Published packages (Copr, Guix)"
        "Announcement"
        "Support policy document"))

      (blockers ("0.5.0 RC must be stable for 2+ weeks"))
      (estimated-complexity . "low")))

    ;; Risk assessment
    (risks
     ((high
       ("SPARK proofs may reveal design flaws requiring refactoring"
        "rpm-ostree integration complexity underestimated"
        "CubDB edge cases in crash recovery"))

      (medium
       ("DNF5 API instability"
        "Filesystem snapshot driver differences"
        "Performance targets may require optimization"))

      (low
       ("Documentation effort"
        "Packaging complexity"))))

    ;; Success metrics
    (success-criteria
     ((1.0.0-means
       "Can install/remove/upgrade packages on Fedora Workstation"
       "Can undo any operation within retention window"
       "Cannot brick system through normal usage"
       "All safety-critical code formally verified"
       "E2E tests pass reliably"
       "Documentation enables new users to start quickly")))))
