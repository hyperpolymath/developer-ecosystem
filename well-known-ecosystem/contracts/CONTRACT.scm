;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2024-2025 hyperpolymath
;;
;; Well-Known Ecosystem Contract Definition
;; Defines the schema, validation rules, and registry format for well-known URIs

(define-module (well-known-ecosystem contracts contract)
  #:use-module (srfi srfi-1)   ; List operations
  #:use-module (srfi srfi-9)   ; Records
  #:export (well-known-contract
            field-spec
            validation-rule
            resource-type
            registry-entry))

;;;; ============================================================
;;;; CONTRACT VERSION
;;;; ============================================================

(define contract-version "1.0.0")
(define contract-updated "2025-12-27")

;;;; ============================================================
;;;; FIELD SPECIFICATION
;;;; Defines the structure for individual fields in a well-known resource
;;;; ============================================================

(define-record-type <field-spec>
  (make-field-spec name type required default format description constraints)
  field-spec?
  (name        field-name)         ; string - field identifier
  (type        field-type)         ; symbol - 'string 'url 'email 'date 'integer 'boolean 'json 'list
  (required    field-required?)    ; boolean - mandatory field
  (default     field-default)      ; any - default value if not provided
  (format      field-format)       ; string or #f - regex pattern or format spec
  (description field-description)  ; string - human-readable description
  (constraints field-constraints)) ; alist - additional validation constraints

;; Field type validators
(define field-types
  '((string   . "UTF-8 text string")
    (url      . "Valid HTTPS URL (RFC 3986)")
    (email    . "Email address (RFC 5322)")
    (date     . "ISO 8601 date or datetime")
    (integer  . "Signed integer")
    (boolean  . "true or false")
    (json     . "Valid JSON object or array")
    (list     . "Newline or comma-separated values")
    (pgp-key  . "OpenPGP public key or URL to key")
    (language . "IETF BCP 47 language tag")
    (duration . "ISO 8601 duration")))

;;;; ============================================================
;;;; VALIDATION RULE
;;;; Defines reusable validation constraints
;;;; ============================================================

(define-record-type <validation-rule>
  (make-validation-rule id severity check message)
  validation-rule?
  (id       rule-id)       ; symbol - unique rule identifier
  (severity rule-severity) ; symbol - 'error 'warning 'info
  (check    rule-check)    ; procedure - (lambda (value context) -> boolean)
  (message  rule-message)) ; string - error message template

;; Severity levels
(define severity-levels
  '((error   . 1)   ; Validation fails, resource is non-compliant
    (warning . 2)   ; Issue detected but resource may still work
    (info    . 3))) ; Informational note, no action required

;;;; ============================================================
;;;; RESOURCE TYPE DEFINITION
;;;; Full specification for a well-known resource type
;;;; ============================================================

(define-record-type <resource-type>
  (make-resource-type id name standard uri-path content-type
                      fields rules expires-field metadata)
  resource-type?
  (id           resource-id)           ; symbol - unique identifier
  (name         resource-name)         ; string - human-readable name
  (standard     resource-standard)     ; string - RFC or spec reference
  (uri-path     resource-uri-path)     ; string - path under /.well-known/
  (content-type resource-content-type) ; string - MIME type
  (fields       resource-fields)       ; list of <field-spec>
  (rules        resource-rules)        ; list of <validation-rule>
  (expires-field resource-expires)     ; symbol or #f - field containing expiry
  (metadata     resource-metadata))    ; alist - additional metadata

;;;; ============================================================
;;;; REGISTRY ENTRY
;;;; Format for storing resources in the registry
;;;; ============================================================

(define-record-type <registry-entry>
  (make-registry-entry resource-id version registered-by
                       registration-date status iana-registered
                       specification-uri notes)
  registry-entry?
  (resource-id       entry-resource-id)       ; symbol - references resource-type id
  (version           entry-version)           ; string - semver
  (registered-by     entry-registered-by)     ; string - registrant organization
  (registration-date entry-registration-date) ; string - ISO 8601 date
  (status            entry-status)            ; symbol - 'active 'deprecated 'proposed
  (iana-registered   entry-iana-registered?)  ; boolean - listed in IANA registry
  (specification-uri entry-specification-uri) ; string - URL to specification
  (notes             entry-notes))            ; string or #f - additional notes

;;;; ============================================================
;;;; VALIDATION RESULT
;;;; Output format for validation operations
;;;; ============================================================

