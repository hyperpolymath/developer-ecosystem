; SPDX-License-Identifier: PMPL-1.0-or-later
; ECOSYSTEM.scm - Project position in the ReScript ecosystem

(ecosystem
  (version . "1.0")
  (name . "rescript-runtime-tools")
  (type . "developer-tooling")
  (purpose . "Runtime-aware build/dev/test CLI for ReScript projects targeting Deno/Bun")

  (position-in-ecosystem
    (layer . "runtime")
    (role . "tooling")
    (complements . ("rescript-wasm-runtime" "rescript-full-stack"))
    (consumed-by . ("rescript-full-stack" "rescript-wasm-runtime" "rescribe-ssg")))

  (related-projects
    ((name . "rescript-wasm-runtime")
     (relationship . sibling-standard)
     (notes . "Runtime bindings - this tool provides the DX layer on top"))

    ((name . "rescript-full-stack")
     (relationship . parent-ecosystem)
     (notes . "This tool is part of the full-stack ReScript architecture"))

    ((name . "rescript-tea")
     (relationship . potential-consumer)
     (notes . "TEA apps can use rrt for dev/build"))

    ((name . "rescribe-ssg")
     (relationship . potential-consumer)
     (notes . "SSG can use rrt for build orchestration"))

    ((name . "deno")
     (relationship . runtime-dependency)
     (notes . "Primary runtime target"))

    ((name . "bun")
     (relationship . runtime-dependency)
     (notes . "Secondary runtime target")))

  (what-this-is
    "Unified CLI for ReScript development on modern runtimes"
    "Zero-npm tooling using Deno's npm: specifier"
    "Runtime detection and capability checking"
    "Build orchestration without node_modules")

  (what-this-is-not
    "Not a bundler (uses runtime-native bundling)"
    "Not a package manager (uses Deno cache)"
    "Not Node.js compatible (by design)"))
