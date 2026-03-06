;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for rescript-websocket
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2025-01-01")
    (updated "2025-01-04")
    (project "rescript-websocket")
    (repo "github.com/hyperpolymath/rescript-websocket"))

  (project-context
    (name "rescript-websocket")
    (tagline "Type-safe WebSocket client and server for ReScript")
    (tech-stack ("ReScript" "Deno" "WebSocket")))

  (current-position
    (phase "initial-release")
    (overall-completion 60)
    (components
      (("client" . 100)
       ("server" . 100)
       ("broadcast" . 100)
       ("tests" . 0)
       ("docs" . 80)))
    (working-features
      ("WebSocket client connection"
       "Event handlers (open, close, message, error)"
       "Text and binary message sending"
       "JSON message helper"
       "Ready state checking"
       "Promise-based waitForOpen"
       "Server-side WebSocket upgrade"
       "Deno.serve integration"
       "Multi-client broadcast")))

  (route-to-mvp
    (milestones
      (("v0.1.0" . "Core client and server bindings")
       ("v0.2.0" . "Room/channel abstraction")
       ("v0.3.0" . "Protocol support")
       ("v1.0.0" . "Stable release"))))

  (blockers-and-issues
    (critical)
    (high)
    (medium
      ("Test suite not yet implemented"))
    (low
      ("JSR publication pending")))

  (critical-next-actions
    (immediate
      ("Write basic test suite"))
    (this-week
      ("Publish to JSR"))
    (this-month
      ("Add room/channel abstraction")))

  (session-history
    (("2025-01-04" . "Initial implementation complete"))))
