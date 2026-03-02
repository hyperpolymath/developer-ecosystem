;; SPDX-License-Identifier: PMPL-1.0-or-later
;; rescript-openapi ecosystem position

(ecosystem
  (version "1.0")
  (name "rescript-openapi")
  (type "cli-tool")
  (purpose "Generate type-safe ReScript API clients from OpenAPI specifications")

  (position-in-ecosystem
    (layer "network-api")
    (category "code-generation")
    (role "Bridges OpenAPI ecosystem to ReScript")
    (hub "github.com/hyperpolymath/rescript-full-stack"))

  (related-projects
    (sibling-standard
      (name "rescript-full-stack")
      (relationship "Part of the ReScript full-stack ecosystem")
      (integration "Generated clients work with rescript-tea, rescript-wasm-runtime"))

    (sibling-standard
      (name "rescript-schema")
      (relationship "Runtime dependency for validation")
      (integration "Generated Schema.res uses rescript-schema for JSON parsing"))

    (potential-consumer
      (name "Any ReScript project")
      (relationship "Consumer of generated clients")
      (integration "Import generated ApiClient module"))

    (inspiration
      (name "openapi-typescript")
      (relationship "TypeScript equivalent")
      (notes "Similar goals, different target language"))

    (inspiration
      (name "orval")
      (relationship "TypeScript client generator")
      (notes "Mutator pattern influenced HTTP abstraction design"))

    (inspiration
      (name "progenitor")
      (relationship "Rust OpenAPI generator")
      (notes "Rust codegen patterns")))

  (what-this-is
    "A Rust CLI that reads OpenAPI 3.x specs"
    "Generates idiomatic ReScript types, validators, and HTTP clients"
    "Enables type-safe API consumption in ReScript projects"
    "Part of the hyperpolymath ReScript ecosystem")

  (what-this-is-not
    "Not a server stub generator"
    "Not a schema-first API design tool"
    "Not a runtime library (generates code, doesn't ship runtime)"))
