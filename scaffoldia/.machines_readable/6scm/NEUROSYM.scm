;; SPDX-License-Identifier: MPL-2.0
;; NEUROSYM.scm - Neurosymbolic integration config for rsr-template-repo

(define neurosym-config
  `((version . "1.0.0")
    (symbolic-layer
      ((type . "scheme")
       (reasoning . "deductive")
       (verification . "formal")))
    (neural-layer
      ((embeddings . false)
       (fine-tuning . false)))
    (integration . ())))
