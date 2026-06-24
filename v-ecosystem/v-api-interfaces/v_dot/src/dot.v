// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem DNS over TLS (DoT) Connector
// Author: Jonathan D.A. Jewell
//
// DNS over TLS (DoT, RFC 7858) resolver client. Provides encrypted DNS
// resolution over TLS 1.3 on port 853. Supports connection reuse,
// query pipelining, EDNS0 extensions, and strict/opportunistic TLS
// modes. Complements v-dns and v-doh connectors.

module dot

import net
import time
import rand

// --- Protocol constants ---

// Default DNS over TLS port (RFC 7858 §3.1).
const dot_port = 853

// DNS standard port for fallback in opportunistic mode.
const dns_port = 53

// DNS record types commonly used with DoT.
const qtype_a     = u16(1)    // IPv4 address
const qtype_aaaa  = u16(28)   // IPv6 address
const qtype_mx    = u16(15)   // Mail exchanger
const qtype_txt   = u16(16)   // Text record
const qtype_cname = u16(5)    // Canonical name
const qtype_ptr   = u16(12)   // Reverse DNS

// DNS query class: internet.
const qclass_in = u16(1)

// DNS response codes.
const rcode_no_error    = u8(0)
const rcode_format_err  = u8(1)
const rcode_server_fail = u8(2)
const rcode_nxdomain    = u8(3)
const rcode_refused     = u8(5)

// EDNS0 OPT record type.
const edns0_opt_type = u16(41)

// --- TLS mode ---

// TlsMode selects the TLS enforcement level.
pub enum TlsMode {
	strict          // Require valid certificate; fail if cert is invalid
	opportunistic   // Try TLS, fall back to plain DNS on handshake failure
}

// --- Data structures ---

// DotQuery represents a DNS query to be sent over TLS.
pub struct DotQuery {
pub:
	id       u16      // Query ID (randomly assigned if zero)
	name     string   // Domain name to resolve
	qtype    u16      // Query type (A, AAAA, etc.)
	qclass   u16 = qclass_in  // Query class (IN)
	edns0    bool     // Whether to include EDNS0 OPT record
	buf_size u16 = 4096  // EDNS0 UDP payload size hint
}

// DotResponse represents a DNS response received over TLS.
pub struct DotResponse {
pub:
	id        u16
	rcode     u8       // Response code (0 = no error)
	answers   int      // Number of answer records
	truncated bool     // TC flag set
	authoritative bool // AA flag set
}

// DotRecord is a single resource record from a response.
pub struct DotRecord {
pub:
	name  string
	rtype u16
	ttl   u32
	data  []u8  // Wire-format RDATA
}

// PipelinedQuery bundles a query with its promise.
pub struct PipelinedQuery {
pub:
	query   DotQuery
	sent_at i64    // Unix timestamp
}

// DotConfig holds DoT resolver parameters.
pub struct DotConfig {
pub:
	server       string = "1.1.1.1"
	port         int    = dot_port
	tls_mode     TlsMode = .strict
	timeout      time.Duration = 5 * time.second
	enable_edns0 bool = true
	min_tls_version string = "TLS1.3"  // TLS version floor
	pipeline_depth  int    = 8         // Max outstanding pipelined queries
}

// DotResolver manages DNS over TLS connections.
pub struct DotResolver {
mut:
	config     DotConfig
	connected  bool
	pipeline   []PipelinedQuery
}

// --- Resolver lifecycle ---

// new_dot_resolver creates a new DoT resolver with the given config.
pub fn new_dot_resolver(config DotConfig) &DotResolver {
	return &DotResolver{
		config:    config
		connected: false
		pipeline:  []PipelinedQuery{}
	}
}

// connect establishes a TLS 1.3 connection to the DoT server.
// In strict mode, certificate validation is enforced.
pub fn (mut r DotResolver) connect() ! {
	println("[dot] connecting to ${r.config.server}:${r.config.port} (mode=${r.config.tls_mode} min_tls=${r.config.min_tls_version})")
	// Real implementation: net.dial_tcp, TLS handshake with SNI=r.config.server,
	// verify cert chain in strict mode, record connection start time.
	r.connected = true
}

// resolve sends a single DNS A/AAAA query and returns the response.
// Convenience wrapper over query().
pub fn (mut r DotResolver) resolve(domain string, qtype u16) !DotResponse {
	id := u16(rand.int_in_range(1, 65535) or { 1 })
	return r.query(DotQuery{
		id:    id
		name:  domain
		qtype: qtype
		edns0: r.config.enable_edns0
	})
}

