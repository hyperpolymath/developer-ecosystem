;; SPDX-License-Identifier: PMPL-1.0-or-later
;; META.scm - Meta-level information for rescript-wasm-runtime
;; Media-Type: application/meta+scheme

(meta
  (architecture-decisions
    (adr-001
      (title "ReScript as primary language")
      (status "accepted")
      (date "2025-01-03")
      (context "Need type-safe language that compiles to JS for WASM runtime bindings")
      (decision "Use ReScript instead of TypeScript for type safety and functional patterns")
      (consequences "Better type inference, smaller output, but smaller community"))
    (adr-002
      (title "Deno as primary runtime")
      (status "accepted")
      (date "2025-01-03")
      (context "Need modern JS runtime with good WASM support")
      (decision "Use Deno as primary runtime, Bun as secondary")
      (consequences "Better security model, native TypeScript, but less npm compatibility"))
    (adr-003
      (title "Zero-copy SharedArrayBuffer for WASM interop")
      (status "accepted")
      (date "2025-01-03")
      (context "Need high-performance data transfer between JS and WASM")
      (decision "Use SharedArrayBuffer with Atomics for thread-safe zero-copy transfers")
      (consequences "Requires cross-origin isolation, but eliminates serialization overhead"))
    (adr-004
      (title "DAG-based dependency analysis")
      (status "accepted")
      (date "2025-01-03")
      (context "Need to analyze module dependencies and detect cycles")
      (decision "Implement full DAG with cycle detection, topological sort, and elimination scoring")
      (consequences "More complex implementation but enables sophisticated dependency management")))

  (development-practices
    (code-style
      (language "ReScript")
      (format "rescript format")
      (module-format "ES6")
      (suffix ".mjs")
      (open-belt true))
    (security
      (principle "Defense in depth")
      (wasm-sandboxing "Explicit imports only")
      (memory-isolation "SharedArrayBuffer with Atomics"))
    (testing
      (framework "Deno test")
      (coverage "deno coverage")
      (unit-tests "tests/unit/")
      (integration-tests "tests/integration/"))
    (versioning "SemVer")
    (documentation "AsciiDoc preferred")
    (branching "main for stable"))

  (design-rationale
    (why-rescript "Type safety without TypeScript complexity, smaller bundle output")
    (why-deno "Security-first runtime, native WASM support, no node_modules")
    (why-shared-memory "Avoid serialization overhead for large data transfers")
    (why-dag "Enable cycle detection and smart elimination of redundant dependencies")
    (why-tea "The Elm Architecture provides predictable state management")))
