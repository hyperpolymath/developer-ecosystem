// SPDX-License-Identifier: MPL-2.0
//! WASM codec library for ReScript protobuf support
//!
//! This library provides protobuf binary encoding/decoding functions
//! that are called from ReScript via wasm-bindgen.
//!
//! The codec uses JSON as an intermediate format:
//! - ReScript passes JSON to encode functions
//! - WASM returns base64-encoded protobuf binary
//! - For decoding, WASM receives base64 binary and returns JSON

use integer_encoding::{VarInt, VarIntWriter};
use serde_json::{Map, Value};
use std::io::Write;
use wasm_bindgen::prelude::*;

// ============================================================================
// Wire Types (protobuf encoding)
// ============================================================================

const WIRE_VARINT: u32 = 0;
const WIRE_FIXED64: u32 = 1;
const WIRE_LEN: u32 = 2;
const WIRE_FIXED32: u32 = 5;

// ============================================================================
// Protobuf Encoder
// ============================================================================

struct ProtoEncoder {
    buf: Vec<u8>,
}

impl ProtoEncoder {
    fn new() -> Self {
        Self { buf: Vec::with_capacity(256) }
    }

    fn into_bytes(self) -> Vec<u8> {
        self.buf
    }

    fn write_tag(&mut self, field_number: u32, wire_type: u32) {
        let tag = (field_number << 3) | wire_type;
        self.buf.write_varint(tag).unwrap();
    }

    fn write_varint(&mut self, value: u64) {
        self.buf.write_varint(value).unwrap();
    }

    fn write_sint32(&mut self, value: i32) {
        // ZigZag encoding
        let encoded = ((value << 1) ^ (value >> 31)) as u32;
        self.write_varint(encoded as u64);
    }

    fn write_sint64(&mut self, value: i64) {
        // ZigZag encoding
        let encoded = ((value << 1) ^ (value >> 63)) as u64;
        self.write_varint(encoded);
    }

    fn write_fixed32(&mut self, value: u32) {
        self.buf.extend_from_slice(&value.to_le_bytes());
    }

    fn write_fixed64(&mut self, value: u64) {
        self.buf.extend_from_slice(&value.to_le_bytes());
    }

    fn write_float(&mut self, value: f32) {
        self.buf.extend_from_slice(&value.to_le_bytes());
    }

    fn write_double(&mut self, value: f64) {
        self.buf.extend_from_slice(&value.to_le_bytes());
    }

    fn write_bytes(&mut self, data: &[u8]) {
        self.buf.write_varint(data.len()).unwrap();
        self.buf.extend_from_slice(data);
    }

    fn write_string(&mut self, s: &str) {
        self.write_bytes(s.as_bytes());
    }

    fn write_bool(&mut self, value: bool) {
        self.write_varint(if value { 1 } else { 0 });
    }
}

// ============================================================================
// Protobuf Decoder
// ============================================================================

