;; SPDX-License-Identifier: MPL-2.0
;; NEUROSYM.scm - Neurosymbolic config

(define neurosym-config
  `((version . "1.0.0")
    (symbolic-layer
      ((type . "scheme")
       (reasoning . "deductive")))
    (neural-layer
      ((embeddings . false)
       (fine-tuning . false)))
    (integration . ())))
