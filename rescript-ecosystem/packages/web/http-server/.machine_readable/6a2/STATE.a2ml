;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for rescript-http-server
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2025-01-04")
    (updated "2025-01-04")
    (project "rescript-http-server")
    (repo "github.com/hyperpolymath/rescript-http-server"))

  (project-context
    (name "rescript-http-server")
    (tagline "Type-safe HTTP server bindings for ReScript using Deno.serve")
    (tech-stack
      ("ReScript" "11+")
      ("Deno" "1.40+")
      ("@rescript/core" "latest")))

  (current-position
    (phase "alpha")
    (overall-completion 40)
    (components
      (("HttpServer.res" . "complete")
       ("HttpServer.resi" . "complete")
       ("deno-bindings" . "complete")
       ("routing" . "complete")
       ("middleware" . "complete")
       ("tests" . "not-started")
       ("path-params" . "not-started")))
    (working-features
      ("Deno.serve FFI bindings")
      ("Request method/path/headers/body access")
      ("Response builders (text, JSON, HTML)")
      ("Error responses (400, 401, 403, 404, 500)")
      ("Redirects")
      ("Pattern-based routing with wildcards")
      ("Middleware composition")
      ("CORS middleware")
      ("Logging middleware")))

  (route-to-mvp
    (milestones
      (("v0.1.0" . "Foundation - complete")
       ("v0.2.0" . "Enhanced routing - path params, groups")
       ("v0.3.0" . "Advanced middleware - rate limiting, compression")
       ("v0.4.0" . "Body handling - multipart, streaming")
       ("v0.5.0" . "Security - CSRF, JWT, auth")
       ("v1.0.0" . "Production ready - tests, benchmarks, docs"))))

  (blockers-and-issues
    (critical)
    (high)
    (medium
      ("Path parameter extraction not implemented")
      ("No test suite"))
    (low
      ("No multipart form parsing")
      ("No streaming support")))

  (critical-next-actions
    (immediate
      ("Add path parameter extraction"))
    (this-week
      ("Create test suite")
      ("Add rate limiting middleware"))
    (this-month
      ("Implement body size limits")
      ("Add compression middleware")))

  (session-history
    (("2025-01-04" . "Initial implementation with core HTTP server functionality"))))
