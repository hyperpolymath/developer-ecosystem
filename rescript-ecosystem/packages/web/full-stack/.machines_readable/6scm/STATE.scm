; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2025 Hyperpolymath
;
; STATE.scm - Project state for rescript-full-stack
; Media-Type: application/vnd.hyperpolymath.state+scm

(state
  (metadata
    (version "1.0.0")
    (schema-version "1.0")
    (created "2025-01-04")
    (updated "2025-01-04")
    (project "rescript-full-stack")
    (repo "hyperpolymath/rescript-full-stack"))

  (project-context
    (name "ReScript Full Stack")
    (tagline "A complete map of the ReScript ecosystem across all stack layers")
    (tech-stack
      (primary "ReScript")
      (runtime "Deno")
      (wasm-backend "Rust")
      (mobile "Tauri 2.0")))

  (current-position
    (phase "active-development")
    (overall-completion 40)
    (components
      (presentation
        (status "complete")
        (items
          ("rescript-tea" "complete" "TEA architecture with layout and animation")
          ("@rescript/react" "community" "Official React bindings")
          ("cadre-tea-router" "complete" "TEA-integrated routing")))
      (state-data
        (status "partial")
        (items
          ("rescript-schema" "community" "Runtime validation - adopted")
          ("rescript-json" "community" "JSON encoding/decoding")
          ("rescript-env" "gap" "Environment config - needed")))
      (runtime
        (status "complete")
        (items
          ("rescript-wasm-runtime" "complete" "Deno/Bun with SharedMemory and DAG")))
      (persistence
        (status "in-development")
        (items
          ("rescript-postgres" "code-complete" "PostgreSQL client - FFI to postgres.js")
          ("rescript-redis" "gap" "Cache and pub/sub - needed")
          ("rescript-sqlite" "gap" "Embedded database - needed")))
      (network
        (status "partial")
        (items
          ("rescript-http" "included-in-wasm-runtime" "HTTP server via Deno.serve")
          ("rescript-websocket" "gap" "WebSocket client/server - needed")
          ("rescript-graphql" "community" "GraphQL via rescript-relay"))))
    (working-features
      ("TEA architecture with subscriptions")
      ("CSS Grid/Flexbox layout primitives")
      ("URL routing with query params and guards")
      ("SharedArrayBuffer zero-copy WASM transfer")
      ("DAG dependency analysis")))

  (route-to-mvp
    (milestones
      (p0-foundation
        (status "complete")
        (description "Minimum viable full-stack")
        (items
          ("@rescript/core - standard library" #t)
          ("@rescript/react - React bindings" #t)
          ("rescript-tea - TEA architecture" #t)
          ("cadre-tea-router - routing" #t)
          ("rescript-wasm-runtime - server runtime" #t)))
      (p1-data-layer
        (status "in-progress")
        (description "Essential for real applications")
        (items
          ("rescript-postgres - PostgreSQL client" #f)
          ("rescript-schema - runtime validation" #t)
          ("rescript-env - environment config" #f)
          ("rescript-jwt - JWT handling" #f)))))

  (blockers-and-issues
    (critical ())
    (high-priority
      (("rescript-postgres completion" "Unlocks all database-backed apps"))))

  (critical-next-actions
    (immediate
      ("Complete rescript-postgres FFI bindings"))))
