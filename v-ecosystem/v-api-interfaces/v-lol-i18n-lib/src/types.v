// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LOL i18n Service — V-lang API Types
//
// High-level V types that wrap the C structs from the Zig FFI.
// These provide idiomatic V access to the LOL service without
// exposing raw pointers or C types to callers.

module lol

// --- Result codes ---

// LolError represents error conditions returned by the LOL service.
// Matches the lol_result_t enum in generated/abi/lol.h.
pub enum LolError {
	generic_error
	invalid_param
	out_of_memory
	null_pointer
	locale_not_found
	key_not_found
	plural_out_of_range
}

// stringer implements the string representation of LolError.
pub fn (e LolError) str() string {
	return match e {
		.generic_error { 'Generic error' }
		.invalid_param { 'Invalid parameter' }
		.out_of_memory { 'Out of memory' }
		.null_pointer { 'Null pointer' }
		.locale_not_found { 'Locale not found in corpus' }
		.key_not_found { 'Translation key not found' }
		.plural_out_of_range { 'Plural form index out of range' }
	}
}

// --- CLDR plural categories ---

// PluralCategory represents a Unicode CLDR plural category.
// Different languages partition quantities into different subsets
// of these six categories.
pub enum PluralCategory {
	zero  // Typically 0 in some languages (Arabic, etc.)
	one   // Typically 1 (English "1 item")
	two   // Typically 2 (Arabic dual, Welsh, etc.)
	few   // Small numbers (3-10 in Arabic, 2-4 in Czech, etc.)
	many  // Large numbers (11-99 in Arabic, etc.)
	other // Everything else (English "2 items", "5 items", etc.)
}

// stringer for PluralCategory
pub fn (c PluralCategory) str() string {
	return match c {
		.zero { 'zero' }
		.one { 'one' }
		.two { 'two' }
		.few { 'few' }
		.many { 'many' }
		.other { 'other' }
	}
}

// --- Locale ---

// Locale represents a parsed BCP 47 locale tag resolved against
// the LOL corpus.
pub struct Locale {
pub:
	tag      string // Full BCP 47 tag (e.g. "en-US")
	language string // ISO 639 language subtag (e.g. "en")
	script   string // ISO 15924 script (e.g. "Latn"), empty if unspecified
	region   string // ISO 3166-1 region (e.g. "US"), empty if unspecified
}

// --- Translation result ---

// TranslationResult holds the output of a translation lookup,
// including the text and information about locale fallback.
pub struct TranslationResult {
pub:
	text            string // The resolved translation text (UTF-8)
	resolved_locale string // The locale that was actually used
	is_fallback     bool   // Whether a fallback locale was used
}

// --- Language metadata ---

// LanguageInfo holds metadata about a single language in the
// LOL parallel corpus.
pub struct LanguageInfo {
pub:
	iso639_3     string // ISO 639-3 three-letter code
	name         string // English name
	native_name  string // Autonym (name in the language itself)
	family       string // Language family (e.g. "Indo-European")
	scripts      string // Writing systems used
	source_count int    // Number of corpus sources available
	verse_count  int    // Total verses crawled
	quality      f64    // Quality score from VeriSimDB pipeline (0.0-1.0)
}

// --- Plural rule ---

// PluralRule describes which CLDR plural categories a language uses
// and how many distinct forms it requires.
pub struct PluralRule {
pub:
	language   string           // ISO 639 code
	form_count int              // Number of distinct plural forms (1-6)
	categories []PluralCategory // Which categories this language uses
}

// --- Service configuration ---

// Config holds initialisation parameters for the LOL service.
pub struct Config {
pub:
	data_dir        string // Path to corpus data directory (default: "corpus")
	default_locale  string // Default fallback locale (default: "en")
	enable_fallback bool   // Whether to walk the fallback chain (default: true)
	api_port        int    // Port for API gateway, 0 to disable (default: 0)
}

// default_config returns a Config with sensible defaults.
pub fn default_config() Config {
	return Config{
		data_dir: 'corpus'
		default_locale: 'en'
		enable_fallback: true
		api_port: 0
	}
}