struct ProtoDecoder<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> ProtoDecoder<'a> {
    fn new(data: &'a [u8]) -> Self {
        Self { data, pos: 0 }
    }

    fn remaining(&self) -> usize {
        self.data.len() - self.pos
    }

    fn read_varint(&mut self) -> Result<u64, &'static str> {
        let mut result: u64 = 0;
        let mut shift = 0;

        loop {
            if self.pos >= self.data.len() {
                return Err("Unexpected end of input");
            }
            let byte = self.data[self.pos];
            self.pos += 1;

            result |= ((byte & 0x7f) as u64) << shift;

            if byte & 0x80 == 0 {
                return Ok(result);
            }

            shift += 7;
            if shift >= 64 {
                return Err("Varint too long");
            }
        }
    }

    fn read_tag(&mut self) -> Result<(u32, u32), &'static str> {
        if self.remaining() == 0 {
            return Err("End of data");
        }
        let tag = self.read_varint()? as u32;
        let field_number = tag >> 3;
        let wire_type = tag & 0x7;
        Ok((field_number, wire_type))
    }

    fn read_sint32(&mut self) -> Result<i32, &'static str> {
        let encoded = self.read_varint()? as u32;
        // ZigZag decoding
        Ok(((encoded >> 1) as i32) ^ (-((encoded & 1) as i32)))
    }

    fn read_sint64(&mut self) -> Result<i64, &'static str> {
        let encoded = self.read_varint()?;
        // ZigZag decoding
        Ok(((encoded >> 1) as i64) ^ (-((encoded & 1) as i64)))
    }

    fn read_fixed32(&mut self) -> Result<u32, &'static str> {
        if self.remaining() < 4 {
            return Err("Not enough data for fixed32");
        }
        let bytes: [u8; 4] = self.data[self.pos..self.pos + 4].try_into().unwrap();
        self.pos += 4;
        Ok(u32::from_le_bytes(bytes))
    }

    fn read_fixed64(&mut self) -> Result<u64, &'static str> {
        if self.remaining() < 8 {
            return Err("Not enough data for fixed64");
        }
        let bytes: [u8; 8] = self.data[self.pos..self.pos + 8].try_into().unwrap();
        self.pos += 8;
        Ok(u64::from_le_bytes(bytes))
    }

    fn read_float(&mut self) -> Result<f32, &'static str> {
        if self.remaining() < 4 {
            return Err("Not enough data for float");
        }
        let bytes: [u8; 4] = self.data[self.pos..self.pos + 4].try_into().unwrap();
        self.pos += 4;
        Ok(f32::from_le_bytes(bytes))
    }

    fn read_double(&mut self) -> Result<f64, &'static str> {
        if self.remaining() < 8 {
            return Err("Not enough data for double");
        }
        let bytes: [u8; 8] = self.data[self.pos..self.pos + 8].try_into().unwrap();
        self.pos += 8;
        Ok(f64::from_le_bytes(bytes))
    }

    fn read_bytes(&mut self) -> Result<Vec<u8>, &'static str> {
        let len = self.read_varint()? as usize;
        if self.remaining() < len {
            return Err("Not enough data for bytes");
        }
        let bytes = self.data[self.pos..self.pos + len].to_vec();
        self.pos += len;
        Ok(bytes)
    }

    fn read_string(&mut self) -> Result<String, &'static str> {
        let bytes = self.read_bytes()?;
        String::from_utf8(bytes).map_err(|_| "Invalid UTF-8")
    }

    fn read_bool(&mut self) -> Result<bool, &'static str> {
        Ok(self.read_varint()? != 0)
    }

    fn skip_field(&mut self, wire_type: u32) -> Result<(), &'static str> {
        match wire_type {
            WIRE_VARINT => {
                self.read_varint()?;
            }
            WIRE_FIXED64 => {
                self.pos += 8;
            }
            WIRE_LEN => {
                let len = self.read_varint()? as usize;
                self.pos += len;
            }
            WIRE_FIXED32 => {
                self.pos += 4;
            }
            _ => return Err("Unknown wire type"),
        }
        Ok(())
    }
}

// ============================================================================
// Schema-based encoding/decoding
// ============================================================================

/// Field descriptor for dynamic encoding
#[derive(Clone)]
pub struct FieldDescriptor {
    pub number: u32,
    pub name: String,
    pub field_type: FieldType,
    pub is_repeated: bool,
    pub is_optional: bool,
}

#[derive(Clone)]
pub enum FieldType {
    Int32,
    Int64,
    Uint32,
    Uint64,
    Sint32,
    Sint64,
    Fixed32,
    Fixed64,
    Sfixed32,
    Sfixed64,
    Float,
    Double,
    Bool,
    String,
    Bytes,
    Message(Vec<FieldDescriptor>), // nested message
    Enum,
}

/// Encode a JSON value to protobuf binary based on field descriptors
fn encode_message(fields: &[FieldDescriptor], json: &Map<String, Value>) -> Result<Vec<u8>, String> {
    let mut encoder = ProtoEncoder::new();

    for field in fields {
        let value = json.get(&field.name);

        if field.is_repeated {
            if let Some(Value::Array(arr)) = value {
                for item in arr {
                    encode_field(&mut encoder, field, item)?;
                }
            }
        } else if let Some(v) = value {
            if !v.is_null() {
                encode_field(&mut encoder, field, v)?;
            }
        }
    }

    Ok(encoder.into_bytes())
}

