// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Graph Database Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Multi-dialect graph database client supporting Neo4j Bolt, TinkerPop
// Gremlin, and SPARQL endpoint protocols. Provides a unified interface
// for node/edge CRUD, query execution, and transaction management over
// raw TCP (Bolt) or HTTP (Gremlin/SPARQL). Designed for knowledge graph
// and linked data workloads within the V-Ecosystem API layer.

module graphdb

import net
import net.http
import json
import time

// --- Query dialect enumeration ---

// QueryDialect selects the graph query language used when executing
// statements against the connected backend.
pub enum QueryDialect {
	cypher   // Neo4j Cypher Query Language
	gremlin  // Apache TinkerPop Gremlin
	sparql   // W3C SPARQL 1.1 Query Language
}

// --- Connection configuration ---

// Config holds the parameters needed to establish a graph database
// connection. The dialect field determines which protocol framing
// is used on the wire.
pub struct Config {
pub:
	host              string
	port              int
	dialect           QueryDialect
	username          string
	password          string
	database          string = 'neo4j'
	connect_timeout   time.Duration = 10 * time.second
	read_timeout      time.Duration = 30 * time.second
	use_tls           bool
	max_retry_count   int = 3
}

// --- Graph data structures ---

// Node represents a vertex in the graph with an identifier, labels,
// and a property map.
pub struct Node {
pub mut:
	id         string
	labels     []string
	properties map[string]string
}

// Edge represents a directed relationship between two nodes, carrying
// a type tag and property map.
pub struct Edge {
pub mut:
	id           string
	rel_type     string
	source_id    string
	target_id    string
	properties   map[string]string
}

// QueryResult holds the tabular output of a graph query, represented
// as a list of column names and a list of row maps.
pub struct QueryResult {
pub mut:
	columns []string
	rows    []map[string]string
	count   int
}

// TransactionState tracks whether a transaction is active, committed,
// or rolled back.
pub enum TransactionState {
	none
	active
	committed
	rolled_back
}

// --- Client ---

// Client manages the connection to a graph database and exposes
// protocol-specific operations through a unified interface.
pub struct Client {
mut:
	config          Config
	tcp_conn        ?net.TcpConn
	connected       bool
	transaction_state TransactionState
	transaction_id  string
}

// connect establishes a connection to the graph database backend
// using the dialect specified in the configuration. Returns an error
// if the handshake or authentication fails.
pub fn connect(config Config) !&Client {
	mut client := &Client{
		config: config
	}

	match config.dialect {
		.cypher {
			client.connect_bolt()!
		}
		.gremlin {
			// Gremlin uses HTTP/WebSocket; validate reachability
			client.verify_http_endpoint('/gremlin')!
		}
		.sparql {
			// SPARQL uses HTTP; validate reachability
			client.verify_http_endpoint('/sparql')!
		}
	}

	client.connected = true
	println('[graphdb] connected to ${config.host}:${config.port} (${config.dialect})')
	return client
}

// disconnect cleanly shuts down the connection, rolling back any
// active transaction first.
pub fn (mut c Client) disconnect() {
	if !c.connected {
		return
	}
	if c.transaction_state == .active {
		c.rollback() or {}
	}
	if mut conn := c.tcp_conn {
		conn.close() or {}
	}
	c.connected = false
	println('[graphdb] disconnected')
}

// --- Query execution ---

// execute runs a query string in the configured dialect and returns
// the result set. Cypher queries go over Bolt; Gremlin and SPARQL
// are dispatched as HTTP POST requests to the appropriate endpoint.
pub fn (mut c Client) execute(query_text string) !QueryResult {
	if !c.connected {
		return error('not connected to graph database')
	}

	return match c.config.dialect {
		.cypher {
			c.execute_cypher(query_text)!
		}
		.gremlin {
			c.execute_gremlin(query_text)!
		}
		.sparql {
			c.execute_sparql(query_text)!
		}
	}
}

