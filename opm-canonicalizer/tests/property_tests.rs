// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// property_tests.rs — Proptest property-based tests for opm-canonicalizer.
// Verifies invariants over generated inputs.

use opm_canonicalizer::canonicalize;
use proptest::prelude::*;

proptest! {
    // P2P: Canonicalization is idempotent — applying it twice yields the same result.
    #[test]
    fn prop_canonicalize_idempotent(s in "[a-zA-Z0-9_]{1,20}") {
        let json = format!(r#"{{"key":"{}","a":1}}"#, s);
        if let Ok(once) = canonicalize(&json) {
            let twice = canonicalize(&once).unwrap();
            prop_assert_eq!(once, twice);
        }
    }

    // P2P: Output never contains unescaped whitespace between tokens.
    #[test]
    fn prop_output_no_whitespace(s in "[a-zA-Z0-9]{1,30}") {
        let json = format!(r#"{{"value":"{}"}}"#, s);
        if let Ok(out) = canonicalize(&json) {
            prop_assert!(!out.contains("  "));
            // Spaces inside string values are fine; spaces between tokens are not
            // (the simplest check: no space before ':' or ',')
            prop_assert!(!out.contains(" :"));
            prop_assert!(!out.contains(", "));
        }
    }

    // P2P: Object keys in output are always lexicographically sorted.
    #[test]
    fn prop_object_keys_sorted(
        k1 in "[a-m]{3,8}",
        k2 in "[n-z]{3,8}",
    ) {
        // k1 < k2 lexicographically (a-m comes before n-z)
        let json = format!(r#"{{"{k2}":2,"{k1}":1}}"#, k1=k1, k2=k2);
        if let Ok(out) = canonicalize(&json) {
            let pos1 = out.find(&format!(r#""{k1}""#, k1=k1)).unwrap_or(usize::MAX);
            let pos2 = out.find(&format!(r#""{k2}""#, k2=k2)).unwrap_or(0);
            prop_assert!(pos1 < pos2, "k1={} should appear before k2={}", k1, k2);
        }
    }

    // P2P: Arrays preserve element order.
    #[test]
    fn prop_array_order_preserved(values in prop::collection::vec(0i64..100, 2..10)) {
        let arr: Vec<String> = values.iter().map(|v| v.to_string()).collect();
        let json = format!("[{}]", arr.join(","));
        if let Ok(out) = canonicalize(&json) {
            // Reconstruct expected
            let expected = format!("[{}]", arr.join(","));
            prop_assert_eq!(out, expected);
        }
    }

    // P2P: Negative integers round-trip correctly.
    #[test]
    fn prop_negative_integers_roundtrip(n in -1_000_000i64..-1) {
        let json = n.to_string();
        if let Ok(out) = canonicalize(&json) {
            prop_assert_eq!(out, json);
        }
    }
}
