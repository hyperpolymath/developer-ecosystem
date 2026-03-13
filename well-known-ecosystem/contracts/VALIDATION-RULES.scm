;; SPDX-License-Identifier: PMPL-1.0-or-later
;; SPDX-FileCopyrightText: 2024-2025 hyperpolymath
;;
;; Well-Known Ecosystem Validation Rules
;; Comprehensive validation rule definitions for all resource types

(define-module (well-known-ecosystem contracts validation-rules)
  #:export (core-rules
            security-txt-rules
            openid-configuration-rules
            json-resource-rules
            all-rules))

;;;; ============================================================
;;;; RULE SEVERITY DEFINITIONS
;;;; ============================================================

;; error   - Validation fails, resource is non-compliant
;; warning - Issue detected but resource may still function
;; info    - Informational note, best practice suggestion

;;;; ============================================================
;;;; CORE RULES (Apply to all resources)
;;;; ============================================================

(define core-rules
  '(;; Encoding rules
    ((id          . core/utf8-encoding)
     (severity    . error)
     (applies-to  . all)
     (description . "Resource content must be valid UTF-8")
     (check       . "Validate UTF-8 encoding of entire content")
     (message     . "Invalid UTF-8 encoding detected at byte offset ~a"))

    ((id          . core/no-bom)
     (severity    . warning)
     (applies-to  . all)
     (description . "UTF-8 BOM (Byte Order Mark) should not be present")
     (check       . "Check for BOM bytes 0xEF 0xBB 0xBF at start")
     (message     . "UTF-8 BOM detected; remove for compatibility"))

    ((id          . core/line-endings)
     (severity    . warning)
     (applies-to  . (text/plain text/html application/xml))
     (description . "Use LF line endings, not CRLF")
     (check       . "Scan for CRLF (0x0D 0x0A) sequences")
     (message     . "CRLF line endings detected; prefer LF for consistency"))

    ((id          . core/trailing-newline)
     (severity    . info)
     (applies-to  . all)
     (description . "Files should end with a newline")
     (check       . "Check if last byte is 0x0A")
     (message     . "File does not end with newline"))

    ;; Size rules
    ((id          . core/max-size)
     (severity    . error)
     (applies-to  . all)
     (description . "Resource must not exceed maximum size")
     (parameters  . ((max-bytes . 1048576)))  ; 1 MiB
     (check       . "Compare file size to max-bytes parameter")
     (message     . "Resource size ~a bytes exceeds maximum ~a bytes"))

    ((id          . core/min-size)
     (severity    . warning)
     (applies-to  . all)
     (description . "Resource should not be empty")
     (parameters  . ((min-bytes . 1)))
     (check       . "Check file size > 0")
     (message     . "Resource is empty"))

    ;; URL rules
    ((id          . core/https-only)
     (severity    . error)
     (applies-to  . all)
     (description . "All URLs must use HTTPS protocol")
     (check       . "Regex match for http:// (excluding localhost)")
     (exceptions  . ("http://localhost" "http://127.0.0.1" "http://[::1]"))
     (message     . "HTTP URL found: ~a (must use HTTPS)"))

    ((id          . core/valid-urls)
     (severity    . error)
     (applies-to  . all)
     (description . "All URLs must be syntactically valid (RFC 3986)")
     (check       . "Parse all URL-typed fields with RFC 3986 parser")
     (message     . "Invalid URL syntax: ~a"))

    ((id          . core/no-localhost-production)
     (severity    . warning)
     (applies-to  . all)
     (description . "Production resources should not reference localhost")
     (check       . "Scan for localhost, 127.0.0.1, [::1] in URLs")
     (message     . "Localhost reference found: ~a (not suitable for production)"))

    ;; Security rules
    ((id          . core/no-weak-crypto)
     (severity    . error)
     (applies-to  . all)
     (description . "Do not reference weak cryptographic algorithms")
     (check       . "Scan for MD5, SHA1 in security contexts")
     (blocked     . ("MD5" "SHA1" "RC4" "DES" "3DES"))
     (message     . "Weak cryptographic algorithm referenced: ~a"))

    ((id          . core/no-secrets)
     (severity    . error)
     (applies-to  . all)
     (description . "Resources must not contain secrets or credentials")
     (check       . "Pattern match for common secret formats")
     (patterns    . ("password=" "api_key=" "secret=" "token="
                     "-----BEGIN PRIVATE KEY-----"
                     "-----BEGIN RSA PRIVATE KEY-----"))
     (message     . "Potential secret detected: ~a"))))

