// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LOL i18n Service — V-lang FFI Bindings
//
// Raw C function declarations that link against liblol (the Zig FFI).
// These are not intended for direct use; the public API in lol.v wraps
// them with idiomatic V types and error handling.

module lol

// C struct types (opaque pointers in V)
struct C.lol_locale_t {
	tag      &char
	language &char
	script   &char
	region   &char
}

struct C.lol_translation_result_t {
	text            &char
	resolved_locale &char
	is_fallback     u32
	_padding        u32
}

struct C.lol_language_info_t {
	iso639_3     &char
	name         &char
	native_name  &char
	family       &char
	scripts      &char
	source_count u32
	verse_count  u32
	quality      f64
}

struct C.lol_plural_rule_t {
	language   &char
	form_count u32
	categories [6]u32
	_padding   u32
}

// Lifecycle
fn C.lol_init(data_dir &char) voidptr
fn C.lol_free(handle voidptr)
fn C.lol_is_initialized(handle voidptr) u32

// Locale resolution
fn C.lol_resolve_locale(handle voidptr, tag &char) &C.lol_locale_t
fn C.lol_free_locale(locale &C.lol_locale_t)

// Translation
fn C.lol_translate(handle voidptr, locale_tag &char, key &char) &C.lol_translation_result_t
fn C.lol_free_translation(result &C.lol_translation_result_t)
fn C.lol_translation_text(result &C.lol_translation_result_t) &char

// Plural
fn C.lol_select_plural(handle voidptr, locale_tag &char, quantity u64) u32
fn C.lol_translate_plural(handle voidptr, locale_tag &char, key &char, quantity u64) &C.lol_translation_result_t

// Language metadata
fn C.lol_language_count(handle voidptr) u32
fn C.lol_get_language(handle voidptr, code &char) &C.lol_language_info_t
fn C.lol_free_language(info &C.lol_language_info_t)

// Plural rules
fn C.lol_get_plural_rule(handle voidptr, lang_code &char) &C.lol_plural_rule_t
fn C.lol_free_plural_rule(rule &C.lol_plural_rule_t)

// Fallback chain
fn C.lol_fallback_chain_len(handle voidptr, locale_tag &char) u32

// Error handling
fn C.lol_last_error() &char

// Version
fn C.lol_version() &char
fn C.lol_build_info() &char

// --- Internal helpers ---

// c_str_to_v converts a C null-terminated string to a V string.
// Returns empty string if the pointer is null.
fn c_str_to_v(ptr &char) string {
	if ptr == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(ptr) }
}
