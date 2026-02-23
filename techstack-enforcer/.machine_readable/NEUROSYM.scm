;; SPDX-License-Identifier: MPL-2.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for techstack-enforcer

(define neurosym-config
  `((version . "1.0.0")
    (symbolic-layer
      ((type . "scheme")
       (reasoning . "deductive")
       (verification . "formal-spark")
       (policy-format . "s-expression filterlist DSL")
       (proof-obligations . "gnatprove --level=2 on src/core/")))
    (neural-layer
      ((embeddings . false)
       (fine-tuning . false)
       (learning-mode
         ((purpose . "CVE pattern analysis to language recommendation")
          (data-source . "NVD 2.0 API")
          (output . "language recommendations by vulnerability class")
          (confidence-threshold . 0.8)))))
    (integration
      ((pattern . "symbolic-core with neural-advisory")
       (description . "Core enforcement is purely symbolic (SPARK-verified). Learning mode adds neural-inspired pattern recognition for CVE-to-language mapping.")
       (invariant . "Neural advisory layer NEVER overrides symbolic enforcement decisions")))))