(define-record-type <validation-result>
  (make-validation-result resource-path resource-type valid?
                          errors warnings info metadata)
  validation-result?
  (resource-path result-path)       ; string - path to validated resource
  (resource-type result-type)       ; symbol - resource type id
  (valid?        result-valid?)     ; boolean - overall validation status
  (errors        result-errors)     ; list of strings
  (warnings      result-warnings)   ; list of strings
  (info          result-info)       ; list of strings
  (metadata      result-metadata))  ; alist - extracted metadata

;;;; ============================================================
;;;; WELL-KNOWN CONTRACT
;;;; Master contract combining all definitions
;;;; ============================================================

(define well-known-contract
  `((version     . ,contract-version)
    (updated     . ,contract-updated)
    (description . "Well-Known Ecosystem Contract Definition")
    (license     . "PMPL-1.0 OR PMPL-1.0-or-later")

    ;; Input specification
    (inputs
     ((resource-path
       (type        . path)
       (required    . #t)
       (description . "Path to well-known resource file or directory"))
      (resource-type
       (type        . symbol)
       (required    . #f)
       (description . "Explicit resource type (auto-detected if omitted)"))
      (strict-mode
       (type        . boolean)
       (default     . #f)
       (description . "Treat warnings as errors"))
      (format
       (type        . symbol)
       (values      . (json text sexp))
       (default     . text)
       (description . "Output format for validation results"))))

    ;; Output specification
    (outputs
     ((validation-result
       (type        . validation-result)
       (description . "Structured validation result"))
      (exit-code
       (type        . integer)
       (values      . ((0 . "Valid")
                       (1 . "Validation errors")
                       (2 . "Validation warnings (strict mode)")
                       (3 . "File not found")
                       (4 . "Unknown resource type")
                       (5 . "Parse error")))
       (description . "Process exit code"))
      (report
       (type        . string)
       (description . "Human-readable validation report"))))

    ;; Registry format
    (registry-format
     ((version     . "1.0.0")
      (description . "Well-Known Ecosystem Resource Registry")
      (schema
       ((resource-id       . symbol)
        (version           . string)
        (registered-by     . string)
        (registration-date . date)
        (status            . (active deprecated proposed))
        (iana-registered   . boolean)
        (specification-uri . url)
        (notes             . string-or-null)))
      (indexes
       ((primary   . resource-id)
        (secondary . (status iana-registered))))))

    ;; Core validation rules (apply to all resources)
    (core-validation-rules
     ((utf8-encoding
       (severity    . error)
       (description . "Resource must be valid UTF-8"))
      (no-bom
       (severity    . warning)
       (description . "UTF-8 BOM should not be present"))
      (line-endings
       (severity    . warning)
       (description . "Use LF line endings (not CRLF)"))
      (max-size
       (severity    . error)
       (value       . 1048576)  ; 1 MiB
       (description . "Resource must not exceed 1 MiB"))
      (https-only
       (severity    . error)
       (description . "All URLs must use HTTPS (not HTTP)"))
      (no-localhost
       (severity    . warning)
       (description . "Production resources should not reference localhost"))))))

;;;; ============================================================
;;;; SUPPORTED RESOURCE TYPES
;;;; Definitions for common well-known resources
;;;; ============================================================

(define security-txt-fields
  (list
   (make-field-spec
    'contact 'url #t #f
    "^(mailto:|https://)"
    "Security contact information"
    '((min-count . 1)))
   (make-field-spec
    'expires 'date #t #f
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"
    "Expiration datetime (RFC 9116 mandatory)"
    '((max-future-days . 365)))
   (make-field-spec
    'encryption 'url #f #f
    "^https://"
    "URL to PGP public key"
    '())
   (make-field-spec
    'acknowledgments 'url #f #f
    "^https://"
    "URL to security acknowledgments page"
    '())
   (make-field-spec
    'preferred-languages 'language #f #f
    "^[a-z]{2,3}(-[A-Z]{2})?$"
    "IETF BCP 47 language tags"
    '((separator . ", ")))
   (make-field-spec
    'canonical 'url #f #f
    "^https://"
    "Canonical URL for this security.txt"
    '())
   (make-field-spec
    'policy 'url #f #f
    "^https://"
    "URL to security policy"
    '())
   (make-field-spec
    'hiring 'url #f #f
    "^https://"
    "URL to security jobs page"
    '())))

(define security-txt-rules
  (list
   (make-validation-rule
    'expires-present 'error
    (lambda (content ctx) (string-contains content "Expires:"))
    "RFC 9116 requires an Expires field")
   (make-validation-rule
    'contact-present 'error
    (lambda (content ctx) (string-contains content "Contact:"))
    "RFC 9116 requires at least one Contact field")
   (make-validation-rule
    'expires-not-past 'error
    (lambda (content ctx) #t) ; Implemented in validator
    "Expires date must be in the future")
   (make-validation-rule
    'expires-within-year 'warning
    (lambda (content ctx) #t) ; Implemented in validator
    "Expires date should be within one year")
   (make-validation-rule
    'signed-recommended 'info
    (lambda (content ctx)
      (string-contains content "-----BEGIN PGP SIGNED MESSAGE-----"))
    "PGP signature is recommended")))

(define security-txt-type
  (make-resource-type
   'security-txt
   "security.txt"
   "RFC 9116"
   "security.txt"
   "text/plain; charset=utf-8"
   security-txt-fields
   security-txt-rules
   'expires
   '((iana-registered . #t)
     (required-by-rsr . #t))))

;;;; ============================================================
;;;; OPENID CONFIGURATION
;;;; ============================================================

(define openid-configuration-fields
  (list
   (make-field-spec
    'issuer 'url #t #f
    "^https://"
    "Issuer identifier URL"
    '())
   (make-field-spec
    'authorization_endpoint 'url #t #f
    "^https://"
    "OAuth 2.0 authorization endpoint"
    '())
   (make-field-spec
    'token_endpoint 'url #t #f
    "^https://"
    "OAuth 2.0 token endpoint"
    '())
   (make-field-spec
    'jwks_uri 'url #t #f
    "^https://"
    "URL of JSON Web Key Set"
    '())
   (make-field-spec
    'response_types_supported 'list #t #f
    #f
    "Supported OAuth response types"
    '((min-count . 1)))
   (make-field-spec
    'subject_types_supported 'list #t #f
    #f
    "Supported subject identifier types"
    '((min-count . 1)))
   (make-field-spec
    'id_token_signing_alg_values_supported 'list #t #f
    #f
    "Supported ID token signing algorithms"
    '((must-include . "RS256")))))

(define openid-configuration-type
  (make-resource-type
   'openid-configuration
   "OpenID Connect Discovery"
   "OpenID Connect Discovery 1.0"
   "openid-configuration"
   "application/json"
   openid-configuration-fields
   '()
   #f
   '((iana-registered . #t))))

;;;; ============================================================
;;;; WEBFINGER
;;;; ============================================================

(define webfinger-fields
  (list
   (make-field-spec
    'subject 'url #t #f
    #f
    "Resource identifier (URI)"
    '())
   (make-field-spec
    'aliases 'list #f '()
    #f
    "Additional URIs for the resource"
    '())
   (make-field-spec
    'properties 'json #f #f
    #f
    "Name/value pairs describing the resource"
    '())
   (make-field-spec
    'links 'json #f '()
    #f
    "Array of link objects"
    '())))

(define webfinger-type
  (make-resource-type
   'webfinger
   "WebFinger"
   "RFC 7033"
   "webfinger"
   "application/jrd+json"
   webfinger-fields
   '()
   #f
   '((iana-registered . #t)
     (query-based . #t))))

;;;; ============================================================
;;;; HOST-META
;;;; ============================================================

(define host-meta-type
  (make-resource-type
   'host-meta
   "Host Metadata"
   "RFC 6415"
   "host-meta"
   "application/xrd+xml"
   '()
   '()
   #f
   '((iana-registered . #t)
     (json-variant . "host-meta.json"))))

;;;; ============================================================
;;;; ASSETLINKS.JSON (Android App Links)
;;;; ============================================================

(define assetlinks-fields
  (list
   (make-field-spec
    'relation 'list #t #f
    #f
    "Relationship type declarations"
    '((must-include . "delegate_permission/common.handle_all_urls")))
   (make-field-spec
    'target 'json #t #f
    #f
    "Target application specification"
    '((required-keys . (namespace package_name sha256_cert_fingerprints))))))

(define assetlinks-type
  (make-resource-type
   'assetlinks
   "Digital Asset Links"
   "Google Asset Links"
   "assetlinks.json"
   "application/json"
   assetlinks-fields
   '()
   #f
   '((vendor . "Google")
     (platform . "Android"))))

;;;; ============================================================
;;;; APPLE APP SITE ASSOCIATION
;;;; ============================================================

(define apple-app-site-association-fields
  (list
   (make-field-spec
    'applinks 'json #f #f
    #f
    "Universal links configuration"
    '())
   (make-field-spec
    'webcredentials 'json #f #f
    #f
    "Associated domains for credentials"
    '())
   (make-field-spec
    'appclips 'json #f #f
    #f
    "App Clips configuration"
    '())))

(define apple-app-site-association-type
  (make-resource-type
   'apple-app-site-association
   "Apple App Site Association"
   "Apple Universal Links"
   "apple-app-site-association"
   "application/json"
   apple-app-site-association-fields
   '()
   #f
   '((vendor . "Apple")
     (platform . "iOS/macOS"))))

;;;; ============================================================
;;;; NODEINFO (Fediverse)
;;;; ============================================================

(define nodeinfo-fields
  (list
   (make-field-spec
    'version 'string #t #f
    "^2\\.[0-2]$"
    "NodeInfo schema version"
    '((allowed-values . ("2.0" "2.1" "2.2"))))
   (make-field-spec
    'software 'json #t #f
    #f
    "Server software information"
    '((required-keys . (name version))))
   (make-field-spec
    'protocols 'list #t #f
    #f
    "Supported federation protocols"
    '())
   (make-field-spec
    'usage 'json #t #f
    #f
    "Usage statistics"
    '((required-keys . (users localPosts))))
   (make-field-spec
    'openRegistrations 'boolean #t #f
    #f
    "Whether new registrations are open"
    '())))

(define nodeinfo-type
  (make-resource-type
   'nodeinfo
   "NodeInfo"
   "NodeInfo Schema"
   "nodeinfo"
   "application/json"
   nodeinfo-fields
   '()
   #f
   '((fediverse . #t))))

;;;; ============================================================
;;;; MATRIX SERVER DISCOVERY
;;;; ============================================================

(define matrix-server-fields
  (list
   (make-field-spec
    'm.server 'string #t #f
    "^[a-zA-Z0-9.-]+:[0-9]+$"
    "Matrix server hostname and port"
    '())))

(define matrix-server-type
  (make-resource-type
   'matrix-server
   "Matrix Server Discovery"
   "Matrix Spec"
   "matrix/server"
   "application/json"
   matrix-server-fields
   '()
   #f
   '((protocol . "Matrix"))))

;;;; ============================================================
;;;; RSR-SPECIFIC: AI.TXT
;;;; ============================================================

(define ai-txt-fields
  (list
   (make-field-spec
    'ai-policy 'url #f #f
    "^https://"
    "URL to full AI policy document"
    '())
   (make-field-spec
    'training-opt-out 'boolean #f #f
    #f
    "Whether to opt out of AI training"
    '())
   (make-field-spec
    'contact 'email #f #f
    #f
    "Contact for AI-related inquiries"
    '())))

(define ai-txt-type
  (make-resource-type
   'ai-txt
   "AI Policy Disclosure"
   "RSR Standard"
   "ai.txt"
   "text/plain; charset=utf-8"
   ai-txt-fields
   '()
   #f
   '((rsr-required . #t))))

;;;; ============================================================
;;;; REGISTRY OF SUPPORTED RESOURCE TYPES
;;;; ============================================================

(define resource-registry
  (list
   (make-registry-entry
    'security-txt "1.0.0" "IETF" "2022-04-01" 'active #t
    "https://www.rfc-editor.org/rfc/rfc9116" #f)
   (make-registry-entry
    'openid-configuration "1.0.0" "OpenID Foundation" "2014-11-08" 'active #t
    "https://openid.net/specs/openid-connect-discovery-1_0.html" #f)
   (make-registry-entry
    'webfinger "1.0.0" "IETF" "2013-09-01" 'active #t
    "https://www.rfc-editor.org/rfc/rfc7033" #f)
   (make-registry-entry
    'host-meta "1.0.0" "IETF" "2012-10-01" 'active #t
    "https://www.rfc-editor.org/rfc/rfc6415" #f)
   (make-registry-entry
    'assetlinks "1.0.0" "Google" "2015-01-01" 'active #f
    "https://developers.google.com/digital-asset-links" "Android app links")
   (make-registry-entry
    'apple-app-site-association "1.0.0" "Apple" "2015-01-01" 'active #f
    "https://developer.apple.com/documentation/xcode/supporting-associated-domains"
    "iOS universal links")
   (make-registry-entry
    'nodeinfo "2.2.0" "NodeInfo" "2018-01-01" 'active #f
    "https://nodeinfo.diaspora.software/" "Fediverse server info")
   (make-registry-entry
    'matrix-server "1.0.0" "Matrix.org" "2019-01-01" 'active #f
    "https://spec.matrix.org/" "Matrix federation")
   (make-registry-entry
    'ai-txt "1.0.0" "hyperpolymath" "2025-01-01" 'proposed #f
    #f "RSR-specific AI policy disclosure")))

;;;; ============================================================
;;;; EXPORT ALL TYPES
;;;; ============================================================

(define all-resource-types
  (list security-txt-type
        openid-configuration-type
        webfinger-type
        host-meta-type
        assetlinks-type
        apple-app-site-association-type
        nodeinfo-type
        matrix-server-type
        ai-txt-type))

;; End of contract definition
