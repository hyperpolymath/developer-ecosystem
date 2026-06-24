// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LOL REST API — corpus data access over HTTP.
//
// Endpoints:
//   GET  /                          — API discovery
//   GET  /api/v1/languages          — list all languages in corpus
//   GET  /api/v1/languages/:code    — get a specific language by ISO 639-3
//   GET  /api/v1/corpus/stats       — aggregate corpus statistics
//   GET  /api/v1/crawl/status       — crawl pipeline status
//   GET  /api/v1/health             — gateway health check

module main

import net.http

// RestHandler implements http.Handler for the LOL REST API.
struct RestHandler {
	data_dir string
}

pub fn (mut h RestHandler) handle(req http.Request) http.Response {
	path := req.url.all_before('?')
	return match true {
		path == '/' { rest_info() }
		path == '/api/v1/languages' { rest_list_languages(h.data_dir) }
		path.starts_with('/api/v1/languages/') { rest_get_language(h.data_dir, path.all_after('/api/v1/languages/')) }
		path == '/api/v1/corpus/stats' { rest_corpus_stats(h.data_dir) }
		path == '/api/v1/crawl/status' { rest_crawl_status(h.data_dir) }
		path == '/api/v1/health' { rest_health(h.data_dir) }
		else { json_response(404, '{"error":"Not found","endpoints":["/api/v1/languages","/api/v1/corpus/stats","/api/v1/crawl/status","/api/v1/health"]}') }
	}
}

fn rest_info() http.Response {
	return json_response(200, '{"service":"lol-rest","version":"0.1.0","project":"1000Langs Parallel Corpus","endpoints":["/api/v1/languages","/api/v1/corpus/stats","/api/v1/crawl/status","/api/v1/health"]}')
}

fn rest_list_languages(data_dir string) http.Response {
	languages := list_languages(data_dir)
	mut items := []string{}
	for lang in languages {
		items << language_to_json(lang)
	}
	return json_response(200, '{"count":${languages.len},"languages":[${items.join(",")}]}')
}

fn rest_get_language(data_dir string, code string) http.Response {
	lang := get_language(data_dir, code) or {
		return json_response(404, '{"error":"Language not found","code":"${esc(code)}"}')
	}
	return json_response(200, language_to_json(lang))
}

fn rest_corpus_stats(data_dir string) http.Response {
	stats := get_corpus_stats(data_dir)
	return json_response(200, '{"total_languages":${stats.total_languages},"total_verses":${stats.total_verses},"total_bytes":${stats.total_bytes},"avg_quality":${stats.avg_quality},"families":${stats.families}}')
}

fn rest_crawl_status(data_dir string) http.Response {
	status := get_crawl_status(data_dir)
	mut sources := []string{}
	for s in status.sources {
		sources << '{"name":"${esc(s.name)}","languages":${s.languages},"crawled":${s.crawled},"status":"${esc(s.status)}"}'
	}
	return json_response(200, '{"total_languages":${status.total_languages},"crawled":${status.crawled},"in_progress":${status.in_progress},"failed":${status.failed},"last_crawl":"${esc(status.last_crawl)}","sources":[${sources.join(",")}]}')
}

fn rest_health(data_dir string) http.Response {
	stats := get_corpus_stats(data_dir)
	crawl := get_crawl_status(data_dir)
	healthy := stats.total_languages > 0 || crawl.sources.len > 0
	status := if healthy { 'ok' } else { 'no_data' }
	return json_response(200, '{"status":"${status}","version":"0.1.0","data_dir":"${esc(data_dir)}","languages":${stats.total_languages},"crawl_sources":${crawl.sources.len}}')
}