;;;; ============================================================
;;;; SECURITY.TXT RULES (RFC 9116)
;;;; ============================================================

(define security-txt-rules
  '(;; Required field rules
    ((id          . security-txt/contact-required)
     (severity    . error)
     (applies-to  . security-txt)
     (description . "Contact field is mandatory (RFC 9116 Section 2.5.3)")
     (check       . "Grep for ^Contact: at line start")
     (message     . "Missing required Contact field"))

    ((id          . security-txt/expires-required)
     (severity    . error)
     (applies-to  . security-txt)
     (description . "Expires field is mandatory (RFC 9116 Section 2.5.5)")
     (check       . "Grep for ^Expires: at line start")
     (message     . "Missing required Expires field"))

    ;; Contact field validation
    ((id          . security-txt/contact-format)
     (severity    . error)
     (applies-to  . security-txt)
     (description . "Contact must be mailto: or https:// URL")
     (check       . "Validate Contact field value format")
     (pattern     . "^Contact:\\s*(mailto:|https://)")
     (message     . "Contact must start with mailto: or https://"))

    ((id          . security-txt/contact-multiple)
     (severity    . info)
     (applies-to  . security-txt)
     (description . "Multiple contact methods recommended")
     (check       . "Count Contact: lines")
     (recommended . 2)
     (message     . "Consider adding multiple contact methods"))

    ;; Expires field validation
    ((id          . security-txt/expires-format)
     (severity    . error)
     (applies-to  . security-txt)
     (description . "Expires must be ISO 8601 datetime with timezone")
     (check       . "Parse Expires value as ISO 8601")
     (pattern     . "^Expires:\\s*[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}")
     (message     . "Expires must be ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)"))

    ((id          . security-txt/expires-not-past)
     (severity    . error)
     (applies-to  . security-txt)
     (description . "Expires date must be in the future")
     (check       . "Compare Expires datetime to current time")
     (message     . "security.txt has expired (Expires: ~a)"))

    ((id          . security-txt/expires-within-year)
     (severity    . warning)
     (applies-to  . security-txt)
     (description . "Expires should be within one year")
     (check       . "Calculate days until expiry")
     (max-days    . 365)
     (message     . "Expires is more than 1 year in the future (~a days)"))

    ((id          . security-txt/expires-soon)
     (severity    . warning)
     (applies-to  . security-txt)
     (description . "Warn when expiration is approaching")
     (check       . "Calculate days until expiry")
     (warn-days   . 30)
     (message     . "security.txt expires in ~a days"))

    ;; Optional field validation
    ((id          . security-txt/encryption-https)
     (severity    . error)
     (applies-to  . security-txt)
     (description . "Encryption field URL must use HTTPS")
     (check       . "Validate Encryption field URL scheme")
     (pattern     . "^Encryption:\\s*https://")
     (message     . "Encryption URL must use HTTPS"))

    ((id          . security-txt/preferred-languages-format)
     (severity    . error)
     (applies-to  . security-txt)
     (description . "Preferred-Languages must be valid BCP 47 tags")
     (check       . "Parse and validate language tags")
     (pattern     . "^[a-z]{2,3}(-[A-Z][a-z]{3})?(-[A-Z]{2})?$")
     (message     . "Invalid language tag: ~a"))

    ;; Signature validation
    ((id          . security-txt/signature-recommended)
     (severity    . info)
     (applies-to  . security-txt)
     (description . "PGP signature recommended for authenticity")
     (check       . "Check for -----BEGIN PGP SIGNED MESSAGE-----")
     (message     . "Consider adding PGP signature for authenticity"))

    ((id          . security-txt/signature-valid)
     (severity    . warning)
     (applies-to  . security-txt)
     (description . "If signed, PGP signature should be valid")
     (check       . "Verify PGP signature if present")
     (requires    . gpg)
     (message     . "PGP signature verification failed"))

    ;; Format rules
    ((id          . security-txt/no-duplicate-fields)
     (severity    . warning)
     (applies-to  . security-txt)
     (description . "Avoid duplicate field names (except Contact)")
     (check       . "Count occurrences of each field name")
     (allowed-duplicates . (contact))
     (message     . "Duplicate field: ~a (only Contact may be repeated)"))

    ((id          . security-txt/unknown-fields)
     (severity    . info)
     (applies-to  . security-txt)
     (description . "Unknown fields are allowed but noted")
     (check       . "Compare field names to known set")
     (known-fields . (contact expires encryption acknowledgments
                      preferred-languages canonical policy hiring))
     (message     . "Unknown field: ~a"))

    ((id          . security-txt/field-casing)
     (severity    . warning)
     (applies-to  . security-txt)
     (description . "Field names should use canonical casing")
     (check       . "Compare field names case-sensitively")
     (canonical   . ((contact . "Contact")
                     (expires . "Expires")
                     (encryption . "Encryption")
                     (acknowledgments . "Acknowledgments")
                     (preferred-languages . "Preferred-Languages")
                     (canonical . "Canonical")
                     (policy . "Policy")
                     (hiring . "Hiring")))
     (message     . "Field ~a should be ~a"))))