fn encode_field(encoder: &mut ProtoEncoder, field: &FieldDescriptor, value: &Value) -> Result<(), String> {
    match &field.field_type {
        FieldType::Int32 | FieldType::Uint32 | FieldType::Enum => {
            if let Some(n) = value.as_i64() {
                encoder.write_tag(field.number, WIRE_VARINT);
                encoder.write_varint(n as u64);
            }
        }
        FieldType::Int64 | FieldType::Uint64 => {
            // Handle as string for bigint
            if let Some(s) = value.as_str() {
                let n: i64 = s.parse().map_err(|_| "Invalid int64")?;
                encoder.write_tag(field.number, WIRE_VARINT);
                encoder.write_varint(n as u64);
            } else if let Some(n) = value.as_i64() {
                encoder.write_tag(field.number, WIRE_VARINT);
                encoder.write_varint(n as u64);
            }
        }
        FieldType::Sint32 => {
            if let Some(n) = value.as_i64() {
                encoder.write_tag(field.number, WIRE_VARINT);
                encoder.write_sint32(n as i32);
            }
        }
        FieldType::Sint64 => {
            if let Some(s) = value.as_str() {
                let n: i64 = s.parse().map_err(|_| "Invalid sint64")?;
                encoder.write_tag(field.number, WIRE_VARINT);
                encoder.write_sint64(n);
            }
        }
        FieldType::Fixed32 | FieldType::Sfixed32 => {
            if let Some(n) = value.as_i64() {
                encoder.write_tag(field.number, WIRE_FIXED32);
                encoder.write_fixed32(n as u32);
            }
        }
        FieldType::Fixed64 | FieldType::Sfixed64 => {
            if let Some(s) = value.as_str() {
                let n: u64 = s.parse().map_err(|_| "Invalid fixed64")?;
                encoder.write_tag(field.number, WIRE_FIXED64);
                encoder.write_fixed64(n);
            }
        }
        FieldType::Float => {
            if let Some(n) = value.as_f64() {
                encoder.write_tag(field.number, WIRE_FIXED32);
                encoder.write_float(n as f32);
            }
        }
        FieldType::Double => {
            if let Some(n) = value.as_f64() {
                encoder.write_tag(field.number, WIRE_FIXED64);
                encoder.write_double(n);
            }
        }
        FieldType::Bool => {
            if let Some(b) = value.as_bool() {
                encoder.write_tag(field.number, WIRE_VARINT);
                encoder.write_bool(b);
            }
        }
        FieldType::String => {
            if let Some(s) = value.as_str() {
                encoder.write_tag(field.number, WIRE_LEN);
                encoder.write_string(s);
            }
        }
        FieldType::Bytes => {
            // Base64 encoded
            if let Some(s) = value.as_str() {
                let bytes = base64_decode(s)?;
                encoder.write_tag(field.number, WIRE_LEN);
                encoder.write_bytes(&bytes);
            }
        }
        FieldType::Message(nested_fields) => {
            if let Some(obj) = value.as_object() {
                let nested_bytes = encode_message(nested_fields, obj)?;
                encoder.write_tag(field.number, WIRE_LEN);
                encoder.write_bytes(&nested_bytes);
            }
        }
    }
    Ok(())
}

/// Decode protobuf binary to JSON based on field descriptors
fn decode_message(fields: &[FieldDescriptor], data: &[u8]) -> Result<Map<String, Value>, String> {
    let mut decoder = ProtoDecoder::new(data);
    let mut result = Map::new();

    // Initialize repeated fields
    for field in fields {
        if field.is_repeated {
            result.insert(field.name.clone(), Value::Array(Vec::new()));
        }
    }

    while decoder.remaining() > 0 {
        let (field_number, wire_type) = decoder.read_tag().map_err(|e| e.to_string())?;

        // Find field descriptor
        let field = fields.iter().find(|f| f.number == field_number);

        match field {
            Some(f) => {
                let value = decode_field(&mut decoder, f, wire_type)?;

                if f.is_repeated {
                    if let Some(Value::Array(arr)) = result.get_mut(&f.name) {
                        arr.push(value);
                    }
                } else {
                    result.insert(f.name.clone(), value);
                }
            }
            None => {
                // Skip unknown field
                decoder.skip_field(wire_type).map_err(|e| e.to_string())?;
            }
        }
    }

    Ok(result)
}

