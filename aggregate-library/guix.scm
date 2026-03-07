;;; SPDX-License-Identifier: PMPL-1.0-or-later
;;; SPDX-FileCopyrightText: 2025 Hyperpolymath

;;; guix.scm - GNU Guix package definition for aggregate-library
;;; Primary package manager per Hyperpolymath Standard language policy

(use-modules (guix packages)
             (guix gexp)
             (guix git-download)
             (guix build-system copy)
             ((guix licenses) #:prefix license:)
             (gnu packages base)
             (gnu packages version-control))

(define-public aggregate-library
  (package
    (name "aggregate-library")
    (version "0.1.0")
    (source (local-file "." "aggregate-library-checkout"
                        #:recursive? #t
                        #:select? (lambda (file stat)
                                    (not (string-prefix? ".git" (basename file))))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("specs" "share/aggregate-library/specs")
          ("docs" "share/aggregate-library/docs")
          ("README.adoc" "share/aggregate-library/README.adoc")
          ("README.md" "share/aggregate-library/README.md")
          ("LICENSE.txt" "share/aggregate-library/LICENSE.txt")
          ("SPEC_FORMAT.md" "share/aggregate-library/SPEC_FORMAT.md")
          ("config.ncl" "share/aggregate-library/config.ncl")
          (".well-known" "share/aggregate-library/.well-known"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'validate-specs
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((out (assoc-ref outputs "out")))
                ;; Verify specifications are properly installed
                (for-each
                 (lambda (category)
                   (let ((dir (string-append out "/share/aggregate-library/specs/" category)))
                     (unless (file-exists? dir)
                       (error "Missing specification category:" category))))
                 '("arithmetic" "comparison" "logical" "string" "collection" "conditional"))
                #t))))))
    (native-inputs
     (list coreutils))
    (home-page "https://github.com/Hyperpolymath/aggregate-library")
    (synopsis "Common Library specification for cross-language programming")
    (description
     "aggregate-library (aLib) defines a minimal Common Library specification
representing the intersection of functionality across 7 programming languages:
WokeLang, Duet/Ensemble, Eclexia, Oblíbený, RT-Lang, Phronesis, and Julia the Viper.

The library provides 20 core operations across 6 categories:
@itemize
@item Arithmetic: add, subtract, multiply, divide, modulo
@item Comparison: less_than, greater_than, equal, not_equal, less_equal, greater_equal
@item Logical: and, or, not
@item String: concat, length, substring
@item Collection: map, filter, fold, contains
@item Conditional: if_then_else
@end itemize

This package installs the specifications, not executable code.  Each language
implementation can use these specifications to ensure cross-language compatibility.")
    (license (list license:expat license:agpl3+))))

;; Return the package for direct evaluation
aggregate-library