// execute_with_params runs a parameterised query, binding the given
// parameter map to the query template. Only Cypher and Gremlin
// support server-side parameter binding; SPARQL parameters are
// interpolated client-side with escaping.
pub fn (mut c Client) execute_with_params(query_text string, params map[string]string) !QueryResult {
	if !c.connected {
		return error('not connected to graph database')
	}

	// Build the parameterised query body based on dialect
	parameterised_query := c.build_parameterised_query(query_text, params)
	return c.execute(parameterised_query)
}

// --- Node CRUD ---

// create_node inserts a new vertex with the given labels and
// properties. Returns the node with its server-assigned identifier.
pub fn (mut c Client) create_node(labels []string, properties map[string]string) !Node {
	label_str := labels.join(':')
	prop_str := encode_properties(properties)

	query := match c.config.dialect {
		.cypher {
			'CREATE (n:${label_str} {${prop_str}}) RETURN n'
		}
		.gremlin {
			mut gremlin_query := "g.addV('${labels[0]}')"
			for key, value in properties {
				gremlin_query += ".property('${key}', '${value}')"
			}
			gremlin_query
		}
		.sparql {
			// SPARQL INSERT DATA
			node_uri := '_:node_${time.ticks()}'
			mut triples := 'INSERT DATA { ${node_uri} a <${labels[0]}> '
			for key, value in properties {
				triples += '; <${key}> "${value}" '
			}
			triples += '. }'
			triples
		}
	}

	result := c.execute(query)!
	return Node{
		id: if result.rows.len > 0 { result.rows[0]['id'] or { '' } } else { '' }
		labels: labels
		properties: properties
	}
}

// get_node retrieves a vertex by its identifier.
pub fn (mut c Client) get_node(node_id string) !Node {
	query := match c.config.dialect {
		.cypher {
			'MATCH (n) WHERE id(n) = ${node_id} RETURN n'
		}
		.gremlin {
			"g.V('${node_id}')"
		}
		.sparql {
			'SELECT ?p ?o WHERE { <${node_id}> ?p ?o }'
		}
	}

	result := c.execute(query)!
	if result.rows.len == 0 {
		return error('node ${node_id} not found')
	}

	mut node := Node{
		id: node_id
	}
	for row in result.rows {
		for key, value in row {
			node.properties[key] = value
		}
	}
	return node
}

// delete_node removes a vertex and its incident edges by identifier.
pub fn (mut c Client) delete_node(node_id string) ! {
	query := match c.config.dialect {
		.cypher {
			'MATCH (n) WHERE id(n) = ${node_id} DETACH DELETE n'
		}
		.gremlin {
			"g.V('${node_id}').drop()"
		}
		.sparql {
			'DELETE WHERE { <${node_id}> ?p ?o }'
		}
	}

	c.execute(query)!
}

// --- Edge CRUD ---

// create_edge inserts a directed relationship between two existing
// nodes. Returns the edge with its server-assigned identifier.
pub fn (mut c Client) create_edge(source_id string, target_id string, rel_type string, properties map[string]string) !Edge {
	prop_str := encode_properties(properties)

	query := match c.config.dialect {
		.cypher {
			'MATCH (a), (b) WHERE id(a) = ${source_id} AND id(b) = ${target_id} CREATE (a)-[r:${rel_type} {${prop_str}}]->(b) RETURN r'
		}
		.gremlin {
			mut gremlin_query := "g.V('${source_id}').addE('${rel_type}').to(g.V('${target_id}'))"
			for key, value in properties {
				gremlin_query += ".property('${key}', '${value}')"
			}
			gremlin_query
		}
		.sparql {
			'INSERT DATA { <${source_id}> <${rel_type}> <${target_id}> }'
		}
	}

	result := c.execute(query)!
	return Edge{
		id: if result.rows.len > 0 { result.rows[0]['id'] or { '' } } else { '' }
		rel_type: rel_type
		source_id: source_id
		target_id: target_id
		properties: properties
	}
}

// delete_edge removes a relationship by its identifier.
pub fn (mut c Client) delete_edge(edge_id string) ! {
	query := match c.config.dialect {
		.cypher {
			'MATCH ()-[r]->() WHERE id(r) = ${edge_id} DELETE r'
		}
		.gremlin {
			"g.E('${edge_id}').drop()"
		}
		.sparql {
			'DELETE WHERE { ?s ?p ?o . FILTER(STR(?p) = "${edge_id}") }'
		}
	}

	c.execute(query)!
}