fn decode_field(decoder: &mut ProtoDecoder, field: &FieldDescriptor, wire_type: u32) -> Result<Value, String> {
    match &field.field_type {
        FieldType::Int32 | FieldType::Uint32 | FieldType::Enum => {
            let n = decoder.read_varint().map_err(|e| e.to_string())?;
            Ok(Value::Number(serde_json::Number::from(n as i64)))
        }
        FieldType::Int64 | FieldType::Uint64 => {
            let n = decoder.read_varint().map_err(|e| e.to_string())?;
            Ok(Value::String(n.to_string()))
        }
        FieldType::Sint32 => {
            let n = decoder.read_sint32().map_err(|e| e.to_string())?;
            Ok(Value::Number(serde_json::Number::from(n)))
        }
        FieldType::Sint64 => {
            let n = decoder.read_sint64().map_err(|e| e.to_string())?;
            Ok(Value::String(n.to_string()))
        }
        FieldType::Fixed32 | FieldType::Sfixed32 => {
            let n = decoder.read_fixed32().map_err(|e| e.to_string())?;
            Ok(Value::Number(serde_json::Number::from(n)))
        }
        FieldType::Fixed64 | FieldType::Sfixed64 => {
            let n = decoder.read_fixed64().map_err(|e| e.to_string())?;
            Ok(Value::String(n.to_string()))
        }
        FieldType::Float => {
            let n = decoder.read_float().map_err(|e| e.to_string())?;
            Ok(serde_json::Number::from_f64(n as f64)
                .map(Value::Number)
                .unwrap_or(Value::Null))
        }
        FieldType::Double => {
            let n = decoder.read_double().map_err(|e| e.to_string())?;
            Ok(serde_json::Number::from_f64(n)
                .map(Value::Number)
                .unwrap_or(Value::Null))
        }
        FieldType::Bool => {
            let b = decoder.read_bool().map_err(|e| e.to_string())?;
            Ok(Value::Bool(b))
        }
        FieldType::String => {
            let s = decoder.read_string().map_err(|e| e.to_string())?;
            Ok(Value::String(s))
        }
        FieldType::Bytes => {
            let bytes = decoder.read_bytes().map_err(|e| e.to_string())?;
            Ok(Value::String(base64_encode(&bytes)))
        }
        FieldType::Message(nested_fields) => {
            let bytes = decoder.read_bytes().map_err(|e| e.to_string())?;
            let obj = decode_message(nested_fields, &bytes)?;
            Ok(Value::Object(obj))
        }
    }
}

// ============================================================================
// Base64 encoding (simple implementation)
// ============================================================================

const BASE64_CHARS: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

fn base64_encode(data: &[u8]) -> String {
    let mut result = String::with_capacity((data.len() + 2) / 3 * 4);

    for chunk in data.chunks(3) {
        let b0 = chunk[0] as usize;
        let b1 = chunk.get(1).copied().unwrap_or(0) as usize;
        let b2 = chunk.get(2).copied().unwrap_or(0) as usize;

        result.push(BASE64_CHARS[b0 >> 2] as char);
        result.push(BASE64_CHARS[((b0 & 0x03) << 4) | (b1 >> 4)] as char);

        if chunk.len() > 1 {
            result.push(BASE64_CHARS[((b1 & 0x0f) << 2) | (b2 >> 6)] as char);
        } else {
            result.push('=');
        }

        if chunk.len() > 2 {
            result.push(BASE64_CHARS[b2 & 0x3f] as char);
        } else {
            result.push('=');
        }
    }

    result
}

fn base64_decode(s: &str) -> Result<Vec<u8>, String> {
    let mut result = Vec::new();
    let s = s.trim_end_matches('=');
    let bytes: Vec<u8> = s.bytes().collect();

    let decode_char = |c: u8| -> Result<u8, String> {
        match c {
            b'A'..=b'Z' => Ok(c - b'A'),
            b'a'..=b'z' => Ok(c - b'a' + 26),
            b'0'..=b'9' => Ok(c - b'0' + 52),
            b'+' => Ok(62),
            b'/' => Ok(63),
            _ => Err("Invalid base64 character".to_string()),
        }
    };

    for chunk in bytes.chunks(4) {
        if chunk.len() < 2 {
            break;
        }

        let b0 = decode_char(chunk[0])?;
        let b1 = decode_char(chunk[1])?;
        result.push((b0 << 2) | (b1 >> 4));

        if chunk.len() > 2 {
            let b2 = decode_char(chunk[2])?;
            result.push((b1 << 4) | (b2 >> 2));

            if chunk.len() > 3 {
                let b3 = decode_char(chunk[3])?;
                result.push((b2 << 6) | b3);
            }
        }
    }

    Ok(result)
}

// ============================================================================
// WASM Exports
// ============================================================================

