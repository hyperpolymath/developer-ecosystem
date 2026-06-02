// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// lib.rs — Public API for opm-canonicalizer.
// Exposes JSON canonicalization as a library for testing and reuse.

#![forbid(unsafe_code)]

use serde::de::{self, Deserialize, Deserializer, MapAccess, SeqAccess, Visitor};
use std::collections::BTreeMap;
use std::fmt;

/// A JSON value that forbids floating-point numbers and duplicate object keys.
/// Keys in objects are canonically sorted (BTreeMap provides lexicographic order).
#[derive(Debug, Clone, PartialEq)]
pub enum JValue {
    Null,
    Bool(bool),
    Number(String),
    String(String),
    Array(Vec<JValue>),
    Object(BTreeMap<String, JValue>),
}

impl<'de> Deserialize<'de> for JValue {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        deserializer.deserialize_any(JValueVisitor)
    }
}

struct JValueVisitor;

impl<'de> Visitor<'de> for JValueVisitor {
    type Value = JValue;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a valid JSON value")
    }

    fn visit_bool<E>(self, v: bool) -> Result<Self::Value, E> {
        Ok(JValue::Bool(v))
    }

    fn visit_i64<E>(self, v: i64) -> Result<Self::Value, E> {
        Ok(JValue::Number(v.to_string()))
    }

    fn visit_u64<E>(self, v: u64) -> Result<Self::Value, E> {
        Ok(JValue::Number(v.to_string()))
    }

    fn visit_f64<E>(self, _v: f64) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        Err(E::custom("floating point numbers are not allowed"))
    }

    fn visit_str<E>(self, v: &str) -> Result<Self::Value, E> {
        Ok(JValue::String(v.to_string()))
    }

    fn visit_string<E>(self, v: String) -> Result<Self::Value, E> {
        Ok(JValue::String(v))
    }

    fn visit_none<E>(self) -> Result<Self::Value, E> {
        Ok(JValue::Null)
    }

    fn visit_unit<E>(self) -> Result<Self::Value, E> {
        Ok(JValue::Null)
    }

    fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
    where
        A: SeqAccess<'de>,
    {
        let mut values = Vec::new();
        while let Some(v) = seq.next_element::<JValue>()? {
            values.push(v);
        }
        Ok(JValue::Array(values))
    }

    fn visit_map<A>(self, mut map: A) -> Result<Self::Value, A::Error>
    where
        A: MapAccess<'de>,
    {
        let mut values = BTreeMap::new();
        while let Some((k, v)) = map.next_entry::<String, JValue>()? {
            if values.contains_key(&k) {
                return Err(de::Error::custom("duplicate object key"));
            }
            values.insert(k, v);
        }
        Ok(JValue::Object(values))
    }
}

/// Emit a canonical JSON string from a JValue.
/// Canonical form: no whitespace, keys sorted lexicographically, no float numbers.
pub fn emit_canonical(value: &JValue, out: &mut String) {
    match value {
        JValue::Null => out.push_str("null"),
        JValue::Bool(true) => out.push_str("true"),
        JValue::Bool(false) => out.push_str("false"),
        JValue::Number(n) => out.push_str(n),
        JValue::String(s) => {
            out.push('"');
            for c in s.chars() {
                match c {
                    '"' => out.push_str("\\\""),
                    '\\' => out.push_str("\\\\"),
                    '\n' => out.push_str("\\n"),
                    '\r' => out.push_str("\\r"),
                    '\t' => out.push_str("\\t"),
                    '\u{08}' => out.push_str("\\b"),
                    '\u{0C}' => out.push_str("\\f"),
                    c if c <= '\u{1F}' => {
                        out.push_str(&format!("\\u{:04x}", c as u32));
                    }
                    _ => out.push(c),
                }
            }
            out.push('"');
        }
        JValue::Array(items) => {
            out.push('[');
            for (i, v) in items.iter().enumerate() {
                if i != 0 {
                    out.push(',');
                }
                emit_canonical(v, out);
            }
            out.push(']');
        }
        JValue::Object(map) => {
            out.push('{');
            for (i, (k, v)) in map.iter().enumerate() {
                if i != 0 {
                    out.push(',');
                }
                emit_canonical(&JValue::String(k.clone()), out);
                out.push(':');
                emit_canonical(v, out);
            }
            out.push('}');
        }
    }
}