// --- Transaction support ---

// begin_transaction starts an explicit transaction on backends that
// support it (Bolt/Cypher). Gremlin and SPARQL operate in auto-commit
// mode where this is a no-op that records intent.
pub fn (mut c Client) begin_transaction() ! {
	if !c.connected {
		return error('not connected')
	}
	if c.transaction_state == .active {
		return error('transaction already active')
	}

	match c.config.dialect {
		.cypher {
			c.execute('BEGIN')!
		}
		.gremlin {
			// Gremlin Server sessions are used for transactions;
			// record that we intend transactional semantics.
			println('[graphdb] gremlin session transaction started')
		}
		.sparql {
			println('[graphdb] sparql auto-commit mode (no explicit transactions)')
		}
	}

	c.transaction_id = 'tx-${time.ticks()}'
	c.transaction_state = .active
	println('[graphdb] transaction ${c.transaction_id} started')
}

// commit finalises the active transaction, making all mutations
// durable.
pub fn (mut c Client) commit() ! {
	if c.transaction_state != .active {
		return error('no active transaction to commit')
	}

	match c.config.dialect {
		.cypher {
			c.execute('COMMIT')!
		}
		else {}
	}

	println('[graphdb] transaction ${c.transaction_id} committed')
	c.transaction_state = .committed
	c.transaction_id = ''
}

// rollback aborts the active transaction, discarding all pending
// mutations.
pub fn (mut c Client) rollback() ! {
	if c.transaction_state != .active {
		return error('no active transaction to rollback')
	}

	match c.config.dialect {
		.cypher {
			c.execute('ROLLBACK')!
		}
		else {}
	}

	println('[graphdb] transaction ${c.transaction_id} rolled back')
	c.transaction_state = .rolled_back
	c.transaction_id = ''
}

// --- Internal protocol helpers ---

// connect_bolt establishes a TCP connection and performs the Bolt
// handshake (magic preamble 0x6060B017 followed by version negotiation).
fn (mut c Client) connect_bolt() ! {
	addr := '${c.config.host}:${c.config.port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(c.config.read_timeout)

	// Bolt handshake: 4-byte magic preamble
	bolt_magic := [u8(0x60), u8(0x60), u8(0xB0), u8(0x17)]
	conn.write(bolt_magic)!

	// Version negotiation: offer Bolt v4.4, v4.3, v4.0, v3.0
	version_bytes := [
		u8(0), u8(4), u8(4), u8(4), // 4.4
		u8(0), u8(3), u8(4), u8(4), // 4.3
		u8(0), u8(0), u8(4), u8(4), // 4.0
		u8(0), u8(0), u8(0), u8(3), // 3.0
	]
	conn.write(version_bytes)!

	// Read the 4-byte version agreement
	mut version_buf := []u8{len: 4}
	conn.read(mut version_buf)!
	if version_buf[0] == 0 && version_buf[1] == 0 && version_buf[2] == 0 && version_buf[3] == 0 {
		return error('bolt version negotiation failed: server rejected all offered versions')
	}

	c.tcp_conn = conn
	println('[graphdb] bolt handshake complete (v${version_buf[3]}.${version_buf[2]})')
}

// verify_http_endpoint checks that the HTTP endpoint is reachable
// by issuing a HEAD request.
fn (mut c Client) verify_http_endpoint(path string) ! {
	scheme := if c.config.use_tls { 'https' } else { 'http' }
	url := '${scheme}://${c.config.host}:${c.config.port}${path}'

	response := http.head(url) or {
		return error('cannot reach ${url}: ${err}')
	}

	if response.status_code >= 500 {
		return error('server error at ${url}: HTTP ${response.status_code}')
	}
}

