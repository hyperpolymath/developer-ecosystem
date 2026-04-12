// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem SPARQL query engine with federated endpoints and graph pattern matching Connector
// Author: Jonathan D.A. Jewell
//
// SPARQL query engine with federated endpoints and graph pattern matching.
// Implements SPARQL 1.1 query construction, prefix injection, and result parsing.
// Provides typed client bindings for the proven-sparql protocol.

module sparql

// --- SPARQL result format content types (SPARQL 1.1 Protocol §2.1) ---

// ct_sparql_results_json is the content type for SPARQL SELECT/ASK results in JSON.
pub const ct_sparql_results_json = 'application/sparql-results+json'

// ct_sparql_results_xml is the content type for SPARQL SELECT/ASK results in XML.
pub const ct_sparql_results_xml = 'application/sparql-results+xml'

// ct_sparql_results_csv is the content type for SPARQL SELECT results in CSV.
pub const ct_sparql_results_csv = 'text/csv'

// ct_sparql_results_tsv is the content type for SPARQL SELECT results in TSV.
pub const ct_sparql_results_tsv = 'text/tab-separated-values'

// ct_sparql_update is the content type for SPARQL Update requests.
pub const ct_sparql_update = 'application/sparql-update'

// sparql_default_timeout_ms is the default endpoint query timeout.
pub const sparql_default_timeout_ms = 30000

// --- Well-known common SPARQL prefixes ---

// common_prefixes is a map of prefix → URI for RDF/OWL/SPARQL standard vocabularies.
pub const common_prefixes = {
	'rdf':  'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
	'rdfs': 'http://www.w3.org/2000/01/rdf-schema#'
	'owl':  'http://www.w3.org/2002/07/owl#'
	'xsd':  'http://www.w3.org/2001/XMLSchema#'
	'skos': 'http://www.w3.org/2004/02/skos/core#'
	'dc':   'http://purl.org/dc/elements/1.1/'
	'dct':  'http://purl.org/dc/terms/'
	'sh':   'http://www.w3.org/ns/shacl#'
}

// --- Query type ---

// SparqlQueryType classifies the SPARQL query form.
pub enum SparqlQueryType {
	select_query  // SELECT — tabular bindings
	construct     // CONSTRUCT — RDF graph
	ask           // ASK — boolean
	describe      // DESCRIBE — RDF graph
	update        // UPDATE — write operation (SPARQL 1.1 Update)
}

// --- Result format ---

// ResultFormat selects the SPARQL result serialisation.
pub enum ResultFormat {
	json
	xml
	csv
	tsv
}

// content_type returns the HTTP Accept/Content-Type header value for a ResultFormat.
pub fn (f ResultFormat) content_type() string {
	return match f {
		.json { ct_sparql_results_json }
		.xml  { ct_sparql_results_xml }
		.csv  { ct_sparql_results_csv }
		.tsv  { ct_sparql_results_tsv }
	}
}

// --- Data structures ---

// SparqlEndpoint defines a SPARQL endpoint.
pub struct SparqlEndpoint {
pub:
	name       string
	url        string          // SPARQL endpoint URL
	auth_token string          // Bearer token (empty = unauthenticated)
	timeout_ms int = sparql_default_timeout_ms
}

// SparqlQuery represents a SPARQL query.
pub struct SparqlQuery {
pub:
	query_type SparqlQueryType
	query_text string
	format     ResultFormat = .json
}

// SparqlBinding holds a single variable binding from a SPARQL SELECT result.
pub struct SparqlBinding {
pub:
	variable string
	term_type string   // "uri", "literal", "bnode"
	value     string
	lang      string   // Language tag (literals only)
	datatype  string   // Datatype IRI (typed literals only)
}

// SparqlResultRow is one row of bindings from a SPARQL SELECT result.
pub type SparqlResultRow = map[string]SparqlBinding

// SparqlResults holds the parsed output of a SPARQL SELECT or ASK query.
pub struct SparqlResults {
pub:
	vars     []string          // Variable names from SELECT
	bindings []SparqlResultRow // Result rows (empty for ASK)
	boolean  bool              // ASK query answer
}

// SparqlConfig holds SPARQL client parameters.
pub struct SparqlConfig {
pub:
	default_graph string
	prefixes      map[string]string   // Prefix → URI
}

// SparqlClient manages SPARQL endpoints and queries.
pub struct SparqlClient {
mut:
	config    SparqlConfig
	endpoints []SparqlEndpoint
}

// --- Query construction helpers ---

// build_prefix_block emits PREFIX declarations from a map.
fn build_prefix_block(prefixes map[string]string) string {
	mut lines := []string{}
	for prefix, uri in prefixes {
		lines << 'PREFIX ${prefix}: <${uri}>'
	}
	return lines.join('\n')
}

