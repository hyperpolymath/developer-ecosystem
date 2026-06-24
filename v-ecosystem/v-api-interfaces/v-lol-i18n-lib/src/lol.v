// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LOL i18n Service — V-lang Public API
//
// Idiomatic V wrapper around the LOL Zig FFI (liblol). This module
// is the primary interface for V programs that need i18n services.
//
// LOL is always called as a service, never embedded. Create a Service
// instance with lol.open(), perform translation lookups, and close
// when done.
//
// Usage:
//   import lol
//
//   fn main() {
//       mut svc := lol.open('corpus') or { panic(err) }
//       defer svc.close()
//
//       text := svc.translate('en-US', 'greeting') or { 'Hello!' }
//       println(text.text)
//
//       cat := svc.select_plural('ar', 5)
//       println('Arabic plural for 5: ${cat}')
//   }

module lol

#flag -llol
#include "lol.h"

// Service is the primary interface to the LOL i18n service.
// It wraps an opaque handle to the C library and provides
// idiomatic V methods for all service operations.
pub struct Service {
mut:
	handle voidptr
}

// open creates a new LOL service instance, loading corpus data
// from the given directory. Returns an error if initialisation fails.
pub fn open(data_dir string) !Service {
	handle := C.lol_init(data_dir.str)
	if handle == unsafe { nil } {
		err_msg := c_str_to_v(C.lol_last_error())
		return error(if err_msg.len > 0 { err_msg } else { 'Failed to initialise LOL service' })
	}
	return Service{
		handle: handle
	}
}

// open_default creates a LOL service with the default corpus directory.
pub fn open_default() !Service {
	return open('corpus')
}

// close releases all resources held by the service.
// Safe to call multiple times.
pub fn (mut s Service) close() {
	if s.handle != unsafe { nil } {
		C.lol_free(s.handle)
		s.handle = unsafe { nil }
	}
}

// is_initialized returns true if the service handle is valid and ready.
pub fn (s &Service) is_initialized() bool {
	if s.handle == unsafe { nil } {
		return false
	}
	return C.lol_is_initialized(s.handle) == 1
}

// --- Locale Resolution ---

// resolve_locale parses a BCP 47 locale tag and resolves it against
// the corpus. Returns a Locale with the parsed components.
pub fn (s &Service) resolve_locale(tag string) !Locale {
	raw := C.lol_resolve_locale(s.handle, tag.str)
	if raw == unsafe { nil } {
		return error('Failed to resolve locale: ${tag}')
	}
	defer {
		C.lol_free_locale(raw)
	}

	return Locale{
		tag: c_str_to_v(raw.tag)
		language: c_str_to_v(raw.language)
		script: c_str_to_v(raw.script)
		region: c_str_to_v(raw.region)
	}
}

// --- Translation ---

// translate looks up a translation key for the given locale tag.
// If the exact locale is not available and fallback is enabled,
// the service walks the fallback chain (e.g. en-US -> en -> default).
pub fn (s &Service) translate(locale_tag string, key string) !TranslationResult {
	raw := C.lol_translate(s.handle, locale_tag.str, key.str)
	if raw == unsafe { nil } {
		err_msg := c_str_to_v(C.lol_last_error())
		return error(if err_msg.len > 0 { err_msg } else { 'Translation not found: ${key}' })
	}
	defer {
		C.lol_free_translation(raw)
	}

	return TranslationResult{
		text: c_str_to_v(raw.text)
		resolved_locale: c_str_to_v(raw.resolved_locale)
		is_fallback: raw.is_fallback != 0
	}
}

// translate_plural combines plural form selection with translation
// lookup. The quantity determines the CLDR plural category, which
// is appended to the key as a suffix (e.g. "items" -> "items.one").
pub fn (s &Service) translate_plural(locale_tag string, key string, quantity u64) !TranslationResult {
	raw := C.lol_translate_plural(s.handle, locale_tag.str, key.str, quantity)
	if raw == unsafe { nil } {
		err_msg := c_str_to_v(C.lol_last_error())
		return error(if err_msg.len > 0 { err_msg } else { 'Plural translation not found: ${key}' })
	}
	defer {
		C.lol_free_translation(raw)
	}

	return TranslationResult{
		text: c_str_to_v(raw.text)
		resolved_locale: c_str_to_v(raw.resolved_locale)
		is_fallback: raw.is_fallback != 0
	}
}

// --- Plural Selection ---

// select_plural returns the CLDR plural category that should be
// used for the given quantity in the specified locale.
pub fn (s &Service) select_plural(locale_tag string, quantity u64) PluralCategory {
	raw := C.lol_select_plural(s.handle, locale_tag.str, quantity)
	return match raw {
		0 { PluralCategory.zero }
		1 { PluralCategory.one }
		2 { PluralCategory.two }
		3 { PluralCategory.few }
		4 { PluralCategory.many }
		else { PluralCategory.other }
	}
}

// --- Language Metadata ---

// language_count returns the number of languages available in the corpus.
pub fn (s &Service) language_count() int {
	return int(C.lol_language_count(s.handle))
}

// get_language looks up metadata for a specific language by its
// ISO 639-3 code (e.g. "eng", "deu", "fra").
pub fn (s &Service) get_language(code string) !LanguageInfo {
	raw := C.lol_get_language(s.handle, code.str)
	if raw == unsafe { nil } {
		return error('Language not found: ${code}')
	}
	defer {
		C.lol_free_language(raw)
	}

	return LanguageInfo{
		iso639_3: c_str_to_v(raw.iso639_3)
		name: c_str_to_v(raw.name)
		native_name: c_str_to_v(raw.native_name)
		family: c_str_to_v(raw.family)
		scripts: c_str_to_v(raw.scripts)
		source_count: int(raw.source_count)
		verse_count: int(raw.verse_count)
		quality: raw.quality
	}
}

// --- Plural Rules ---

// get_plural_rule retrieves the CLDR plural rule for a language,
// including how many forms it has and which categories it uses.
pub fn (s &Service) get_plural_rule(lang_code string) !PluralRule {
	raw := C.lol_get_plural_rule(s.handle, lang_code.str)
	if raw == unsafe { nil } {
		return error('Plural rule not found for: ${lang_code}')
	}
	defer {
		C.lol_free_plural_rule(raw)
	}

	count := int(raw.form_count)
	mut cats := []PluralCategory{cap: count}
	for i in 0 .. count {
		cats << match raw.categories[i] {
			0 { PluralCategory.zero }
			1 { PluralCategory.one }
			2 { PluralCategory.two }
			3 { PluralCategory.few }
			4 { PluralCategory.many }
			else { PluralCategory.other }
		}
	}

	return PluralRule{
		language: c_str_to_v(raw.language)
		form_count: count
		categories: cats
	}
}

// --- Fallback Chain ---

// fallback_chain_length returns the number of locales in the
// fallback chain for a given tag. For "en-GB" this is typically 3:
// en-GB, en, default.
pub fn (s &Service) fallback_chain_length(locale_tag string) int {
	return int(C.lol_fallback_chain_len(s.handle, locale_tag.str))
}

// --- Error and Version ---

// last_error returns the most recent error message from the service,
// or an empty string if there is no error.
pub fn last_error() string {
	return c_str_to_v(C.lol_last_error())
}

// version returns the LOL library version string.
pub fn version() string {
	return c_str_to_v(C.lol_version())
}

// build_info returns the LOL library build information string.
pub fn build_info() string {
	return c_str_to_v(C.lol_build_info())
}
