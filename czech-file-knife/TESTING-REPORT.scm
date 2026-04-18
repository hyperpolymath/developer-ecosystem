;; SPDX-License-Identifier: MPL-2.0-or-later
;; Testing Report for czech-file-knife
;; Generated: 2025-12-29

(define testing-report
  '((project . "czech-file-knife")
    (date . "2025-12-29")
    (author . "Claude Code Automated Testing")

    (summary
     (status . pass)
     (build . success)
     (tests-passed . 8)
     (tests-failed . 0)
     (execution . "all-commands-functional"))

    (build-results
     (command . "cargo build --release")
     (duration-seconds . 67)
     (outcome . success)
     (warnings
      ((crate . "cfk-providers")
       (count . 2)
       (type . "unexpected-cfg-condition"))
      ((crate . "cfk-cache")
       (count . 2)
       (type . "unused-imports"))
      ((crate . "cfk-ios")
       (count . 3)
       (type . "unused-imports-variables"))))

    (test-results
     (command . "cargo test")
     (total . 8)
     (passed . 8)
     (failed . 0))

    (functional-tests
     ((command . "cfk --help") (status . pass))
     ((command . "cfk backends") (status . pass))
     ((command . "cfk ls") (status . pass))
     ((command . "cfk cat") (status . pass))
     ((command . "cfk stat") (status . pass))
     ((command . "cfk mkdir") (status . pass))
     ((command . "cfk cp") (status . pass))
     ((command . "cfk mv") (status . pass))
     ((command . "cfk rm") (status . pass))
     ((command . "cfk df local") (status . pass) (note . "fixed")))

    (fixes-applied
     ((id . 1)
      (file . "cfk-providers/src/local.rs")
      (problem . "get_space_info returned unknown")
      (solution . "Implemented Unix statvfs call")
      (dependency-added . "libc")))

    (recommendations
     ((priority . minor)
      (items
       ("Add ceph feature to Cargo.toml or remove cfg attribute")
       ("Run cargo fix to clean up unused imports"))))))

;; Helper to check if tests passed
(define (tests-passed? report)
  (eq? (assoc-ref (assoc-ref report 'summary) 'status) 'pass))
