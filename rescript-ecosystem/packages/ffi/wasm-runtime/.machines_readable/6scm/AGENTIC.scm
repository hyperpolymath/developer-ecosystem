;; SPDX-License-Identifier: PMPL-1.0-or-later
;; AGENTIC.scm - AI agent interaction patterns for rescript-wasm-runtime

(define agentic-config
  (quote ((version . "1.0.0")
    (project . "rescript-wasm-runtime")
    
    (claude-code
      ((model . "claude-opus-4-5-20251101")
       (tools . ("read" "edit" "bash" "grep" "glob"))
       (permissions . "read-all")))
    
    (agent-capabilities
      ((code-review . "thorough")
       (refactoring . "conservative")
       (testing . "comprehensive")
       (documentation . "AsciiDoc")))
    
    (patterns
      ((wasm-bindings . "Use @val @scope for external WebAssembly bindings")
       (error-handling . "Use result types, not exceptions")
       (memory-management . "Use SharedArrayBuffer for zero-copy")
       (async-operations . "Use promise types with async/await")
       (module-structure . "One module per file, clear interfaces")))
    
    (constraints
      ((primary-language . "ReScript")
       (runtime . "Deno")
       (secondary-runtime . "Bun")
       (banned . ("typescript" "go" "python" "makefile" "node" "npm" "bun-pkg"))))
    
    (entry-points
      ((build . "just build")
       (test . "just test")
       (format . "just fmt")
       (examples . "just examples")
       (benchmark . "just bench")))
    
    (code-generation-hints
      ((prefer-functional . true)
       (avoid-mutation . true)
       (explicit-types . true)
       (small-functions . true)
       (comprehensive-tests . true))))))
