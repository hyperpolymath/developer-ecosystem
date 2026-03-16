;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem position for rescript-poly-core
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "rescript-poly-core")
  (type "library")
  (purpose "Foundation library providing shared utilities and MCP infrastructure for the Hyperpolymath ReScript ecosystem")

  (position-in-ecosystem
    (category "foundation")
    (subcategory "core-library")
    (unique-value
      ("type-safe-result-handling"
       "async-utilities-with-retry"
       "structured-json-logging"
       "mcp-server-infrastructure"
       "zero-external-dependencies")))

  (related-projects
    (upstream
      (("@rescript/core" . "ReScript standard library")))
    (downstream
      (("poly-mcps" . "MCP servers built with rescript-poly-core")
       ("poly-clients" . "API clients using rescript-poly-core patterns")
       ("poly-apps" . "Applications using rescript-poly-core")))
    (siblings
      (("rescript-full-stack" . "Ecosystem documentation and overview"))))

  (what-this-is
    ("Shared foundation library for ReScript projects"
     "Common patterns for error handling and async"
     "Structured logging infrastructure"
     "Configuration management utilities"
     "MCP server building blocks"
     "Consistent API across poly-* projects"))

  (what-this-is-not
    ("Not a web framework"
     "Not a UI component library"
     "Not a database ORM"
     "Not an authentication system"
     "Not application-specific code")))
