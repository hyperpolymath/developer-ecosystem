// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Domain types and data access for the LOL corpus.
//
// Reads corpus metadata, crawl status, and analysis results from the
// filesystem. The Julia analysis bridge and Elixir orchestrator write
// their output as JSON files; this module reads them for API serving.

module main

import os

// --- Core domain types ---

// LanguageInfo represents a single language in the corpus.
struct LanguageInfo {
	iso639_3    string // ISO 639-3 three-letter code (e.g. "eng", "fra")
	name        string // English name
	native_name string // Name in the language itself
	family      string // Language family (e.g. "Indo-European")
	scripts     string // Writing systems used
	sources     int    // Number of corpus sources available
	verses      int    // Total verses crawled
	quality     f64    // Quality score from VeriSimDB pipeline (0.0–1.0)
}

// CrawlStatus tracks the state of corpus crawling.
struct CrawlStatus {
	total_languages int
	crawled         int
	in_progress     int
	failed          int
	last_crawl      string // ISO 8601 timestamp
	sources         []SourceStatus
}

// SourceStatus tracks a single crawl source.
struct SourceStatus {
	name      string // e.g. "BibleCloud", "eBible", "BibleCom"
	languages int    // Languages available from this source
	crawled   int    // Languages successfully crawled
	status    string // "ready", "crawling", "error"
}

// CorpusStats holds aggregate statistics.
struct CorpusStats {
	total_languages int
	total_verses    int
	total_bytes     i64
	avg_quality     f64
	families        int
}

// DistanceEntry holds a pairwise language distance result.
struct DistanceEntry {
	lang_a   string
	lang_b   string
	distance f64
	method   string // "jsd", "cosine", "jaccard"
}

// FrequencyResult holds frequency analysis for a language.
struct FrequencyResult {
	language     string
	total_tokens int
	unique_types int
	zipf_coeff   f64
	hapax_ratio  f64
	top_10       []TokenCount
}

// TokenCount is a word/token with its frequency count.
struct TokenCount {
	token string
	count int
}

// --- Data access layer ---
// Reads JSON files from the corpus data directory.
// The crawlers, Julia analysis, and VeriSimDB pipeline all write here.

// list_languages reads available language metadata from the corpus directory.
fn list_languages(data_dir string) []LanguageInfo {
	meta_path := os.join_path(data_dir, 'metadata')
	if !os.exists(meta_path) {
		return []
	}

	mut languages := []LanguageInfo{}
	entries := os.ls(meta_path) or { return [] }
	for entry in entries {
		if entry.ends_with('.json') {
			full := os.join_path(meta_path, entry)
			content := os.read_file(full) or { continue }
			lang := parse_language_json(content, entry.all_before('.json'))
			languages << lang
		}
	}
	return languages
}

// get_language reads metadata for a specific language by ISO 639-3 code.
fn get_language(data_dir string, code string) ?LanguageInfo {
	path := os.join_path(data_dir, 'metadata', '${code}.json')
	content := os.read_file(path) or { return none }
	return parse_language_json(content, code)
}

// get_crawl_status reads overall crawl status.
fn get_crawl_status(data_dir string) CrawlStatus {
	path := os.join_path(data_dir, 'crawl-status.json')
	if !os.exists(path) {
		return CrawlStatus{
			sources: [
				SourceStatus{name: 'BibleCloud', status: 'ready'},
				SourceStatus{name: 'BibleCom', status: 'ready'},
				SourceStatus{name: 'eBible', status: 'ready'},
				SourceStatus{name: 'FindBible', status: 'ready'},
				SourceStatus{name: 'PNGScriptures', status: 'ready'},
				SourceStatus{name: 'DigitalBiblePlatform', status: 'ready'},
			]
		}
	}

	content := os.read_file(path) or { return CrawlStatus{} }
	return parse_crawl_status_json(content)
}

// get_corpus_stats reads aggregate corpus statistics.
fn get_corpus_stats(data_dir string) CorpusStats {
	path := os.join_path(data_dir, 'stats.json')
	content := os.read_file(path) or { return CorpusStats{} }
	return parse_corpus_stats_json(content)
}

// --- JSON parsing helpers ---
// Manual JSON parsing to keep zero dependencies (V's built-in json is
// available but we follow the v-api-interfaces pattern for consistency).

fn parse_language_json(content string, fallback_code string) LanguageInfo {
	return LanguageInfo{
		iso639_3: json_field_or(content, 'iso639_3', fallback_code)
		name: json_field(content, 'name')
		native_name: json_field(content, 'native_name')
		family: json_field(content, 'family')
		scripts: json_field(content, 'scripts')
		sources: json_int_field(content, 'sources')
		verses: json_int_field(content, 'verses')
		quality: json_float_field(content, 'quality')
	}
}

fn parse_crawl_status_json(content string) CrawlStatus {
	return CrawlStatus{
		total_languages: json_int_field(content, 'total_languages')
		crawled: json_int_field(content, 'crawled')
		in_progress: json_int_field(content, 'in_progress')
		failed: json_int_field(content, 'failed')
		last_crawl: json_field(content, 'last_crawl')
	}
}

fn parse_corpus_stats_json(content string) CorpusStats {
	return CorpusStats{
		total_languages: json_int_field(content, 'total_languages')
		total_verses: json_int_field(content, 'total_verses')
		avg_quality: json_float_field(content, 'avg_quality')
		families: json_int_field(content, 'families')
	}
}
