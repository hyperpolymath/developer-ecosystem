; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2025 Hyperpolymath
;
; NEUROSYM.scm - Neurosymbolic configuration for AI reasoning
; Media-Type: application/vnd.hyperpolymath.neurosym+scm

(neurosym
  (version "1.0.0")
  (project "rescript-full-stack")

  (semantic-model
    (domain "full-stack-web-development")
    (primary-concepts
      ("ReScript type system")
      ("TEA architecture pattern")
      ("WASM interop via SharedArrayBuffer")
      ("Deno runtime security model")
      ("Component composition patterns"))

    (relationships
      (rescript-tea -> cadre-tea-router "integrates-with")
      (cadre-tea-router -> rescript-tea "extends")
      (rescript-wasm-runtime -> wasm-modules "hosts")
      (rescript-wasm-runtime -> deno "runs-on")
      (rescript-postgres -> rescript-schema "validates-with")))

  (reasoning-patterns
    (component-selection
      (rule "When user needs frontend state management"
            (recommend "rescript-tea")
            (rationale "TEA provides functional state management"))
      (rule "When user needs URL routing"
            (recommend "cadre-tea-router")
            (requires "rescript-tea"))
      (rule "When user needs server runtime"
            (recommend "rescript-wasm-runtime")
            (alternative "standalone Deno.serve"))
      (rule "When user needs database access"
            (recommend "rescript-postgres")
            (status "in-development")))

    (anti-patterns
      (avoid "TypeScript" (reason "Unsound types, prefer ReScript"))
      (avoid "Node.js" (reason "Security model inferior to Deno"))
      (avoid "Redux" (reason "TEA provides better ReScript integration"))
      (avoid "npm" (reason "Use Deno imports or jsr"))))

  (knowledge-graph
    (entities
      (rescript (type language) (paradigm functional))
      (deno (type runtime) (security explicit-permissions))
      (wasm (type compute-target) (performance near-native))
      (tea (type architecture) (pattern model-update-view))
      (postgres (type database) (category relational)))

    (properties
      (rescript compiles-to javascript)
      (rescript has-sound-types #t)
      (deno supports typescript-native)
      (deno has-permissions-api #t)
      (tea enables predictable-updates)
      (wasm enables portable-compute)))

  (inference-rules
    (rule full-stack-pattern
      (if (and (needs frontend) (needs backend) (needs database)))
      (then (use rescript-tea) (use rescript-wasm-runtime) (use rescript-postgres)))

    (rule realtime-pattern
      (if (needs realtime-updates))
      (then (use rescript-websocket) (use rescript-sse))
      (note "rescript-websocket is a gap - needs implementation"))

    (rule mobile-pattern
      (if (needs mobile-app))
      (then (use rescript-tauri))
      (note "rescript-tauri is a gap - needs implementation")))

  (symbolic-constraints
    (type-safety
      (constraint "All API boundaries must use rescript-schema validation")
      (constraint "All FFI bindings must have .resi interface files")
      (constraint "No any types or unchecked casts"))

    (security
      (constraint "Deno permissions must be explicit")
      (constraint "No eval or dynamic code execution")
      (constraint "All secrets via environment variables"))

    (performance
      (constraint "Large data transfer via SharedArrayBuffer")
      (constraint "Compute-heavy operations via WASM")
      (constraint "Lazy loading for large modules"))))
