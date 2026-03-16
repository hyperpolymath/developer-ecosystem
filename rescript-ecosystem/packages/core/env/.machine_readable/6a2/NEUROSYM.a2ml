;; SPDX-License-Identifier: PMPL-1.0-or-later
;; NEUROSYM.scm - Neurosymbolic integration config for rescript-env

(define neurosym-config
  `((version . "1.0.0")

    (project . "rescript-env")

    (symbolic-layer
      ((type . "scheme")
       (reasoning . "deductive")
       (verification . "type-system")
       (artifacts . (".machine_readable/*.scm"))))

    (neural-layer
      ((embeddings . false)
       (fine-tuning . false)
       (inference . "claude-opus-4-5-20251101")))

    (integration
      ((code-generation
        ((style . "functional")
         (language . "ReScript")
         (patterns . ("option-types" "pattern-matching" "pipe-operators"))))

       (documentation
        ((format . "asciidoc")
         (api-style . "jsdoc-comments")
         (examples . "required")))

       (quality-assurance
        ((type-checking . "rescript-compiler")
         (runtime-testing . "deno-test")
         (static-analysis . "compiler-warnings")))))))
