;; SPDX-License-Identifier: PMPL-1.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for rescript-poly-core

(define neurosym-config
  `((version . "1.0.0")
    (symbolic-layer
      ((type . "rescript")
       (reasoning . "type-driven")
       (verification . "compiler")
       (patterns
         ("result-types" "pattern-matching" "exhaustive-checks"))))
    (neural-layer
      ((embeddings . false)
       (fine-tuning . false)
       (mcp-integration . true)))
    (integration
      ((ai-agents . "mcp-protocol")
       (tool-calling . "structured-schemas")
       (error-feedback . "typed-results")))))
