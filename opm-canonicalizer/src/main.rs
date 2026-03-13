use serde::de::{self, Deserialize, Deserializer, MapAccess, SeqAccess, Visitor};
use std::collections::BTreeMap;
use std::fmt;
use std::io::{self, Read};

#[derive(Debug, Clone, PartialEq)]
enum JValue {
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

fn emit_canonical(value: &JValue, out: &mut String) {
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

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut input = String::new();
    io::stdin().read_to_string(&mut input)?;
    let mut deserializer = serde_json::Deserializer::from_str(&input);
    let value = JValue::deserialize(&mut deserializer)?;

    let mut out = String::new();
    emit_canonical(&value, &mut out);
    println!("{out}");
    Ok(())
}
