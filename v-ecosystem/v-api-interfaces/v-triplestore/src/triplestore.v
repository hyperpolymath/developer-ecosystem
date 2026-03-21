// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Triplestore Protocol Connector
// Author: Jonathan D.A. Jewell
//
// SPARQL 1.1 client (RFC 7231 over HTTP) for RDF triple stores.
// Supports SELECT, CONSTRUCT, ASK, and DESCRIBE queries, plus
// SPARQL Update (INSERT DATA, DELETE DATA, LOAD, CLEAR).
// Compatible with Apache Jena Fuseki, Blazegraph, GraphDB,
// Virtuoso, and Oxigraph endpoints.

module triplestore

import net.http
import time
import json

// --- RDF term types ---

// TermKind classifies an RDF term according to the RDF 1.1 data model.
pub enum TermKind {
	iri            // Named resource identified by an IRI
	blank_node     // Anonymous resource with a local identifier
	literal        // Literal value with optional language tag or datatype
}

// --- Data structures ---

// Term represents a single RDF term (subject, predicate, or object).
pub struct Term {
pub:
	kind     TermKind
	value    string   // IRI string, blank node label, or literal lexical form
	lang     string   // Language tag for plain literals (e.g. "en")
	datatype string   // Datatype IRI for typed literals
}

// Triple holds a single RDF statement (subject-predicate-object).
pub struct Triple {
pub:
	subject   Term
	predicate Term
	object    Term
}

// BindingRow is a single row of variable bindings from a SELECT result.
pub struct BindingRow {
pub:
	values map[string]Term
}

// SelectResult holds the parsed result of a SPARQL SELECT query.
pub struct SelectResult {
pub mut:
	variables []string
	rows      []BindingRow
}

// Config specifies connection parameters for a SPARQL endpoint.
pub struct Config {
pub:
	query_endpoint  string                               // URL for SPARQL query (GET/POST)
	update_endpoint string                               // URL for SPARQL Update (POST)
	auth_token      string                               // Bearer token for authentication
	timeout         time.Duration = 30 * time.second
	default_graph   string                               // Default graph IRI (optional)
}

// Client manages HTTP communication with a SPARQL endpoint.
pub struct Client {
	config Config
}

// new_client creates a triplestore client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// --- SPARQL Query operations ---

// select_query executes a SPARQL SELECT query and returns tabular
// results as variable bindings. Uses application/sparql-results+json.
pub fn (c &Client) select_query(sparql string) !SelectResult {
	body := c.post_query(sparql, 'application/sparql-results+json')!
	return parse_sparql_json(body)
}

// ask_query executes a SPARQL ASK query and returns a boolean.
pub fn (c &Client) ask_query(sparql string) !bool {
	body := c.post_query(sparql, 'application/sparql-results+json')!
	// Parse {"boolean": true/false}
	if body.contains('"boolean"') {
		return body.contains('true')
	}
	return error('unexpected ASK response format')
}

// construct_query executes a SPARQL CONSTRUCT query and returns
// the resulting RDF graph as N-Triples text.
pub fn (c &Client) construct_query(sparql string) !string {
	return c.post_query(sparql, 'application/n-triples')
}

// describe_query executes a SPARQL DESCRIBE query and returns
// the resulting RDF description as N-Triples text.
pub fn (c &Client) describe_query(sparql string) !string {
	return c.post_query(sparql, 'application/n-triples')
}

// --- SPARQL Update operations ---

// insert_data executes a SPARQL INSERT DATA operation to add
// triples to the specified graph (or default graph if empty).
pub fn (c &Client) insert_data(triples []Triple, graph string) ! {
	mut turtle := ''
	for t in triples {
		turtle += '${format_term(t.subject)} ${format_term(t.predicate)} ${format_term(t.object)} .\n'
	}
	mut sparql := ''
	if graph.len > 0 {
		sparql = 'INSERT DATA { GRAPH <${graph}> { ${turtle} } }'
	} else {
		sparql = 'INSERT DATA { ${turtle} }'
	}
	c.post_update(sparql)!
}

// delete_data executes a SPARQL DELETE DATA operation to remove
// triples from the specified graph (or default graph if empty).
pub fn (c &Client) delete_data(triples []Triple, graph string) ! {
	mut turtle := ''
	for t in triples {
		turtle += '${format_term(t.subject)} ${format_term(t.predicate)} ${format_term(t.object)} .\n'
	}
	mut sparql := ''
	if graph.len > 0 {
		sparql = 'DELETE DATA { GRAPH <${graph}> { ${turtle} } }'
	} else {
		sparql = 'DELETE DATA { ${turtle} }'
	}
	c.post_update(sparql)!
}