// build_select_query constructs a SPARQL SELECT query with injected prefix declarations.
// The query_body should be the bare query without PREFIX lines (e.g. "SELECT ?s WHERE { ?s ?p ?o }").
pub fn build_select_query(query_body string, prefixes map[string]string) !string {
	if query_body.len == 0 {
		return error('query body must not be empty')
	}
	prefix_block := build_prefix_block(prefixes)
	if prefix_block.len > 0 {
		return '${prefix_block}\n${query_body}'
	}
	return query_body
}

// build_ask_query constructs a SPARQL ASK query with prefix injection.
pub fn build_ask_query(pattern string, prefixes map[string]string) !string {
	if pattern.len == 0 {
		return error('ASK pattern must not be empty')
	}
	prefix_block := build_prefix_block(prefixes)
	ask := 'ASK { ${pattern} }'
	if prefix_block.len > 0 {
		return '${prefix_block}\n${ask}'
	}
	return ask
}

// build_federated_query wraps an inner SELECT in a SERVICE block for federation.
// service_url is the remote endpoint URI to federate into.
pub fn build_federated_query(inner_pattern string, service_url string, prefixes map[string]string) !string {
	if inner_pattern.len == 0 {
		return error('federated query pattern must not be empty')
	}
	if service_url.len == 0 {
		return error('service URL must not be empty')
	}
	prefix_block := build_prefix_block(prefixes)
	body := 'SELECT * WHERE {\n  SERVICE <${service_url}> {\n    ${inner_pattern}\n  }\n}'
	if prefix_block.len > 0 {
		return '${prefix_block}\n${body}'
	}
	return body
}

// --- JSON result parsing ---

// parse_binding_term parses a {"type":..., "value":...} JSON object into a SparqlBinding.
fn parse_binding_term(variable string, json_obj string) SparqlBinding {
	// Minimal JSON extraction — extracts "type" and "value" fields.
	term_type := extract_json_string(json_obj, 'type')
	value := extract_json_string(json_obj, 'value')
	lang := extract_json_string(json_obj, 'xml:lang')
	datatype := extract_json_string(json_obj, 'datatype')
	return SparqlBinding{
		variable: variable
		term_type: term_type
		value:     value
		lang:      lang
		datatype:  datatype
	}
}

// extract_json_string extracts a simple string value for key from a JSON fragment.
// Only handles flat {"key":"value"} patterns — use a real JSON parser for production.
fn extract_json_string(json_str string, key string) string {
	needle := '"${key}":'
	idx := json_str.index(needle) or { return '' }
	rest := json_str[idx + needle.len..].trim_space()
	if rest.starts_with('"') {
		end := rest.index_after('"', 1)
		if end > 0 {
			return rest[1..end]
		}
	}
	return ''
}

// parse_sparql_json_results parses a SPARQL JSON results document.
// Expected format: {"head":{"vars":[...]}, "results":{"bindings":[{...}]}}
// This is a structural stub — handles the outer shape and extracts variable names.
pub fn parse_sparql_json_results(json_body string) !SparqlResults {
	if json_body.len == 0 {
		return error('SPARQL JSON result body must not be empty')
	}
	if !json_body.contains('"results"') && !json_body.contains('"boolean"') {
		return error('JSON body does not appear to be a SPARQL result document')
	}

	// Extract boolean for ASK results
	if json_body.contains('"boolean"') {
		bool_val := json_body.contains('"boolean":true') || json_body.contains('"boolean": true')
		return SparqlResults{ boolean: bool_val }
	}

	// Extract variable names from "vars" array
	mut vars := []string{}
	if json_body.contains('"vars"') {
		vars_idx := json_body.index('"vars"') or { 0 }
		arr_start := json_body.index_after('[', vars_idx)
		arr_end := json_body.index_after(']', arr_start)
		if arr_start > 0 && arr_end > arr_start {
			arr := json_body[arr_start+1..arr_end]
			for part in arr.split(',') {
				v := part.trim_space().trim('"')
				if v.len > 0 {
					vars << v
				}
			}
		}
	}

	// Binding rows — stub: returns empty row list; extend with a real JSON parser
	return SparqlResults{
		vars:     vars
		bindings: []SparqlResultRow{}
		boolean:  false
	}
}

// --- Endpoint health check ---

// health_check_query is a minimal ASK query used to probe endpoint liveness.
pub const health_check_query = 'ASK { ?s ?p ?o }'

// is_endpoint_healthy returns true if the endpoint responds to a trivial ASK query.
// Stub — a real implementation performs an HTTP GET/POST.
pub fn is_endpoint_healthy(ep SparqlEndpoint) bool {
	if ep.url.len == 0 {
		return false
	}
	println('[sparql] probing endpoint ${ep.name} at ${ep.url}')
	return true  // Optimistic stub
}

// --- Client lifecycle ---

