;; SPDX-License-Identifier: PMPL-1.0-or-later
;; aLib Conformance Test Specification Format
;;
;; This file documents the conformance test format and validation rules

(define-conformance-spec alib-conformance
  (version "1.0.0")

  (purpose
    "Define how to validate language implementations against aLib specifications")

  (test-case-format
    (required-fields
      (input "Array of input values matching operation signature")
      (output "Expected output value")
      (description "Human-readable description of what is being tested"))

    (optional-fields
      (skip-for "List of languages that should skip this test")
      (note "Additional context or implementation notes")))

  (validation-rules
    (rule-1 "Implementation must produce exact output for given inputs")
    (rule-2 "Type coercion is allowed if semantically equivalent")
    (rule-3 "Exceptions/errors must match expected behavior")
    (rule-4 "Performance is NOT validated (only correctness)"))

  (language-bindings
    (oblibeny
      (runner "oblibeny CLI with test wrapper")
      (type-mapping
        (Number . "i64")
        (Boolean . "bool")
        (String . "custom type (not yet implemented)")
        (Collection . "array type (not yet implemented)")))

    (wokelang
      (runner "wokelang test harness")
      (type-mapping
        (Number . "EmotionalNumber")
        (Boolean . "ConsentBool")))

    (eclexia
      (runner "eclexia sustainability test")
      (type-mapping
        (Number . "EnergyTrackedNumber")
        (Boolean . "bool"))))

  (reporting-format
    (summary
      "operation, test_count, passed, failed, skipped")
    (detail
      "test_description, status, actual_output, expected_output, error_message")))
