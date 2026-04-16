; SPDX-License-Identifier: PMPL-1.0-or-later
;; guix.scm — GNU Guix package definition for idaptik-rescript13-staging
;; Usage: guix shell -f guix.scm

(use-modules (guix packages)
             (guix build-system gnu)
             (guix licenses))

(package
  (name "idaptik-rescript13-staging")
  (version "0.1.0")
  (source #f)
  (build-system gnu-build-system)
  (synopsis "idaptik-rescript13-staging")
  (description "idaptik-rescript13-staging — part of the hyperpolymath ecosystem.")
  (home-page "https://github.com/hyperpolymath/idaptik-rescript13-staging")
  (license ((@@ (guix licenses) license) "PMPL-1.0-or-later"
             "https://github.com/hyperpolymath/palimpsest-license")))