;;;; ============================================================
;;;; OPENID CONFIGURATION RULES
;;;; ============================================================

(define openid-configuration-rules
  '(;; Required fields
    ((id          . oidc/issuer-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "issuer field is required")
     (check       . "Check for issuer key in JSON")
     (message     . "Missing required field: issuer"))

    ((id          . oidc/issuer-https)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "issuer must be HTTPS URL")
     (check       . "Validate issuer URL scheme")
     (message     . "issuer must use HTTPS"))

    ((id          . oidc/issuer-no-fragment)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "issuer must not contain fragment")
     (check       . "Check issuer URL for # character")
     (message     . "issuer must not contain URL fragment"))

    ((id          . oidc/authorization-endpoint-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "authorization_endpoint is required")
     (check       . "Check for authorization_endpoint key")
     (message     . "Missing required field: authorization_endpoint"))

    ((id          . oidc/token-endpoint-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "token_endpoint is required")
     (check       . "Check for token_endpoint key")
     (message     . "Missing required field: token_endpoint"))

    ((id          . oidc/jwks-uri-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "jwks_uri is required")
     (check       . "Check for jwks_uri key")
     (message     . "Missing required field: jwks_uri"))

    ((id          . oidc/response-types-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "response_types_supported is required")
     (check       . "Check for response_types_supported key")
     (message     . "Missing required field: response_types_supported"))

    ((id          . oidc/subject-types-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "subject_types_supported is required")
     (check       . "Check for subject_types_supported key")
     (message     . "Missing required field: subject_types_supported"))

    ((id          . oidc/signing-alg-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "id_token_signing_alg_values_supported is required")
     (check       . "Check for id_token_signing_alg_values_supported key")
     (message     . "Missing required field: id_token_signing_alg_values_supported"))

    ;; Algorithm requirements
    ((id          . oidc/rs256-required)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "RS256 must be supported for ID token signing")
     (check       . "Check id_token_signing_alg_values_supported includes RS256")
     (message     . "RS256 must be in id_token_signing_alg_values_supported"))

    ((id          . oidc/no-none-alg)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "Algorithm 'none' should not be supported")
     (check       . "Check signing alg does not include 'none'")
     (message     . "'none' algorithm should not be supported"))

    ;; URL validation
    ((id          . oidc/all-endpoints-https)
     (severity    . error)
     (applies-to  . openid-configuration)
     (description . "All endpoint URLs must use HTTPS")
     (check       . "Validate all *_endpoint and *_uri fields")
     (message     . "Endpoint ~a must use HTTPS"))))

