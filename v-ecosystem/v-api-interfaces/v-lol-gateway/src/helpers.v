// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Shared utility functions for the LOL triple API gateway.
//
// JSON response builders, string escaping, minimal JSON field extraction,
// and serialisation helpers used across REST, gRPC, and GraphQL handlers.

module main

import net.http

// --- HTTP response builders ---

// json_response builds an HTTP response with JSON content type.
fn json_response(status_code int, body string) http.Response {
	return http.new_response(
		status: http.Status.from_int(status_code)
		header: http.new_header(key: .content_type, value: 'application/json')
		body: body
	)
}

// grpc_response builds an HTTP response with gRPC-Web JSON content type.
fn grpc_response(status_code int, body string) http.Response {
	return http.new_response(
		status: http.Status.from_int(status_code)
		header: http.new_header(key: .content_type, value: 'application/grpc-web+json')
		body: body
	)
}

// --- String escaping ---

// esc escapes a string for safe embedding in JSON values.
// Handles backslashes, double quotes, newlines, tabs, and carriage returns.
fn esc(s string) string {
	mut out := []u8{}
	for c in s.bytes() {
		match c {
			`\\` { out << `\\`; out << `\\` }
			`"` { out << `\\`; out << `"` }
			`\n` { out << `\\`; out << `n` }
			`\r` { out << `\\`; out << `r` }
			`\t` { out << `\\`; out << `t` }
			else { out << c }
		}
	}
	return out.bytestr()
}

// --- Minimal JSON field extraction ---
// These avoid pulling in a full JSON parser. They handle flat JSON objects
// with string, integer, and float values — sufficient for our metadata files.

// json_field extracts a string value for a given key from a JSON string.
// Returns empty string if the key is not found.
fn json_field(data string, key string) string {
	needle := '"${key}"'
	idx := data.index(needle) or { return '' }
	rest := data[idx + needle.len..]

	// Skip whitespace and colon.
	colon := rest.index(':') or { return '' }
	after_colon := rest[colon + 1..].trim_left(' \t\n\r')

	if after_colon.len == 0 {
		return ''
	}

	// String value (starts with quote).
	if after_colon[0] == `"` {
		end := after_colon[1..].index('"') or { return '' }
		return after_colon[1..end + 1]
	}

	// Non-string value — return up to next comma, brace, or bracket.
	mut end := after_colon.len
	for i, c in after_colon.bytes() {
		if c in [`,`, `}`, `]`, `\n`] {
			end = i
			break
		}
	}
	return after_colon[..end].trim_space()
}

// json_field_or extracts a string value, returning default_val if not found.
fn json_field_or(data string, key string, default_val string) string {
	val := json_field(data, key)
	return if val.len > 0 { val } else { default_val }
}

// json_int_field extracts an integer value for a given key.
// Returns 0 if the key is not found or cannot be parsed.
fn json_int_field(data string, key string) int {
	val := json_field(data, key)
	if val.len == 0 {
		return 0
	}
	return val.int()
}

// json_float_field extracts a float value for a given key.
// Returns 0.0 if the key is not found or cannot be parsed.
fn json_float_field(data string, key string) f64 {
	val := json_field(data, key)
	if val.len == 0 {
		return 0.0
	}
	return val.f64()
}

// --- Serialisation helpers ---

// language_to_json serialises a LanguageInfo struct to a JSON object string.
fn language_to_json(lang LanguageInfo) string {
	return '{' +
		'"iso639_3":"${esc(lang.iso639_3)}",' +
		'"name":"${esc(lang.name)}",' +
		'"nativeName":"${esc(lang.native_name)}",' +
		'"family":"${esc(lang.family)}",' +
		'"scripts":"${esc(lang.scripts)}",' +
		'"sources":${lang.sources},' +
		'"verses":${lang.verses},' +
		'"quality":${lang.quality}' +
		'}'
}

// --- GraphQL argument extraction ---

// extract_arg extracts a named argument value from a GraphQL query string.
// Handles both `code: "eng"` and `code: "eng"` patterns.
fn extract_arg(query string, arg_name string) string {
	// Look for the argument name followed by colon.
	needle := '${arg_name}:'
	mut idx := query.index(needle) or {
		// Try with space before colon.
		needle2 := '${arg_name} :'
		query.index(needle2) or { return '' }
	}

	rest := query[idx..]
	// Find the opening quote.
	quote_start := rest.index('"') or { return '' }
	after_quote := rest[quote_start + 1..]
	// Find the closing quote (handle escaped quotes).
	mut end := 0
	for i, c in after_quote.bytes() {
		if c == `"` {
			end = i
			break
		}
	}
	if end == 0 && after_quote.len > 0 && after_quote[0] != `"` {
		return ''
	}
	return after_quote[..end]
}
