;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for rescript-poly-core
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2025-01-04")
    (updated "2025-01-04")
    (project "rescript-poly-core")
    (repo "github.com/hyperpolymath/rescript-poly-core"))

  (project-context
    (name "rescript-poly-core")
    (tagline "Shared foundation library for the Hyperpolymath ReScript ecosystem")
    (tech-stack
      ("rescript" "deno" "mcp")))

  (current-position
    (phase "alpha")
    (overall-completion 40)
    (components
      (("Core.Result" 100 "Extended Result utilities")
       ("Core.Async" 100 "Promise/async utilities")
       ("Core.Logger" 100 "Structured JSON logging")
       ("Core.Config" 100 "Configuration loading")
       ("MCP.Protocol" 100 "MCP types and builders")
       ("MCP.Server" 90 "MCP server infrastructure")))
    (working-features
      ("result-chaining"
       "async-retry"
       "structured-logging"
       "env-config"
       "mcp-tool-registration"
       "mcp-request-handling")))

  (route-to-mvp
    (milestones
      (("v0.1.0" "Foundation" 90
        ("Core modules" "MCP infrastructure" "Basic docs"))
       ("v0.2.0" "Testing" 0
        ("Unit tests" "Integration tests" "CI pipeline"))
       ("v0.3.0" "Ecosystem Integration" 0
        ("JSR publishing" "poly-mcps integration" "Examples"))
       ("v1.0.0" "Stable Release" 0
        ("API stability" "Full documentation" "Production ready")))))

  (blockers-and-issues
    (critical)
    (high
      ("Need unit test coverage"))
    (medium
      ("Need JSR publishing workflow")
      ("Need example MCP server"))
    (low
      ("Consider adding Core.JSON module")
      ("Consider adding Core.Http module")))

  (critical-next-actions
    (immediate
      ("Add unit tests for Core modules")
      ("Set up Deno test runner"))
    (this-week
      ("Publish to JSR")
      ("Add example MCP server"))
    (this-month
      ("Integrate with poly-mcps")
      ("Add Core.Http module")))

  (session-history
    (("2025-01-04" "initial-implementation"
      "Created core modules and MCP infrastructure"))))