;;;; ============================================================
;;;; JSON RESOURCE RULES
;;;; ============================================================

(define json-resource-rules
  '(((id          . json/valid-syntax)
     (severity    . error)
     (applies-to  . (application/json application/jrd+json))
     (description . "Content must be valid JSON")
     (check       . "Parse content as JSON")
     (message     . "Invalid JSON syntax: ~a"))

    ((id          . json/object-or-array)
     (severity    . error)
     (applies-to  . (application/json))
     (description . "Root must be object or array")
     (check       . "Check JSON root type")
     (message     . "JSON root must be object or array, found ~a"))

    ((id          . json/no-duplicate-keys)
     (severity    . warning)
     (applies-to  . (application/json application/jrd+json))
     (description . "Object keys should be unique")
     (check       . "Scan for duplicate keys in objects")
     (message     . "Duplicate key found: ~a"))

    ((id          . json/no-trailing-comma)
     (severity    . warning)
     (applies-to  . (application/json application/jrd+json))
     (description . "Avoid trailing commas (not valid JSON)")
     (check       . "Check for ,] or ,} patterns")
     (message     . "Trailing comma detected (strict JSON violation)"))))

;;;; ============================================================
;;;; WEBFINGER RULES (RFC 7033)
;;;; ============================================================

(define webfinger-rules
  '(((id          . webfinger/subject-required)
     (severity    . error)
     (applies-to  . webfinger)
     (description . "subject field is required")
     (check       . "Check for subject key in JRD")
     (message     . "Missing required field: subject"))

    ((id          . webfinger/subject-uri)
     (severity    . error)
     (applies-to  . webfinger)
     (description . "subject must be a valid URI")
     (check       . "Parse subject as URI")
     (message     . "subject must be valid URI: ~a"))

    ((id          . webfinger/links-array)
     (severity    . error)
     (applies-to  . webfinger)
     (description . "links must be an array if present")
     (check       . "Check links field type")
     (message     . "links must be an array"))

    ((id          . webfinger/link-rel-required)
     (severity    . error)
     (applies-to  . webfinger)
     (description . "Each link must have a rel attribute")
     (check       . "Check each link object for rel")
     (message     . "Link missing required rel attribute"))))

;;;; ============================================================
;;;; ASSET LINKS RULES (Android)
;;;; ============================================================

(define assetlinks-rules
  '(((id          . assetlinks/array-root)
     (severity    . error)
     (applies-to  . assetlinks)
     (description . "Root must be a JSON array")
     (check       . "Check JSON root type is array")
     (message     . "assetlinks.json root must be an array"))

    ((id          . assetlinks/relation-required)
     (severity    . error)
     (applies-to  . assetlinks)
     (description . "Each entry must have relation array")
     (check       . "Check for relation key in each entry")
     (message     . "Entry missing required relation field"))

    ((id          . assetlinks/target-required)
     (severity    . error)
     (applies-to  . assetlinks)
     (description . "Each entry must have target object")
     (check       . "Check for target key in each entry")
     (message     . "Entry missing required target field"))

    ((id          . assetlinks/target-namespace)
     (severity    . error)
     (applies-to  . assetlinks)
     (description . "target must have namespace field")
     (check       . "Check target object for namespace")
     (message     . "target missing required namespace field"))

    ((id          . assetlinks/android-package)
     (severity    . error)
     (applies-to  . assetlinks)
     (description . "Android target must have package_name")
     (check       . "Check android_app target for package_name")
     (message     . "Android target missing package_name"))

    ((id          . assetlinks/sha256-fingerprints)
     (severity    . error)
     (applies-to  . assetlinks)
     (description . "Android target must have sha256_cert_fingerprints")
     (check       . "Check android_app target for fingerprints")
     (message     . "Android target missing sha256_cert_fingerprints"))))