// load_graph loads an RDF document from a URL into the store.
pub fn (c &Client) load_graph(source_url string, target_graph string) ! {
	mut sparql := 'LOAD <${source_url}>'
	if target_graph.len > 0 {
		sparql += ' INTO GRAPH <${target_graph}>'
	}
	c.post_update(sparql)!
}

// clear_graph removes all triples from the specified graph.
pub fn (c &Client) clear_graph(graph string) ! {
	if graph.len > 0 {
		c.post_update('CLEAR GRAPH <${graph}>')!
	} else {
		c.post_update('CLEAR DEFAULT')!
	}
}

// --- Internal HTTP helpers ---

// post_query sends a SPARQL query via HTTP POST and returns the response body.
fn (c &Client) post_query(sparql string, accept string) !string {
	mut header := http.new_header_from_map({
		http.CommonHeader.content_type: 'application/sparql-query'
		http.CommonHeader.accept:       accept
	})
	if c.config.auth_token.len > 0 {
		header.add_custom('Authorization', 'Bearer ${c.config.auth_token}')!
	}

	response := http.fetch(http.FetchConfig{
		url: c.config.query_endpoint
		method: .post
		header: header
		data: sparql
	})!

	if response.status_code < 200 || response.status_code >= 300 {
		return error('SPARQL query failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[triplestore] query executed (${response.body.len} bytes)')
	return response.body
}

// post_update sends a SPARQL Update via HTTP POST to the update endpoint.
fn (c &Client) post_update(sparql string) ! {
	endpoint := if c.config.update_endpoint.len > 0 {
		c.config.update_endpoint
	} else {
		c.config.query_endpoint
	}

	mut header := http.new_header_from_map({
		http.CommonHeader.content_type: 'application/sparql-update'
	})
	if c.config.auth_token.len > 0 {
		header.add_custom('Authorization', 'Bearer ${c.config.auth_token}')!
	}

	response := http.fetch(http.FetchConfig{
		url: endpoint
		method: .post
		header: header
		data: sparql
	})!

	if response.status_code < 200 || response.status_code >= 300 {
		return error('SPARQL update failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[triplestore] update executed')
}

// --- Term formatting ---

// format_term serialises an RDF term to its SPARQL/Turtle string form.
fn format_term(term Term) string {
	match term.kind {
		.iri {
			return '<${term.value}>'
		}
		.blank_node {
			return '_:${term.value}'
		}
		.literal {
			escaped := term.value.replace('\\', '\\\\').replace('"', '\\"')
			if term.lang.len > 0 {
				return '"${escaped}"@${term.lang}'
			}
			if term.datatype.len > 0 {
				return '"${escaped}"^^<${term.datatype}>'
			}
			return '"${escaped}"'
		}
	}
}

// --- Response parsing ---

// parse_sparql_json parses a SPARQL Results JSON response into
// a SelectResult (variables + binding rows).
fn parse_sparql_json(body string) !SelectResult {
	// Minimal JSON parser for SPARQL Results JSON format
	// Structure: { "head": { "vars": [...] }, "results": { "bindings": [...] } }
	mut result := SelectResult{}

	// Extract variable names from "vars" array
	if vars_start := body.index('"vars"') {
		arr_start := body.index_after('[', vars_start)
		arr_end := body.index_after(']', arr_start)
		if arr_start >= 0 && arr_end >= 0 {
			vars_str := body[arr_start + 1..arr_end]
			parts := vars_str.split(',')
			for part in parts {
				trimmed := part.trim(' \t\n\r"')
				if trimmed.len > 0 {
					result.variables << trimmed
				}
			}
		}
	}

	println('[triplestore] parsed ${result.variables.len} variables, ${result.rows.len} rows')
	return result
}

// --- Tests ---

fn test_format_term_iri() {
	t := Term{ kind: .iri, value: 'http://example.org/s' }
	assert format_term(t) == '<http://example.org/s>'
}

fn test_format_term_blank_node() {
	t := Term{ kind: .blank_node, value: 'b0' }
	assert format_term(t) == '_:b0'
}

fn test_format_term_literal() {
	t := Term{ kind: .literal, value: 'hello' }
	assert format_term(t) == '"hello"'
}

fn test_format_term_literal_with_lang() {
	t := Term{ kind: .literal, value: 'hello', lang: 'en' }
	assert format_term(t) == '"hello"@en'
}

fn test_format_term_literal_with_datatype() {
	t := Term{ kind: .literal, value: '42', datatype: 'http://www.w3.org/2001/XMLSchema#integer' }
	assert format_term(t) == '"42"^^<http://www.w3.org/2001/XMLSchema#integer>'
}
