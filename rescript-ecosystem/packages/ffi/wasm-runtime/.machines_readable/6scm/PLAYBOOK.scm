;; SPDX-License-Identifier: PMPL-1.0-or-later
;; PLAYBOOK.scm - Operational runbook for rescript-wasm-runtime

(define playbook
  (quote ((version . "1.0.0")
    (project . "rescript-wasm-runtime")
    
    (procedures
      ((build
         ((step . "Install dependencies")
          (command . "npm install"))
         ((step . "Build ReScript sources")
          (command . "just build"))
         ((step . "Verify build")
          (command . "ls src/*.mjs")))
       
       (test
         ((step . "Run all tests")
          (command . "just test"))
         ((step . "Run with coverage")
          (command . "just test-coverage"))
         ((step . "Run unit tests only")
          (command . "just test-unit")))
       
       (deploy
         ((step . "Build production")
          (command . "just build"))
         ((step . "Run tests")
          (command . "just test"))
         ((step . "Deploy to Deno Deploy")
          (command . "just deploy-deno")))
       
       (benchmark
         ((step . "Run startup benchmark")
          (command . "just bench-startup"))
         ((step . "Run memory benchmark")
          (command . "just bench-memory"))
         ((step . "Compare with Node")
          (command . "just bench-compare")))
       
       (debug
         ((step . "Check SharedArrayBuffer availability")
          (command . "deno eval \"console.log(typeof SharedArrayBuffer)\""))
         ((step . "Profile example")
          (command . "just profile hello-world"))
         ((step . "Check WASM module loading")
          (command . "deno run --allow-read src/Wasm.res.mjs")))
       
       (rollback
         ((step . "Revert to previous commit")
          (command . "git revert HEAD"))
         ((step . "Force clean build")
          (command . "just rebuild")))))
    
    (alerts
      ((wasm-load-failure . "Check module path and format")
       (shared-memory-unavailable . "Enable cross-origin isolation headers")
       (cycle-detected . "Review dependency graph with DependencyGraph.analyze")))
    
    (contacts
      ((maintainer . "hyperpolymath")
       (repository . "github.com/hyperpolymath/rescript-wasm-runtime"))))))