;;;; ============================================================
;;;; APPLE APP SITE ASSOCIATION RULES
;;;; ============================================================

(define apple-app-site-association-rules
  '(((id          . aasa/object-root)
     (severity    . error)
     (applies-to  . apple-app-site-association)
     (description . "Root must be a JSON object")
     (check       . "Check JSON root type is object")
     (message     . "apple-app-site-association root must be an object"))

    ((id          . aasa/has-section)
     (severity    . error)
     (applies-to  . apple-app-site-association)
     (description . "Must have at least one recognized section")
     (check       . "Check for applinks, webcredentials, or appclips")
     (message     . "Must contain applinks, webcredentials, or appclips"))

    ((id          . aasa/applinks-apps-empty)
     (severity    . warning)
     (applies-to  . apple-app-site-association)
     (description . "applinks.apps should be empty array for new format")
     (check       . "Check applinks.apps is []")
     (message     . "applinks.apps should be empty array"))

    ((id          . aasa/applinks-details)
     (severity    . error)
     (applies-to  . apple-app-site-association)
     (description . "applinks must have details array")
     (check       . "Check for applinks.details array")
     (message     . "applinks missing details array"))

    ((id          . aasa/appid-format)
     (severity    . error)
     (applies-to  . apple-app-site-association)
     (description . "appID must be TeamID.BundleID format")
     (check       . "Validate appID format")
     (pattern     . "^[A-Z0-9]{10}\\.[a-zA-Z0-9.-]+$")
     (message     . "Invalid appID format: ~a"))))

;;;; ============================================================
;;;; NODEINFO RULES
;;;; ============================================================

(define nodeinfo-rules
  '(((id          . nodeinfo/version-required)
     (severity    . error)
     (applies-to  . nodeinfo)
     (description . "version field is required")
     (check       . "Check for version key")
     (message     . "Missing required field: version"))

    ((id          . nodeinfo/version-valid)
     (severity    . error)
     (applies-to  . nodeinfo)
     (description . "version must be 2.0, 2.1, or 2.2")
     (check       . "Validate version value")
     (allowed     . ("2.0" "2.1" "2.2"))
     (message     . "Invalid version: ~a (must be 2.0, 2.1, or 2.2)"))

    ((id          . nodeinfo/software-required)
     (severity    . error)
     (applies-to  . nodeinfo)
     (description . "software object is required")
     (check       . "Check for software key")
     (message     . "Missing required field: software"))

    ((id          . nodeinfo/software-name)
     (severity    . error)
     (applies-to  . nodeinfo)
     (description . "software.name is required")
     (check       . "Check for software.name")
     (message     . "Missing required field: software.name"))

    ((id          . nodeinfo/protocols-required)
     (severity    . error)
     (applies-to  . nodeinfo)
     (description . "protocols array is required")
     (check       . "Check for protocols key")
     (message     . "Missing required field: protocols"))

    ((id          . nodeinfo/usage-required)
     (severity    . error)
     (applies-to  . nodeinfo)
     (description . "usage object is required")
     (check       . "Check for usage key")
     (message     . "Missing required field: usage"))))

;;;; ============================================================
;;;; AGGREGATE ALL RULES
;;;; ============================================================

(define all-rules
  (append core-rules
          security-txt-rules
          openid-configuration-rules
          json-resource-rules
          webfinger-rules
          assetlinks-rules
          apple-app-site-association-rules
          nodeinfo-rules))

(define (get-rules-for-resource resource-type)
  "Get all applicable rules for a resource type."
  (filter
   (lambda (rule)
     (let ((applies-to (assoc-ref rule 'applies-to)))
       (or (eq? applies-to 'all)
           (eq? applies-to resource-type)
           (and (list? applies-to)
                (member resource-type applies-to)))))
   all-rules))

(define (get-rules-by-severity severity)
  "Get all rules with a specific severity level."
  (filter
   (lambda (rule)
     (eq? (assoc-ref rule 'severity) severity))
   all-rules))

;; End of validation rules
