;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem position for ada-loom-registry (Spindle)
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "spindle")
  (type "library-and-cli")
  (purpose "Parse Nickel configuration files into type-safe Haskell data structures")

  (position-in-ecosystem
    (category "configuration-management")
    (subcategory "nickel-tooling")
    (unique-value
      ("Type-safe Nickel to Haskell bridge")
      ("GHC WASM support for browser deployment")
      ("Registry for validated configurations")))

  (related-projects
    (project
      (name "scaffoldia")
      (relationship "potential-merge")
      (description "Haskell scaffolding tool that could use Spindle for Nickel configs")
      (integration "Spindle could become scaffoldia's Nickel module"))
    (project
      (name "valence")
      (relationship "potential-consumer")
      (description "Elixir web framework")
      (integration "Could use Spindle for Nickel configuration parsing"))
    (project
      (name "hnickel")
      (relationship "dependency")
      (description "Haskell bindings for Nickel language")
      (integration "Core parsing functionality"))
    (project
      (name "nickel-lang")
      (relationship "upstream")
      (description "The Nickel configuration language")
      (integration "Source language for configuration files")))

  (what-this-is
    ("Haskell library for parsing Nickel files")
    ("CLI tool for validating and managing Nickel configs")
    ("Registry for tracking validated configurations")
    ("Bridge between Nickel's type contracts and Haskell's type system"))

  (what-this-is-not
    ("NOT an Ada project (despite repository name)")
    ("NOT a textile/loom project")
    ("NOT a general package registry")
    ("NOT a replacement for Nickel itself")))
