; SPDX-License-Identifier: PMPL-1.0-or-later
; META.scm - Architecture decisions and development practices

(define meta
  '((architecture-decisions

      ((id . "adr-001")
       (title . "Zero npm philosophy")
       (status . accepted)
       (date . "2025-01-05")
       (context . "Node.js tooling requires npm install, node_modules, package.json. This adds friction and disk overhead.")
       (decision . "Use Deno's npm: specifier to run ReScript directly from npm registry without node_modules.")
       (consequences
         "No npm install step required"
         "No node_modules directory"
         "Works offline after first run (Deno caches globally)"
         "Bun uses bunx for equivalent behavior"))

      ((id . "adr-002")
       (title . "Runtime detection at startup")
       (status . accepted)
       (date . "2025-01-05")
       (context . "Tool needs to work identically on Deno and Bun while using native APIs of each.")
       (decision . "Detect runtime via globalThis.Deno/globalThis.Bun checks and branch accordingly.")
       (consequences
         "Single codebase for both runtimes"
         "Can use native APIs (Deno.Command vs Bun.spawn)"
         "CLI works the same regardless of runtime"))

      ((id . "adr-003")
       (title . "ReScript for core modules, TypeScript for CLI")
       (status . accepted)
       (date . "2025-01-05")
       (context . "Core detection/build logic should be in ReScript. CLI needs direct runtime access.")
       (decision . "Core modules (Detect, Dev, Test, Build) in ReScript. CLI entry (bin/rrt.ts) in TypeScript for direct Deno/Bun API access.")
       (consequences
         "Type-safe core logic"
         "CLI can use runtime-specific features directly"
         "Clear separation of concerns")))

    (development-practices
      (code-style
        (language . "rescript")
        (formatter . "rescript format")
        (line-length . 100))

      (security
        (permissions . "explicit")
        (notes . "Deno requires --allow-all for full functionality"))

      (testing
        (framework . "runtime-native")
        (deno . "Deno.test")
        (bun . "bun:test"))

      (versioning
        (scheme . "semver")
        (current . "0.1.0"))

      (documentation
        (format . "asciidoc")
        (api-docs . "inline"))

      (branching
        (model . "trunk-based")
        (main . "main")))

    (design-rationale
      (why-no-npm . "Deno's npm: specifier eliminates dependency installation step entirely")
      (why-typescript-cli . "CLI needs direct access to Deno.Command/Bun.spawn which are easier in TS")
      (why-rescript-core . "Type safety and consistency with rescript-full-stack ecosystem"))))
