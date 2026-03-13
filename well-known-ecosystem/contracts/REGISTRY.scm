;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2024-2025 hyperpolymath
;;
;; Well-Known Ecosystem Registry
;; Canonical registry of supported well-known resources

(define-module (well-known-ecosystem contracts registry)
  #:export (registry
            registry-version
            lookup-resource
            list-resources
            filter-by-status))

;;;; ============================================================
;;;; REGISTRY METADATA
;;;; ============================================================

(define registry-version "1.0.0")
(define registry-updated "2025-12-27")

;;;; ============================================================
;;;; REGISTRY DATA
;;;; Each entry follows the registry-entry schema from CONTRACT.scm
;;;; ============================================================

(define registry
  '(;; RFC 9116 - Security Contact
    ((id                . security-txt)
     (name              . "security.txt")
     (version           . "1.0.0")
     (uri-path          . "security.txt")
     (content-type      . "text/plain; charset=utf-8")
     (standard          . "RFC 9116")
     (specification-uri . "https://www.rfc-editor.org/rfc/rfc9116")
     (registered-by     . "IETF")
     (registration-date . "2022-04-01")
     (status            . active)
     (iana-registered   . #t)
     (has-expiry        . #t)
     (required-fields   . (contact expires))
     (optional-fields   . (encryption acknowledgments preferred-languages
                           canonical policy hiring))
     (notes             . "Mandatory for RSR compliance"))

    ;; OpenID Connect Discovery
    ((id                . openid-configuration)
     (name              . "OpenID Connect Discovery")
     (version           . "1.0.0")
     (uri-path          . "openid-configuration")
     (content-type      . "application/json")
     (standard          . "OpenID Connect Discovery 1.0")
     (specification-uri . "https://openid.net/specs/openid-connect-discovery-1_0.html")
     (registered-by     . "OpenID Foundation")
     (registration-date . "2014-11-08")
     (status            . active)
     (iana-registered   . #t)
     (has-expiry        . #f)
     (required-fields   . (issuer authorization_endpoint token_endpoint
                           jwks_uri response_types_supported
                           subject_types_supported
                           id_token_signing_alg_values_supported))
     (optional-fields   . (userinfo_endpoint registration_endpoint
                           scopes_supported claims_supported))
     (notes             . #f))

    ;; WebFinger (RFC 7033)
    ((id                . webfinger)
     (name              . "WebFinger")
     (version           . "1.0.0")
     (uri-path          . "webfinger")
     (content-type      . "application/jrd+json")
     (standard          . "RFC 7033")
     (specification-uri . "https://www.rfc-editor.org/rfc/rfc7033")
     (registered-by     . "IETF")
     (registration-date . "2013-09-01")
     (status            . active)
     (iana-registered   . #t)
     (has-expiry        . #f)
     (required-fields   . (subject))
     (optional-fields   . (aliases properties links))
     (query-parameters  . (resource rel))
     (notes             . "Query-based resource"))

    ;; Host Metadata (RFC 6415)
    ((id                . host-meta)
     (name              . "Host Metadata")
     (version           . "1.0.0")
     (uri-path          . "host-meta")
     (content-type      . "application/xrd+xml")
     (standard          . "RFC 6415")
     (specification-uri . "https://www.rfc-editor.org/rfc/rfc6415")
     (registered-by     . "IETF")
     (registration-date . "2012-10-01")
     (status            . active)
     (iana-registered   . #t)
     (has-expiry        . #f)
     (variants          . ((json . "host-meta.json")))
     (notes             . #f))

    ;; Change Password (WICG)
    ((id                . change-password)
     (name              . "Change Password")
     (version           . "1.0.0")
     (uri-path          . "change-password")
     (content-type      . "text/html")
     (standard          . "WICG Spec")
     (specification-uri . "https://wicg.github.io/change-password-url/")
     (registered-by     . "WICG")
     (registration-date . "2019-01-01")
     (status            . active)
     (iana-registered   . #t)
     (has-expiry        . #f)
     (behavior          . redirect)
     (notes             . "Should redirect to password change page"))

    ;; Digital Asset Links (Android)
    ((id                . assetlinks)
     (name              . "Digital Asset Links")
     (version           . "1.0.0")
     (uri-path          . "assetlinks.json")
     (content-type      . "application/json")
     (standard          . "Google Asset Links")
     (specification-uri . "https://developers.google.com/digital-asset-links")
     (registered-by     . "Google")
     (registration-date . "2015-01-01")
     (status            . active)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (platform          . android)
     (required-fields   . (relation target))
     (notes             . "Android App Links verification"))

    ;; Apple App Site Association
    ((id                . apple-app-site-association)
     (name              . "Apple App Site Association")
     (version           . "2.0.0")
     (uri-path          . "apple-app-site-association")
     (content-type      . "application/json")
     (standard          . "Apple Universal Links")
     (specification-uri . "https://developer.apple.com/documentation/xcode/supporting-associated-domains")
     (registered-by     . "Apple")
     (registration-date . "2015-01-01")
     (status            . active)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (platform          . ios)
     (optional-fields   . (applinks webcredentials appclips))
     (notes             . "iOS Universal Links and Associated Domains"))

    ;; DNT Policy
    ((id                . dnt-policy)
     (name              . "Do Not Track Policy")
     (version           . "1.0.0")
     (uri-path          . "dnt-policy.txt")
     (content-type      . "text/plain")
     (standard          . "W3C Tracking Protection")
     (specification-uri . "https://www.w3.org/TR/tracking-dnt/")
     (registered-by     . "W3C")
     (registration-date . "2019-01-17")
     (status            . deprecated)
     (iana-registered   . #t)
     (has-expiry        . #f)
     (notes             . "W3C discontinued the DNT standard"))

    ;; Matrix Server Discovery
    ((id                . matrix-server)
     (name              . "Matrix Server")
     (version           . "1.0.0")
     (uri-path          . "matrix/server")
     (content-type      . "application/json")
     (standard          . "Matrix Spec")
     (specification-uri . "https://spec.matrix.org/")
     (registered-by     . "Matrix.org Foundation")
     (registration-date . "2019-01-01")
     (status            . active)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (protocol          . matrix)
     (required-fields   . (m.server))
     (notes             . "Matrix federation server discovery"))

    ;; Matrix Client Discovery
    ((id                . matrix-client)
     (name              . "Matrix Client")
     (version           . "1.0.0")
     (uri-path          . "matrix/client")
     (content-type      . "application/json")
     (standard          . "Matrix Spec")
     (specification-uri . "https://spec.matrix.org/")
     (registered-by     . "Matrix.org Foundation")
     (registration-date . "2019-01-01")
     (status            . active)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (protocol          . matrix)
     (notes             . "Matrix client API discovery"))

    ;; NodeInfo (Fediverse)
    ((id                . nodeinfo)
     (name              . "NodeInfo")
     (version           . "2.2.0")
     (uri-path          . "nodeinfo")
     (content-type      . "application/json")
     (standard          . "NodeInfo 2.0")
     (specification-uri . "https://nodeinfo.diaspora.software/")
     (registered-by     . "Diaspora Foundation")
     (registration-date . "2018-01-01")
     (status            . active)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (protocol          . activitypub)
     (required-fields   . (version software protocols usage openRegistrations))
     (notes             . "Fediverse/ActivityPub server metadata"))

    ;; Humans.txt
    ((id                . humans-txt)
     (name              . "Humans.txt")
     (version           . "1.0.0")
     (uri-path          . "humans.txt")
     (content-type      . "text/plain; charset=utf-8")
     (standard          . "humanstxt.org")
     (specification-uri . "https://humanstxt.org/")
     (registered-by     . "humanstxt.org")
     (registration-date . "2010-01-01")
     (status            . active)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (notes             . "RSR recommended"))

    ;; RSR-specific: AI Policy Disclosure
    ((id                . ai-txt)
     (name              . "AI Policy Disclosure")
     (version           . "1.0.0")
     (uri-path          . "ai.txt")
     (content-type      . "text/plain; charset=utf-8")
     (standard          . "RSR Standard")
     (specification-uri . #f)
     (registered-by     . "hyperpolymath")
     (registration-date . "2025-01-01")
     (status            . proposed)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (optional-fields   . (ai-policy training-opt-out contact))
     (notes             . "RSR-mandated AI policy disclosure"))

    ;; Robots.txt (not under .well-known but commonly checked)
    ((id                . robots-txt)
     (name              . "Robots Exclusion")
     (version           . "1.0.0")
     (uri-path          . "/robots.txt")
     (well-known-path   . #f)
     (content-type      . "text/plain")
     (standard          . "RFC 9309")
     (specification-uri . "https://www.rfc-editor.org/rfc/rfc9309")
     (registered-by     . "IETF")
     (registration-date . "2022-09-01")
     (status            . active)
     (iana-registered   . #f)
     (has-expiry        . #f)
     (notes             . "Not under .well-known but related"))))

;;;; ============================================================
;;;; REGISTRY OPERATIONS
;;;; ============================================================

(define (lookup-resource id)
  "Find a resource entry by its ID."
  (find (lambda (entry)
          (eq? (assoc-ref entry 'id) id))
        registry))

(define (list-resources)
  "Return all registered resource IDs."
  (map (lambda (entry) (assoc-ref entry 'id)) registry))

(define (filter-by-status status)
  "Filter registry entries by status (active, deprecated, proposed)."
  (filter (lambda (entry)
            (eq? (assoc-ref entry 'status) status))
          registry))

(define (filter-by-iana iana-registered?)
  "Filter registry entries by IANA registration status."
  (filter (lambda (entry)
            (eq? (assoc-ref entry 'iana-registered) iana-registered?))
          registry))

(define (get-required-fields id)
  "Get required fields for a resource type."
  (let ((entry (lookup-resource id)))
    (if entry
        (or (assoc-ref entry 'required-fields) '())
        #f)))

(define (get-uri-path id)
  "Get the well-known URI path for a resource type."
  (let ((entry (lookup-resource id)))
    (if entry
        (assoc-ref entry 'uri-path)
        #f)))

;;;; ============================================================
;;;; REGISTRY VALIDATION
;;;; ============================================================

(define (validate-registry)
  "Validate the registry for internal consistency."
  (let ((errors '()))
    ;; Check for duplicate IDs
    (let ((ids (list-resources)))
      (unless (= (length ids) (length (delete-duplicates ids)))
        (set! errors (cons "Duplicate resource IDs found" errors))))
    ;; Check required fields
    (for-each
     (lambda (entry)
       (let ((id (assoc-ref entry 'id))
             (uri-path (assoc-ref entry 'uri-path))
             (standard (assoc-ref entry 'standard)))
         (unless id
           (set! errors (cons "Entry missing 'id' field" errors)))
         (unless uri-path
           (set! errors (cons (format #f "Entry ~a missing 'uri-path'" id) errors)))
         (unless standard
           (set! errors (cons (format #f "Entry ~a missing 'standard'" id) errors)))))
     registry)
    errors))

;; End of registry
