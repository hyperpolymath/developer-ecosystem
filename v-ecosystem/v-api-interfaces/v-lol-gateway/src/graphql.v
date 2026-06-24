// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// LOL GraphQL API — corpus data access via GraphQL.
//
// Queries:
//   { languages { iso639_3 name family quality } }
//   { language(code: "eng") { iso639_3 name nativeName sources verses } }
//   { corpusStats { totalLanguages totalVerses avgQuality families } }
//   { crawlStatus { crawled inProgress failed sources { name status } } }
//   { health { status version } }
//
// GET  /graphql  — GraphiQL playground
// POST /graphql  — execute GraphQL queries

module main

import net.http

// GraphqlHandler implements http.Handler for the LOL GraphQL API.
struct GraphqlHandler {
	data_dir string
}

pub fn (mut h GraphqlHandler) handle(req http.Request) http.Response {
	path := req.url.all_before('?')
	if path != '/graphql' {
		return json_response(404, '{"error":"Use /graphql endpoint"}')
	}

	if req.method == .get {
		return graphiql_page()
	}
	if req.method != .post {
		return json_response(405, '{"error":"POST or GET required"}')
	}

	query := json_field(req.data, 'query')
	if query.len == 0 {
		return json_response(400, '{"errors":[{"message":"Missing query field"}]}')
	}

	return resolve_query(query, h.data_dir)
}

fn resolve_query(query string, data_dir string) http.Response {
	if query.contains('health') {
		return resolve_gql_health(data_dir)
	}
	if query.contains('crawlStatus') {
		return resolve_gql_crawl_status(data_dir)
	}
	if query.contains('corpusStats') {
		return resolve_gql_corpus_stats(data_dir)
	}
	if query.contains('languages') && !query.contains('language(') {
		return resolve_gql_languages(data_dir)
	}
	if query.contains('language(') || query.contains('language (') {
		code := extract_arg(query, 'code')
		return resolve_gql_language(data_dir, code)
	}
	if query.contains('__schema') {
		return resolve_gql_schema()
	}

	return json_response(200, '{"errors":[{"message":"Unknown query. Available: languages, language(code), corpusStats, crawlStatus, health"}]}')
}

fn resolve_gql_languages(data_dir string) http.Response {
	languages := list_languages(data_dir)
	mut items := []string{}
	for lang in languages {
		items << language_to_json(lang)
	}
	return json_response(200, '{"data":{"languages":[${items.join(",")}]}}')
}

fn resolve_gql_language(data_dir string, code string) http.Response {
	if code.len == 0 {
		return json_response(200, '{"errors":[{"message":"language(code: ...) requires a code argument"}]}')
	}
	lang := get_language(data_dir, code) or {
		return json_response(200, '{"errors":[{"message":"Language not found: ${esc(code)}"}]}')
	}
	return json_response(200, '{"data":{"language":${language_to_json(lang)}}}')
}

fn resolve_gql_corpus_stats(data_dir string) http.Response {
	stats := get_corpus_stats(data_dir)
	return json_response(200, '{"data":{"corpusStats":{"totalLanguages":${stats.total_languages},"totalVerses":${stats.total_verses},"totalBytes":${stats.total_bytes},"avgQuality":${stats.avg_quality},"families":${stats.families}}}}')
}

fn resolve_gql_crawl_status(data_dir string) http.Response {
	status := get_crawl_status(data_dir)
	mut sources := []string{}
	for s in status.sources {
		sources << '{"name":"${esc(s.name)}","languages":${s.languages},"crawled":${s.crawled},"status":"${esc(s.status)}"}'
	}
	return json_response(200, '{"data":{"crawlStatus":{"totalLanguages":${status.total_languages},"crawled":${status.crawled},"inProgress":${status.in_progress},"failed":${status.failed},"lastCrawl":"${esc(status.last_crawl)}","sources":[${sources.join(",")}]}}}')
}

fn resolve_gql_health(data_dir string) http.Response {
	stats := get_corpus_stats(data_dir)
	status := if stats.total_languages > 0 { 'ok' } else { 'no_data' }
	return json_response(200, '{"data":{"health":{"status":"${status}","version":"0.1.0","languages":${stats.total_languages}}}}')
}

fn resolve_gql_schema() http.Response {
	return json_response(200, '{"data":{"__schema":{"types":[' +
		'{"name":"Query","fields":["languages","language","corpusStats","crawlStatus","health"]},' +
		'{"name":"Language","fields":["iso639_3","name","nativeName","family","scripts","sources","verses","quality"]},' +
		'{"name":"CorpusStats","fields":["totalLanguages","totalVerses","totalBytes","avgQuality","families"]},' +
		'{"name":"CrawlStatus","fields":["totalLanguages","crawled","inProgress","failed","lastCrawl","sources"]},' +
		'{"name":"Source","fields":["name","languages","crawled","status"]},' +
		'{"name":"Health","fields":["status","version","languages"]}' +
		']}}}')
}

fn graphiql_page() http.Response {
	html := '<!DOCTYPE html>
<html><head><title>LOL (1000Langs) GraphQL</title></head>
<body style="font-family:monospace;padding:2em;background:#1a1a2e;color:#e0e0e0">
<h2>LOL (1000Langs) GraphQL API</h2>
<p>POST queries to /graphql with JSON body:</p>
<pre style="background:#16213e;padding:1em;border-radius:4px">
{ "query": "{ health { status version languages } }" }

{ "query": "{ languages { iso639_3 name family quality } }" }

{ "query": "{ language(code: \\"eng\\") { iso639_3 name nativeName sources verses quality } }" }

{ "query": "{ corpusStats { totalLanguages totalVerses avgQuality families } }" }

{ "query": "{ crawlStatus { crawled inProgress failed sources { name status } } }" }
</pre>
</body></html>'

	return http.new_response(
		status: .ok
		header: http.new_header(key: .content_type, value: 'text/html')
		body: html
	)
}