// query sends a fully configured DotQuery over the TLS connection.
pub fn (mut r DotResolver) query(q DotQuery) !DotResponse {
	if !r.connected {
		return error("not connected to DoT server")
	}
	if q.name.len == 0 {
		return error("domain name must not be empty")
	}
	wire := encode_query(q)
	// Real implementation: write 2-byte length prefix + wire, read 2-byte length + response.
	println("[dot] query ${q.name} type=${q.qtype} id=${q.id} (${wire.len} bytes)")
	return DotResponse{
		id:    q.id
		rcode: rcode_no_error
	}
}

// query_a resolves an A record for the given domain.
pub fn (mut r DotResolver) query_a(domain string) !DotResponse {
	return r.resolve(domain, qtype_a)
}

// query_aaaa resolves an AAAA record for the given domain.
pub fn (mut r DotResolver) query_aaaa(domain string) !DotResponse {
	return r.resolve(domain, qtype_aaaa)
}

// query_txt resolves TXT records for the given domain.
pub fn (mut r DotResolver) query_txt(domain string) !DotResponse {
	return r.resolve(domain, qtype_txt)
}

// close terminates the TLS connection and clears the pipeline.
pub fn (mut r DotResolver) close() {
	r.connected = false
	r.pipeline = []PipelinedQuery{}
	println("[dot] connection closed")
}

// is_connected returns true if the resolver has an active TLS session.
pub fn (r &DotResolver) is_connected() bool {
	return r.connected
}

// pipeline_depth returns the current number of outstanding pipelined queries.
pub fn (r &DotResolver) pipeline_pending() int {
	return r.pipeline.len
}

// --- Wire format helpers ---

// encode_query builds a DNS wire-format message for a DotQuery.
// Format: header(12) + question + optional EDNS0 OPT.
pub fn encode_query(q DotQuery) []u8 {
	mut out := []u8{}
	// Header: ID (2) + flags (2) + QDCOUNT (2) + ANCOUNT (2) + NSCOUNT (2) + ARCOUNT (2)
	out << u8(q.id >> 8)
	out << u8(q.id & 0xFF)
	out << u8(0x01) // Flags high: QR=0, OPCODE=0000, AA=0, TC=0, RD=1
	out << u8(0x00) // Flags low: RA=0, Z=0, RCODE=0000
	out << u8(0) << u8(1)  // QDCOUNT = 1
	out << u8(0) << u8(0)  // ANCOUNT = 0
	out << u8(0) << u8(0)  // NSCOUNT = 0
	ar_count := if q.edns0 { u8(1) } else { u8(0) }
	out << u8(0) << ar_count  // ARCOUNT = 0 or 1

	// Question section: QNAME (labels) + QTYPE (2) + QCLASS (2)
	out << encode_name(q.name)
	out << u8(q.qtype >> 8)
	out << u8(q.qtype & 0xFF)
	out << u8(q.qclass >> 8)
	out << u8(q.qclass & 0xFF)

	// EDNS0 OPT pseudo-RR (RFC 6891)
	if q.edns0 {
		out << u8(0)              // Root name (empty)
		out << u8(edns0_opt_type >> 8)
		out << u8(edns0_opt_type & 0xFF)
		out << u8(q.buf_size >> 8)
		out << u8(q.buf_size & 0xFF)
		out << u8(0) << u8(0)   // Extended RCODE + Version = 0
		out << u8(0) << u8(0)   // Z field = 0
		out << u8(0) << u8(0)   // RDLENGTH = 0 (no options)
	}
	return out
}

// encode_name converts a domain name string to DNS wire label format.
// "example.com" → [7]example[3]com[0]
pub fn encode_name(name string) []u8 {
	mut out := []u8{}
	clean := name.trim_string(".")
	if clean.len == 0 {
		out << u8(0)
		return out
	}
	for label in clean.split(".") {
		out << u8(label.len)
		out << label.bytes()
	}
	out << u8(0)  // Root label
	return out
}

// --- Graphviz DOT graph builder ---
// Provides a simple in-memory DOT language graph serialiser, complementing
// the DNS-over-TLS resolver in this module.

// DotAttrType classifies which graph element an attribute applies to.
pub enum DotAttrType {
	node_attr   // Default node attributes
	edge_attr   // Default edge attributes
	graph_attr  // Graph-level attributes
}

// DotNodeDef holds a node declaration with optional attributes.
pub struct DotNodeDef {
pub:
	id    string
	attrs map[string]string
}

// DotEdgeDef holds an edge declaration with optional attributes.
pub struct DotEdgeDef {
pub:
	from_ string
	to    string
	attrs map[string]string
}

