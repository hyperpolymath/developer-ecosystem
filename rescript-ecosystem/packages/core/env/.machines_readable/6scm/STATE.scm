;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for rescript-env
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2025-01-04")
    (updated "2025-01-04")
    (project "rescript-env")
    (repo "github.com/hyperpolymath/rescript-env"))

  (project-context
    (name "rescript-env")
    (tagline "Type-safe environment variable access for ReScript")
    (tech-stack ("ReScript" "Deno" "@rescript/core")))

  (current-position
    (phase "implementation")
    (overall-completion 70)
    (components
      ((name "Core API")
       (status "complete")
       (files ("src/Env.res" "src/Env.resi")))
      ((name "Documentation")
       (status "complete")
       (files ("README.adoc" "ROADMAP.adoc" "CHANGELOG.adoc")))
      ((name "Testing")
       (status "planned")
       (files ()))
      ((name "JSR Publishing")
       (status "pending")
       (files ())))
    (working-features
      ("get/getOr/getExn"
       "getInt/getFloat/getBool"
       "set/delete/has/all"
       "isDevelopment/isProduction/isTest"
       "Deno runtime detection"
       "Node.js runtime detection")))

  (route-to-mvp
    (milestones
      ((name "v0.1.0 - Initial Release")
       (status "complete")
       (features ("Core API" "Runtime detection" "Type coercion")))
      ((name "v0.2.0 - Schema Validation")
       (status "planned")
       (features ("Schema definition" ".env loading" "Prefix namespacing")))
      ((name "v1.0.0 - Stable")
       (status "future")
       (features ("Full test coverage" "Security audit" "JSR publish")))))

  (blockers-and-issues
    (critical)
    (high)
    (medium
      ("Need comprehensive test suite"
       "JSR publication pending"))
    (low
      ("npm publication decision needed")))

  (critical-next-actions
    (immediate
      ("Add unit tests for all API functions"))
    (this-week
      ("Publish to JSR"
       "Create example project"))
    (this-month
      ("Implement schema validation"
       "Add .env file loading")))

  (session-history
    ((date "2025-01-04")
     (summary "Initial implementation with full API")
     (changes ("Created Env.res with runtime detection"
               "Added type coercion functions"
               "Added environment helpers"
               "Created documentation")))))