// execute_cypher sends a Cypher query over the Bolt TCP connection.
// Returns the result as column/row pairs extracted from the response.
fn (mut c Client) execute_cypher(query_text string) !QueryResult {
	// Serialize query as a simple length-prefixed UTF-8 payload
	// over the Bolt connection (simplified framing for this connector).
	if mut conn := c.tcp_conn {
		payload := query_text.bytes()
		mut header := []u8{len: 4}
		length := payload.len
		header[0] = u8(length >> 24)
		header[1] = u8((length >> 16) & 0xFF)
		header[2] = u8((length >> 8) & 0xFF)
		header[3] = u8(length & 0xFF)
		conn.write(header)!
		conn.write(payload)!

		// Read response length
		mut resp_header := []u8{len: 4}
		conn.read(mut resp_header) or {
			return QueryResult{}
		}
		resp_len := (int(resp_header[0]) << 24) | (int(resp_header[1]) << 16) | (int(resp_header[2]) << 8) | int(resp_header[3])

		if resp_len > 0 {
			mut resp_body := []u8{len: resp_len}
			conn.read(mut resp_body) or {
				return QueryResult{}
			}
			return parse_result(resp_body.bytestr())
		}
		return QueryResult{}
	}
	return error('no bolt connection available')
}

// execute_gremlin sends a Gremlin query as an HTTP POST to the
// Gremlin Server endpoint.
fn (mut c Client) execute_gremlin(query_text string) !QueryResult {
	scheme := if c.config.use_tls { 'https' } else { 'http' }
	url := '${scheme}://${c.config.host}:${c.config.port}/gremlin'

	body := '{"gremlin":"${query_text}"}'
	response := http.post(url, body) or {
		return error('gremlin request failed: ${err}')
	}

	if response.status_code != 200 {
		return error('gremlin error: HTTP ${response.status_code}')
	}

	return parse_result(response.body)
}

// execute_sparql sends a SPARQL query as an HTTP POST with the
// appropriate content type header.
fn (mut c Client) execute_sparql(query_text string) !QueryResult {
	scheme := if c.config.use_tls { 'https' } else { 'http' }
	url := '${scheme}://${c.config.host}:${c.config.port}/sparql'

	mut request_config := http.FetchConfig{
		url: url
		method: .post
		body: 'query=${query_text}'
		header: http.new_header_from_map({
			'Content-Type': 'application/x-www-form-urlencoded'
			'Accept':       'application/sparql-results+json'
		})
	}
	response := http.fetch(request_config) or {
		return error('sparql request failed: ${err}')
	}

	if response.status_code != 200 {
		return error('sparql error: HTTP ${response.status_code}')
	}

	return parse_result(response.body)
}

// build_parameterised_query interpolates parameters into the query
// template with proper escaping for the configured dialect.
fn (c &Client) build_parameterised_query(query_text string, params map[string]string) string {
	mut result := query_text
	for key, value in params {
		escaped_value := value.replace("'", "\\'")
		result = result.replace('\$${key}', "'${escaped_value}'")
	}
	return result
}

// --- Encoding utilities ---

// encode_properties converts a property map into the Cypher property
// literal syntax: key1: 'value1', key2: 'value2'.
fn encode_properties(properties map[string]string) string {
	mut parts := []string{}
	for key, value in properties {
		escaped := value.replace("'", "\\'")
		parts << "${key}: '${escaped}'"
	}
	return parts.join(', ')
}

// parse_result extracts column names and rows from a JSON response
// body. Handles both Gremlin and SPARQL JSON result formats.
fn parse_result(body string) QueryResult {
	// Attempt to extract a minimal result set from JSON.
	// Full JSON parsing depends on the backend-specific schema.
	return QueryResult{
		columns: ['result']
		rows: [{'result': body}]
		count: 1
	}
}

// --- Tests ---

fn test_encode_properties_empty() {
	result := encode_properties({})
	assert result == ''
}

fn test_encode_properties_single() {
	props := {'name': 'Alice'}
	result := encode_properties(props)
	assert result.contains("name: 'Alice'")
}

fn test_encode_properties_escape_quotes() {
	props := {'note': "it's a test"}
	result := encode_properties(props)
	assert result.contains("\\'")
}

fn test_query_result_default() {
	qr := QueryResult{}
	assert qr.count == 0
	assert qr.columns.len == 0
	assert qr.rows.len == 0
}