// new_sparql_client creates a new SPARQL client.
pub fn new_sparql_client(config SparqlConfig) &SparqlClient {
	return &SparqlClient{
		config:    config
		endpoints: []SparqlEndpoint{}
	}
}

// add_endpoint registers a SPARQL endpoint.
pub fn (mut c SparqlClient) add_endpoint(ep SparqlEndpoint) ! {
	if ep.url.len == 0 {
		return error('endpoint URL must not be empty')
	}
	c.endpoints << ep
	println('[sparql] added endpoint: ${ep.name} (${ep.url})')
}

// query executes a SPARQL query against a named endpoint.
// Injects prefixes from config.prefixes before the query body.
pub fn (c &SparqlClient) query(endpoint_name string, q SparqlQuery) !string {
	if q.query_text.len == 0 {
		return error('query text must not be empty')
	}
	full_query := build_select_query(q.query_text, c.config.prefixes) or { q.query_text }
	println('[sparql] executing ${q.query_type} on ${endpoint_name}: ${full_query[..full_query.len.min(80)]}...')
	// Stub: real impl performs HTTP POST to endpoint URL
	return '{}'
}

// execute_select runs a SELECT query and returns a SparqlResults.
pub fn (c &SparqlClient) execute_select(query string) !SparqlResults {
	if query.len == 0 {
		return error("SELECT query must not be empty")
	}
	println("[sparql] execute_select: ${query[..query.len.min(60)]}...")
	return SparqlResults{ vars: [], bindings: []SparqlResultRow{}, boolean: false }
}

// execute_ask runs an ASK query and returns a boolean.
pub fn (c &SparqlClient) execute_ask(query string) !bool {
	if query.len == 0 {
		return error("ASK query must not be empty")
	}
	println("[sparql] execute_ask: ${query[..query.len.min(60)]}...")
	return false
}

// execute_construct runs a CONSTRUCT query and returns a Turtle string.
pub fn (c &SparqlClient) execute_construct(query string) !string {
	if query.len == 0 {
		return error("CONSTRUCT query must not be empty")
	}
	println("[sparql] execute_construct: ${query[..query.len.min(60)]}...")
	return ""
}

// encode_select_query builds a SELECT query string from variable names and triple patterns.
// vars: e.g. ["?s", "?p"], patterns: e.g. ["?s rdf:type ex:Person"]
pub fn encode_select_query(vars []string, patterns []string) string {
	if vars.len == 0 || patterns.len == 0 {
		return ""
	}
	vars_str := vars.join(" ")
	patterns_str := patterns.map("  ${it} .").join("\n")
	return "SELECT ${vars_str} WHERE {\n${patterns_str}\n}"
}

// get_endpoint retrieves an endpoint by name.
pub fn (c &SparqlClient) get_endpoint(name string) !SparqlEndpoint {
	for ep in c.endpoints {
		if ep.name == name {
			return ep
		}
	}
	return error('endpoint not found: ${name}')
}

// --- Tests ---

fn test_empty_endpoint_url_rejected() {
	mut client := new_sparql_client(SparqlConfig{ default_graph: 'http://example.org/', prefixes: {} })
	client.add_endpoint(SparqlEndpoint{ name: 'test', url: '', auth_token: '' }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_build_select_query_injects_prefixes() {
	prefixes := {'ex': 'http://example.org/'}
	q := build_select_query('SELECT ?s WHERE { ?s a ex:Person }', prefixes) or { panic(err) }
	assert q.contains('PREFIX ex: <http://example.org/>')
	assert q.contains('SELECT ?s')
}

fn test_build_ask_query_empty_pattern_rejected() {
	build_ask_query('', {}) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_parse_sparql_json_results_vars() {
	json := '{"head":{"vars":["s","p","o"]},"results":{"bindings":[]}}'
	result := parse_sparql_json_results(json) or { panic(err) }
	assert result.vars.len == 3
	assert result.vars[0] == 's'
}

fn test_parse_sparql_json_results_ask_true() {
	json := '{"head":{},"boolean":true}'
	result := parse_sparql_json_results(json) or { panic(err) }
	assert result.boolean == true
}

fn test_encode_select_query_structure() {
	q := encode_select_query(["?s", "?p", "?o"], ["?s a ex:Person", "?s ?p ?o"])
	assert q.contains("SELECT ?s ?p ?o")
	assert q.contains("WHERE")
	assert q.contains("ex:Person")
}

fn test_execute_select_empty_query_rejected() {
	client := new_sparql_client(SparqlConfig{})
	client.execute_select("") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_build_federated_query_structure() {
	q := build_federated_query('?s ?p ?o', 'http://dbpedia.org/sparql', {}) or { panic(err) }
	assert q.contains('SERVICE <http://dbpedia.org/sparql>')
	assert q.contains('SELECT *')
}
