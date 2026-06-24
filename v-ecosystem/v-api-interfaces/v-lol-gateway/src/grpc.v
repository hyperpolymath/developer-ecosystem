// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LOL gRPC API — corpus data access via gRPC-Web compatible JSON-over-HTTP.
//
// Services:
//   lol.CorpusService/ListLanguages  — list all languages
//   lol.CorpusService/GetLanguage    — get language by ISO 639-3 code
//   lol.CorpusService/CorpusStats    — aggregate statistics
//   lol.CorpusService/CrawlStatus    — crawl pipeline status
//   lol.CorpusService/Health         — health check
//
// Transport: JSON-over-HTTP (gRPC-Web compatible).
// Full HTTP/2 + Protobuf transport planned via Zig FFI.

module main

import net.http

// GrpcHandler implements http.Handler for the LOL gRPC-Web API.
struct GrpcHandler {
	data_dir string
}

pub fn (mut h GrpcHandler) handle(req http.Request) http.Response {
	if req.method != .post {
		return grpc_response(405, '{"error":"POST required for RPC calls"}')
	}

	path := req.url.all_before('?')
	return match path {
		'/lol.CorpusService/ListLanguages' { grpc_list_languages(h.data_dir) }
		'/lol.CorpusService/GetLanguage' { grpc_get_language(h.data_dir, req.data) }
		'/lol.CorpusService/CorpusStats' { grpc_corpus_stats(h.data_dir) }
		'/lol.CorpusService/CrawlStatus' { grpc_crawl_status(h.data_dir) }
		'/lol.CorpusService/Health' { grpc_health(h.data_dir) }
		else { grpc_response(404, '{"error":"Unknown method: ${esc(path)}"}') }
	}
}

fn grpc_list_languages(data_dir string) http.Response {
	languages := list_languages(data_dir)
	mut items := []string{}
	for lang in languages {
		items << language_to_json(lang)
	}
	return grpc_response(200, '{"languages":[${items.join(",")}],"count":${languages.len}}')
}

fn grpc_get_language(data_dir string, payload string) http.Response {
	code := json_field(payload, 'code')
	if code.len == 0 {
		return grpc_response(400, '{"error":"code field required"}')
	}

	lang := get_language(data_dir, code) or {
		return grpc_response(404, '{"error":"Language not found","code":"${esc(code)}"}')
	}
	return grpc_response(200, language_to_json(lang))
}

fn grpc_corpus_stats(data_dir string) http.Response {
	stats := get_corpus_stats(data_dir)
	return grpc_response(200, '{"total_languages":${stats.total_languages},"total_verses":${stats.total_verses},"total_bytes":${stats.total_bytes},"avg_quality":${stats.avg_quality},"families":${stats.families}}')
}

fn grpc_crawl_status(data_dir string) http.Response {
	status := get_crawl_status(data_dir)
	mut sources := []string{}
	for s in status.sources {
		sources << '{"name":"${esc(s.name)}","languages":${s.languages},"crawled":${s.crawled},"status":"${esc(s.status)}"}'
	}
	return grpc_response(200, '{"total_languages":${status.total_languages},"crawled":${status.crawled},"in_progress":${status.in_progress},"failed":${status.failed},"last_crawl":"${esc(status.last_crawl)}","sources":[${sources.join(",")}]}')
}

fn grpc_health(data_dir string) http.Response {
	stats := get_corpus_stats(data_dir)
	status := if stats.total_languages > 0 { 'SERVING' } else { 'NOT_SERVING' }
	return grpc_response(200, '{"status":"${status}","version":"0.1.0"}')
}