/// Encode JSON to protobuf binary (returns base64)
///
/// The schema parameter is a JSON array of field descriptors:
/// [{"n": 1, "name": "field_name", "type": "string", "repeated": false}, ...]
#[wasm_bindgen]
pub fn encode(schema: &str, json_data: &str) -> Result<String, JsValue> {
    let fields = parse_schema(schema).map_err(|e| JsValue::from_str(&e))?;
    let json: Value = serde_json::from_str(json_data)
        .map_err(|e| JsValue::from_str(&format!("JSON parse error: {}", e)))?;

    let obj = json.as_object()
        .ok_or_else(|| JsValue::from_str("Expected JSON object"))?;

    let bytes = encode_message(&fields, obj)
        .map_err(|e| JsValue::from_str(&e))?;

    Ok(base64_encode(&bytes))
}

/// Decode protobuf binary (base64) to JSON
#[wasm_bindgen]
pub fn decode(schema: &str, base64_data: &str) -> Result<String, JsValue> {
    let fields = parse_schema(schema).map_err(|e| JsValue::from_str(&e))?;
    let bytes = base64_decode(base64_data)
        .map_err(|e| JsValue::from_str(&e))?;

    let obj = decode_message(&fields, &bytes)
        .map_err(|e| JsValue::from_str(&e))?;

    serde_json::to_string(&obj)
        .map_err(|e| JsValue::from_str(&format!("JSON serialize error: {}", e)))
}

/// Parse schema from JSON
fn parse_schema(schema: &str) -> Result<Vec<FieldDescriptor>, String> {
    let arr: Vec<Value> = serde_json::from_str(schema)
        .map_err(|e| format!("Schema parse error: {}", e))?;

    let mut fields = Vec::new();
    for item in arr {
        fields.push(parse_field_descriptor(&item)?);
    }
    Ok(fields)
}

fn parse_field_descriptor(v: &Value) -> Result<FieldDescriptor, String> {
    let obj = v.as_object().ok_or("Expected object in schema")?;

    let number = obj.get("n")
        .and_then(|v| v.as_u64())
        .ok_or("Missing field number 'n'")? as u32;

    let name = obj.get("name")
        .and_then(|v| v.as_str())
        .ok_or("Missing field name")?
        .to_string();

    let type_str = obj.get("type")
        .and_then(|v| v.as_str())
        .ok_or("Missing field type")?;

    let is_repeated = obj.get("repeated")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let is_optional = obj.get("optional")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let field_type = match type_str {
        "int32" => FieldType::Int32,
        "int64" => FieldType::Int64,
        "uint32" => FieldType::Uint32,
        "uint64" => FieldType::Uint64,
        "sint32" => FieldType::Sint32,
        "sint64" => FieldType::Sint64,
        "fixed32" => FieldType::Fixed32,
        "fixed64" => FieldType::Fixed64,
        "sfixed32" => FieldType::Sfixed32,
        "sfixed64" => FieldType::Sfixed64,
        "float" => FieldType::Float,
        "double" => FieldType::Double,
        "bool" => FieldType::Bool,
        "string" => FieldType::String,
        "bytes" => FieldType::Bytes,
        "enum" => FieldType::Enum,
        "message" => {
            let nested = obj.get("fields")
                .and_then(|v| v.as_array())
                .ok_or("Message type requires 'fields' array")?;
            let nested_fields: Result<Vec<_>, _> = nested.iter()
                .map(parse_field_descriptor)
                .collect();
            FieldType::Message(nested_fields?)
        }
        _ => return Err(format!("Unknown field type: {}", type_str)),
    };

    Ok(FieldDescriptor {
        number,
        name,
        field_type,
        is_repeated,
        is_optional,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encode_decode_simple() {
        let schema = r#"[
            {"n": 1, "name": "name", "type": "string"},
            {"n": 2, "name": "id", "type": "int32"}
        ]"#;

        let json = r#"{"name": "Alice", "id": 42}"#;

        let encoded = encode(schema, json).unwrap();
        let decoded = decode(schema, &encoded).unwrap();

        let original: Value = serde_json::from_str(json).unwrap();
        let result: Value = serde_json::from_str(&decoded).unwrap();

        assert_eq!(original["name"], result["name"]);
        assert_eq!(original["id"], result["id"]);
    }

    #[test]
    fn test_base64_roundtrip() {
        let data = b"Hello, World!";
        let encoded = base64_encode(data);
        let decoded = base64_decode(&encoded).unwrap();
        assert_eq!(data.to_vec(), decoded);
    }
}
