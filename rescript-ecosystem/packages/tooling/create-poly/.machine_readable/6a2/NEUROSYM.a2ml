;; SPDX-License-Identifier: PMPL-1.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for rescript-poly-core

(define neurosym-config
  `((version . "1.0.0")
    (project . "rescript-poly-core")
    (symbolic-layer
      ((type . "scheme")
       (reasoning . "deductive")
       (verification . "type-system")
       (representations
         (("state" . "STATE.scm")
          ("ecosystem" . "ECOSYSTEM.scm")
          ("meta" . "META.scm")
          ("playbook" . "PLAYBOOK.scm")))))
    (neural-layer
      ((embeddings . #f)
       (fine-tuning . #f)
       (inference . "claude-code")))
    (integration
      ((pattern . "symbolic-first")
       (description . "Use symbolic representations for project structure and state, neural for code generation and assistance")
       (data-flow
         (("read-state" . "Load .scm files for context")
          ("generate-code" . "Neural generates ReScript code")
          ("verify-types" . "ReScript compiler verifies types")
          ("update-state" . "Update .scm files after changes")))))))