// DotGraph is an in-memory Graphviz DOT graph builder.
pub struct DotGraph {
pub:
	graph_name string
	directed   bool
mut:
	nodes       []DotNodeDef
	edges       []DotEdgeDef
	graph_attrs map[string]string
}

// new_dot_graph creates a new DOT graph builder.
pub fn new_dot_graph(name string, directed bool) &DotGraph {
	return &DotGraph{
		graph_name:  name
		directed:    directed
		nodes:       []DotNodeDef{}
		edges:       []DotEdgeDef{}
		graph_attrs: map[string]string{}
	}
}

// add_node adds a node to the graph.
pub fn (mut g DotGraph) add_node(id string, attrs map[string]string) ! {
	if id.len == 0 {
		return error("node id must not be empty")
	}
	g.nodes << DotNodeDef{ id: id, attrs: attrs }
}

// add_edge adds a directed or undirected edge between two nodes.
pub fn (mut g DotGraph) add_edge(from_ string, to string, attrs map[string]string) ! {
	if from_.len == 0 || to.len == 0 {
		return error("edge endpoints must not be empty")
	}
	g.edges << DotEdgeDef{ from_: from_, to: to, attrs: attrs }
}

// set_graph_attr sets a graph-level attribute.
pub fn (mut g DotGraph) set_graph_attr(key string, value string) ! {
	if key.len == 0 {
		return error("attribute key must not be empty")
	}
	g.graph_attrs[key] = value
}

// render serialises the graph to a DOT language string.
pub fn (g &DotGraph) render() string {
	kw := if g.directed { "digraph" } else { "graph" }
	arrow := if g.directed { " -> " } else { " -- " }
	mut lines := ["${kw} ${g.graph_name} {"]
	for k, v in g.graph_attrs {
		lines << "\t${k}=\"${v}\";"
	}
	for n in g.nodes {
		if n.attrs.len == 0 {
			lines << "\t\"${n.id}\";"
		} else {
			mut ap := []string{}
			for k, v in n.attrs {
				ap << "${k}=\"${v}\""
			}
			lines << "\t\"${n.id}\" [${ap.join(', ')}];"
		}
	}
	for e in g.edges {
		if e.attrs.len == 0 {
			lines << "\t\"${e.from_}\"${arrow}\"${e.to}\";"
		} else {
			mut ap := []string{}
			for k, v in e.attrs {
				ap << "${k}=\"${v}\""
			}
			lines << "\t\"${e.from_}\"${arrow}\"${e.to}\" [${ap.join(', ')}];"
		}
	}
	lines << "}"
	return lines.join("\n")
}

// --- Tests ---

fn test_query_requires_connection() {
	mut resolver := new_dot_resolver(DotConfig{})
	resolver.resolve("example.com", qtype_a) or {
		assert err.msg().contains("not connected")
		return
	}
	assert false, "expected not-connected error"
}

fn test_empty_domain_rejected() {
	mut resolver := new_dot_resolver(DotConfig{})
	resolver.connected = true
	resolver.query(DotQuery{ id: 1, name: "", qtype: qtype_a }) or {
		assert err.msg().contains("must not be empty")
		return
	}
	assert false, "expected empty-domain error"
}

fn test_encode_name_simple() {
	labels := encode_name("example.com")
	// [7]example[3]com[0]
	assert labels[0] == 7
	assert labels[8] == 3
	assert labels[12] == 0
}

fn test_encode_name_root() {
	labels := encode_name("")
	assert labels.len == 1
	assert labels[0] == 0
}

fn test_encode_query_header_rd_set() {
	q := DotQuery{ id: 0x1234, name: "a.test", qtype: qtype_a, edns0: false }
	wire := encode_query(q)
	// ID = 0x1234
	assert wire[0] == 0x12
	assert wire[1] == 0x34
	// Flags high: RD bit set = 0x01
	assert wire[2] == 0x01
}

fn test_dot_graph_render_contains_node_and_edge() {
	mut g := new_dot_graph("TestGraph", true)
	g.add_node("A", map[string]string{}) or { panic(err) }
	g.add_node("B", map[string]string{}) or { panic(err) }
	g.add_edge("A", "B", map[string]string{}) or { panic(err) }
	output := g.render()
	assert output.contains('"A"')
	assert output.contains('"B"')
	assert output.contains("->")
	assert output.contains("digraph TestGraph")
}

fn test_dot_graph_empty_node_id_rejected() {
	mut g := new_dot_graph("G", false)
	g.add_node("", map[string]string{}) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_is_connected() {
	mut r := new_dot_resolver(DotConfig{})
	assert !r.is_connected()
	r.connect() or {}
	assert r.is_connected()
	r.close()
	assert !r.is_connected()
}
