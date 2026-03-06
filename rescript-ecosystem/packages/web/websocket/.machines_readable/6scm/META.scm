;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information for rescript-websocket
;; Media-Type: application/meta+scheme

(meta
  (architecture-decisions
    (("Zero-cost FFI" . "Direct bindings to WebSocket API with no wrapper overhead")
     ("Type-safe ready states" . "Enum for connection states instead of magic numbers")
     ("Deno-first" . "Designed for Deno runtime, not Node.js")
     ("Pipe-first API" . "Functions designed for -> operator")))

  (development-practices
    (code-style
      ("@@uncurried for all modules"
       "Pipe-first syntax preferred"
       "Doc comments on public API"))
    (security
      (principle "Secure by default")
      (notes "WSS preferred, no credential storage"))
    (testing
      ("Deno test runner"
       "Integration tests with real WebSocket"))
    (versioning "SemVer")
    (documentation "AsciiDoc")
    (branching "main for stable"))

  (design-rationale
    (("External bindings" . "Use @external for direct JS interop")
     ("Callback-based events" . "Match WebSocket API semantics")
     ("Optional server" . "Client works standalone without server module"))))