/// Parse a JSON string and return the canonical representation, or an error.
pub fn canonicalize(input: &str) -> Result<String, String> {
    let mut deserializer = serde_json::Deserializer::from_str(input);
    let value =
        JValue::deserialize(&mut deserializer).map_err(|e| e.to_string())?;
    let mut out = String::new();
    emit_canonical(&value, &mut out);
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    // ===== Unit tests =====

    #[test]
    fn test_null() {
        assert_eq!(canonicalize("null").expect("TODO: handle error"), "null");
    }

    #[test]
    fn test_bool_true() {
        assert_eq!(canonicalize("true").expect("TODO: handle error"), "true");
    }

    #[test]
    fn test_bool_false() {
        assert_eq!(canonicalize("false").expect("TODO: handle error"), "false");
    }

    #[test]
    fn test_integer() {
        assert_eq!(canonicalize("42").expect("TODO: handle error"), "42");
    }

    #[test]
    fn test_string_basic() {
        assert_eq!(canonicalize(r#""hello""#).expect("TODO: handle error"), r#""hello""#);
    }

    #[test]
    fn test_empty_object() {
        assert_eq!(canonicalize("{}").expect("TODO: handle error"), "{}");
    }

    #[test]
    fn test_empty_array() {
        assert_eq!(canonicalize("[]").expect("TODO: handle error"), "[]");
    }

    #[test]
    fn test_object_keys_sorted() {
        // Keys must be lexicographically sorted in canonical output
        let input = r#"{"z":1,"a":2,"m":3}"#;
        assert_eq!(canonicalize(input).expect("TODO: handle error"), r#"{"a":2,"m":3,"z":1}"#);
    }

    #[test]
    fn test_string_escape_newline() {
        assert_eq!(canonicalize("\"a\\nb\"").expect("TODO: handle error"), "\"a\\nb\"");
    }

    #[test]
    fn test_string_escape_tab() {
        assert_eq!(canonicalize("\"a\\tb\"").expect("TODO: handle error"), "\"a\\tb\"");
    }

    // ===== Smoke tests =====

    #[test]
    fn smoke_nested_structure() {
        let input = r#"{"b":{"d":4,"c":3},"a":[1,2,3]}"#;
        let out = canonicalize(input).expect("TODO: handle error");
        // 'a' before 'b', nested object 'c' before 'd'
        assert_eq!(out, r#"{"a":[1,2,3],"b":{"c":3,"d":4}}"#);
    }

    #[test]
    fn smoke_float_rejected() {
        assert!(canonicalize("3.14").is_err());
    }

    #[test]
    fn smoke_duplicate_key_rejected() {
        assert!(canonicalize(r#"{"a":1,"a":2}"#).is_err());
    }

    // ===== E2E / reflexive tests =====

    #[test]
    fn e2e_canonicalize_twice_is_idempotent() {
        // Canonical form of canonical form is the same canonical form
        let input = r#"{"z":"last","a":"first","m":[3,1,2]}"#;
        let once = canonicalize(input).expect("TODO: handle error");
        let twice = canonicalize(&once).expect("TODO: handle error");
        assert_eq!(once, twice);
    }

    #[test]
    fn e2e_whitespace_stripped() {
        let pretty = r#"{
  "b": 2,
  "a": 1
}"#;
        let compact = r#"{"a":1,"b":2}"#;
        assert_eq!(canonicalize(pretty).expect("TODO: handle error"), compact);
    }

    // ===== Contract tests =====

    #[test]
    fn contract_output_has_no_whitespace() {
        let input = r#"{"x": [1, 2, 3], "y": "hello"}"#;
        let out = canonicalize(input).expect("TODO: handle error");
        assert!(!out.contains(' '));
        assert!(!out.contains('\n'));
        assert!(!out.contains('\t'));
    }

    #[test]
    fn contract_negative_integer_preserved() {
        assert_eq!(canonicalize("-99").expect("TODO: handle error"), "-99");
    }

    #[test]
    fn contract_zero_preserved() {
        assert_eq!(canonicalize("0").expect("TODO: handle error"), "0");
    }

    // ===== Aspect tests (security / correctness) =====

    #[test]
    fn aspect_empty_string_value() {
        assert_eq!(canonicalize(r#""""#).expect("TODO: handle error"), r#""""#);
    }

    #[test]
    fn aspect_unicode_control_chars_escaped() {
        // \u0001 (SOH) must be escaped in canonical output
        let input = "\"\\u0001\"";
        let out = canonicalize(input).expect("TODO: handle error");
        assert!(out.contains("\\u0001"));
    }

    #[test]
    fn aspect_deeply_nested_no_panic() {
        // 50 levels of nesting must not panic
        let mut s = String::new();
        for _ in 0..50 {
            s.push('[');
        }
        s.push_str("null");
        for _ in 0..50 {
            s.push(']');
        }
        assert!(canonicalize(&s).is_ok());
    }

    #[test]
    fn aspect_malformed_input_returns_err() {
        assert!(canonicalize("{invalid}").is_err());
        assert!(canonicalize("").is_err());
    }
}
