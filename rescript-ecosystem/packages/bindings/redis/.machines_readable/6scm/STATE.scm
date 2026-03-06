;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for rescript-redis
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2025-01-04")
    (updated "2025-01-04")
    (project "rescript-redis")
    (repo "github.com/hyperpolymath/rescript-redis"))

  (project-context
    (name "rescript-redis")
    (tagline "Type-safe Redis client for ReScript using Deno")
    (tech-stack
      ("rescript" "deno" "redis")))

  (current-position
    (phase "development")
    (overall-completion 70)
    (components
      (core-bindings 100)
      (streams 100)
      (sentinel 100)
      (cluster 100)
      (tests 0)
      (documentation 80))
    (working-features
      ("string-operations")
      ("hash-operations")
      ("list-operations")
      ("set-operations")
      ("sorted-set-operations")
      ("pub-sub")
      ("streams")
      ("consumer-groups")
      ("sentinel-support")
      ("cluster-support")
      ("json-helpers")))

  (route-to-mvp
    (milestones
      (v0.1.0
        (status "in-progress")
        (remaining
          ("basic-test-suite")
          ("jsr-publishing")))))

  (blockers-and-issues
    (critical)
    (high)
    (medium
      ("need-test-coverage"))
    (low))

  (critical-next-actions
    (immediate
      ("add-basic-tests")
      ("verify-compilation"))
    (this-week
      ("publish-to-jsr"))
    (this-month
      ("add-transactions")
      ("add-pipelining")))

  (session-history
    ((date "2025-01-04")
     (actions
       ("created-redis-bindings")
       ("added-streams-module")
       ("added-sentinel-module")
       ("added-cluster-module")
       ("created-documentation")))))
