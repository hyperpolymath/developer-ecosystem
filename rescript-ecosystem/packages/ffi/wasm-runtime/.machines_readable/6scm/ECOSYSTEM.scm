;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem position for rescript-wasm-runtime
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "rescript-wasm-runtime")
  (type "runtime-library")
  (purpose "ReScript-first WebAssembly runtime layer providing type-safe bindings for loading, instantiating, and interacting with WASM modules")

  (position-in-ecosystem
    (category "WebAssembly")
    (subcategory "Runtime bindings")
    (unique-value
      "Type-safe ReScript API"
      "Zero-copy SharedArrayBuffer transfers"
      "DAG-based dependency analysis"
      "Multi-runtime support (Deno/Bun)"))

  (related-projects
    (sibling-standard
      (name "rhodium-standard-repositories")
      (relationship "Compliance standard for repository structure")
      (url "github.com/hyperpolymath/rhodium-standard-repositories"))
    (sibling-standard
      (name "affinescript")
      (relationship "Affine type system compiler that may target this runtime")
      (url "github.com/hyperpolymath/affinescript"))
    (potential-consumer
      (name "git-hud")
      (relationship "Git supervision tool that could use WASM for performance")
      (url "github.com/hyperpolymath/git-hud"))
    (potential-consumer
      (name "hackenbush-ssg")
      (relationship "Static site generator that could use WASM plugins")
      (url "github.com/hyperpolymath/hackenbush-ssg"))
    (inspiration
      (name "wasmer")
      (relationship "Reference for WASM runtime design patterns")
      (url "wasmer.io"))
    (inspiration
      (name "wasmtime")
      (relationship "Reference for safe WASM execution model")
      (url "wasmtime.dev")))

  (what-this-is
    "A ReScript-first WebAssembly runtime layer"
    "Type-safe bindings for WASM module loading and instantiation"
    "Zero-copy data transfer via SharedArrayBuffer"
    "DAG-based dependency analyzer for module graphs"
    "HTTP server framework with TEA architecture"
    "Support for Deno and Bun runtimes")

  (what-this-is-not
    "Not a full WebAssembly engine (use Wasmtime/WasmEdge for that)"
    "Not a JIT/AOT compiler project"
    "Not a WASI system or container runtime"
    "Not TypeScript-first (ReScript is the source of truth)"))
