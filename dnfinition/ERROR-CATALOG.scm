;; SPDX-License-Identifier: MPL-2.0-or-later
;; SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
;; ERROR-CATALOG.scm - Machine-readable catalog of common repo security errors
;; Format: Guile Scheme (homoiconic, parseable by robot-repo-cleaner)
;; Updated: 2025-12-15

(define error-catalog
  '((metadata
     (format-version . "1.0")
     (schema-version . "2025-12-15")
     (purpose . "Learning rules for propagating fixes across repositories")
     (generator . "robot-repo-bot/Claude analysis"))

    ;;=========================================================================
    ;; ERROR CATEGORY: DUPLICATE WORKFLOWS
    ;;=========================================================================
    (error-type
     (id . "ERR-WF-001")
     (name . "duplicate-codeql-workflows")
     (severity . "high")
     (category . "workflow-duplication")
     (description . "Repository has both codeql.yml AND codeql-analysis.yml")

     (detection
      (method . "file-existence")
      (files . (".github/workflows/codeql.yml" ".github/workflows/codeql-analysis.yml"))
      (condition . "both-exist"))

     (affected-repos
      ("ada-loom-registry" "affinescript" "asdfghj" "blue-screen-of-app"
       "checky-monkey" "conative-gating" "disinfo-nsai-detector" "esn"
       "fslint-plugin-api" "fslint-plugin-sdk" "git-eco-bot" "grimrepo-scripts"
       "hackenbush-ssg" "idaptik" "indieweb2-bastion" "kith" "llm-unify-core"
       "llm-verify" "lol" "lsm" "modshells" "php-aegis" "poly-container-mcp"
       "poly-db-mcp" "polyglot-i18n" "poly-iac-mcp" "poly-observability-mcp"
       "poly-queue-mcp" "poly-secret-mcp" "poly-ssg-mcp" "proof-of-work"
       "rhodium-standard-repositories-fix" "robot-repo-bot" "sanctify-php"
       "scaffoldia" "supernorma" "synapse-release" "thejeffparadox"
       "tree-navigator" "ubicity" "union-policy-parsers" "wordpress-wharf"
       "wp-audit-toolkit"))

     (fix
      (action . "delete")
      (target . ".github/workflows/codeql-analysis.yml")
      (reason . "codeql.yml is the canonical file with build-mode support"))

     (commit-message . "chore: remove duplicate codeql-analysis.yml workflow"))

    ;;=========================================================================
    ;; ERROR CATEGORY: CODEQL LANGUAGE MISMATCH
    ;;=========================================================================
    (error-type
     (id . "ERR-WF-002")
     (name . "codeql-language-mismatch")
     (severity . "medium")
     (category . "workflow-misconfiguration")
     (description . "CodeQL configured to scan languages not present in repository")

     (detection
      (method . "language-detection")
      (check . "compare workflow matrix.language against repo file extensions")
      (extension-map
       ((".js" ".jsx" ".ts" ".tsx" ".mjs") . "javascript-typescript")
       ((".py") . "python")
       ((".go") . "go")
       ((".java" ".kt") . "java-kotlin")
       ((".rb") . "ruby")
       ((".rs") . "rust")
       ((".cs") . "csharp")
       ((".cpp" ".c" ".h" ".hpp") . "cpp")
       ((".swift") . "swift")))

     (examples
      ((repo . "robot-repo-bot")
       (configured . ("javascript" "python" "go" "java" "ruby"))
       (actual . ())
       (issue . "No source code files exist"))
      ((repo . "bunsenite")
       (configured . ("go" "python" "javascript-typescript"))
       (actual . ("rust"))
       (issue . "Only Rust exists, should only scan rust")))

     (fix
      (action . "modify")
      (target . ".github/workflows/codeql.yml")
      (modification . "update matrix.language to match detected languages")
      (fallback . "disable workflow if no scannable languages"))

     (commit-message . "fix: align CodeQL language matrix with repo contents"))

    ;;=========================================================================
    ;; ERROR CATEGORY: BROKEN COMPREHENSIVE-QUALITY
    ;;=========================================================================
    (error-type
     (id . "ERR-WF-003")
     (name . "comprehensive-quality-broken")
     (severity . "medium")
     (category . "workflow-misconfiguration")
     (description . "comprehensive-quality.yml references services/tools not configured")

     (detection
      (method . "file-existence")
      (files . (".github/workflows/comprehensive-quality.yml")))

     (affected-repos
      ("ada-loom-registry" "asdfghj" "blue-screen-of-app" "bunsenite"
       "checky-monkey" "conative-gating" "czech-file-knife" "disinfo-nsai-detector"
       "esn" "fslint-plugin-api" "fslint-plugin-sdk" "git-eco-bot" "grimrepo-scripts"
       "hackenbush-ssg" "idaptik" "indieweb2-bastion" "januskey" "kith"
       "llm-unify-core" "llm-verify" "lol" "lsm" "modshells" "php-aegis"
       "poly-container-mcp" "poly-db-mcp" "polyglot-i18n" "poly-iac-mcp"
       "poly-observability-mcp" "poly-queue-mcp" "poly-secret-mcp" "poly-ssg-mcp"
       "proof-of-work" "rhodium-standard-repositories" "rhodium-standard-repositories-fix"
       "robot-repo-bot" "robot-vacuum-cleaner" "sanctify-php" "scaffoldia"
       "supernorma" "synapse-release" "thejeffparadox" "tree-navigator" "ubicity"
       "union-policy-parsers" "wordpress-wharf" "wp-audit-toolkit"))

     (fix
      (action . "delete")
      (target . ".github/workflows/comprehensive-quality.yml")
      (reason . "Consistently fails due to missing configuration"))

     (commit-message . "chore: remove broken comprehensive-quality.yml workflow"))

    ;;=========================================================================
    ;; ERROR CATEGORY: MIRROR WITHOUT SECRETS
    ;;=========================================================================
    (error-type
     (id . "ERR-WF-004")
     (name . "mirror-missing-secrets")
     (severity . "low")
     (category . "workflow-secrets")
     (description . "mirror.yml references secrets not configured at org/repo level")

     (detection
      (method . "secret-reference")
      (required-secrets . ("GITLAB_TOKEN" "BITBUCKET_TOKEN"))
      (required-vars . ("GITLAB_MIRROR_ENABLED" "BITBUCKET_MIRROR_ENABLED"))
      (note . "Workflow has conditionals but still shows as failed in UI"))

     (affected-repos . 59)  ; Count from scan

     (fix-options
      ((option . "configure-secrets")
       (description . "Set up org-level secrets for mirroring")
       (steps
        ("GitHub Settings > Secrets > Actions > Organization secrets"
         "Add GITLAB_TOKEN with GitLab PAT"
         "Add BITBUCKET_TOKEN with Bitbucket App Password"
         "Set vars: GITLAB_MIRROR_ENABLED=true, BITBUCKET_MIRROR_ENABLED=true")))

      ((option . "remove-workflow")
       (description . "Delete mirror.yml if mirroring not needed")
       (action . "delete")
       (target . ".github/workflows/mirror.yml"))))

    ;;=========================================================================
    ;; ERROR CATEGORY: DATADOG WITHOUT CONFIG
    ;;=========================================================================
    (error-type
     (id . "ERR-WF-005")
     (name . "datadog-without-config")
     (severity . "medium")
     (category . "workflow-secrets")
     (description . "datadog-synthetics.yml runs without DATADOG_API_KEY/APP_KEY")

     (detection
      (method . "file-existence")
      (files . (".github/workflows/datadog-synthetics.yml"))
      (required-secrets . ("DATADOG_API_KEY" "DATADOG_APP_KEY")))

     (affected-repos . ("llm-verify"))

     (fix
      (action . "delete")
      (target . ".github/workflows/datadog-synthetics.yml")
      (reason . "Datadog not configured for these repos"))

     (commit-message . "chore: remove unconfigured Datadog workflow"))

    ;;=========================================================================
    ;; ERROR CATEGORY: EXCESSIVE WORKFLOWS
    ;;=========================================================================
    (error-type
     (id . "ERR-WF-006")
     (name . "excessive-workflow-count")
     (severity . "note")
     (category . "workflow-hygiene")
     (description . "Repository has 15+ workflows, many likely inapplicable")

     (detection
      (method . "file-count")
      (threshold . 15)
      (path . ".github/workflows/"))

     (examples
      ((repo . "llm-verify")
       (count . 33)
       (note . "Many language-specific workflows for unused languages")))

     (recommendation . "Audit workflows and remove those not applicable to repo"))

    ;;=========================================================================
    ;; ERROR CATEGORY: MISSING SHA PINS (Remediated 2025-12-13)
    ;;=========================================================================
    (error-type
     (id . "ERR-SEC-001")
     (name . "unpinned-actions")
     (severity . "high")
     (category . "security")
     (description . "GitHub Actions using version tags instead of SHA pins")
     (status . "fixed")

     (detection
      (method . "regex")
      (pattern . "uses:\\s+[\\w-]+/[\\w-]+@v[0-9]")
      (negative-pattern . "uses:\\s+[\\w-]+/[\\w-]+@[a-f0-9]{40}"))

     (fix
      (action . "modify")
      (modification . "Replace version tags with full SHA hashes")
      (example
       (before . "uses: actions/checkout@v4")
       (after . "uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1")))

     (openssf-scorecard-check . "Pinned-Dependencies"))

    ;;=========================================================================
    ;; ERROR CATEGORY: MISSING PERMISSIONS
    ;;=========================================================================
    (error-type
     (id . "ERR-SEC-002")
     (name . "missing-permissions")
     (severity . "high")
     (category . "security")
     (description . "Workflow missing top-level permissions declaration")
     (status . "fixed")

     (detection
      (method . "yaml-parse")
      (check . "workflow lacks 'permissions:' at top level"))

     (fix
      (action . "modify")
      (modification . "Add 'permissions: read-all' at workflow level")
      (example . "permissions: read-all"))

     (openssf-scorecard-check . "Token-Permissions"))

    ;;=========================================================================
    ;; ERROR CATEGORY: MISSING SPDX HEADER
    ;;=========================================================================
    (error-type
     (id . "ERR-LIC-001")
     (name . "missing-spdx-header")
     (severity . "low")
     (category . "licensing")
     (description . "Workflow file missing SPDX license identifier")
     (status . "fixed")

     (detection
      (method . "regex")
      (pattern . "^# SPDX-License-Identifier:")
      (file-types . (".yml" ".yaml" ".jl" ".rs" ".ex" ".exs")))

     (fix
      (action . "modify")
      (modification . "Add SPDX header as first line")
      (template . "# SPDX-License-Identifier: AGPL-3.0-or-later")))

    ;;=========================================================================
    ;; PROPAGATION RULES
    ;;=========================================================================
    (propagation
     (methods
      ((method . "robot-repo-cleaner")
       (description . "Julia script that applies fixes across all repos")
       (script . "~/fix-github-workflows.sh"))

      ((method . "pre-commit-hook")
       (description . "Validate workflows before commit")
       (location . ".github/hooks/validate-workflows.yml"))

      ((method . "ci-check")
       (description . "GitHub Action that validates workflow hygiene")
       (workflow . ".github/workflows/workflow-linter.yml"))

      ((method . "claude-md-rules")
       (description . "Rules embedded in CLAUDE.md for AI assistants")
       (location . ".claude/CLAUDE.md")))

     (priority-order
      ("ERR-SEC-001" "ERR-SEC-002" "ERR-WF-001" "ERR-WF-002"
       "ERR-WF-003" "ERR-WF-005" "ERR-WF-004" "ERR-LIC-001")))

    ;;=========================================================================
    ;; STATISTICS (as of 2025-12-15)
    ;;=========================================================================
    (statistics
     (total-repos-scanned . 85)
     (repos-with-workflows . 72)
     (issues-found
      (duplicate-codeql . 43)
      (comprehensive-quality . 47)
      (mirror-yml . 59)
      (codeql-language-mismatch . "~40 estimated"))
     (fixed-previously
      (sha-pins . "~114 workflows")
      (permissions . "~114 workflows")
      (spdx-headers . "~114 workflows")))))

;; End of ERROR-CATALOG.scm
