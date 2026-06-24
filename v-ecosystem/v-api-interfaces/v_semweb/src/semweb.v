// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Semantic Web toolkit with RDF parsing, OWL reasoning, and SHACL validation Connector
// Author: Jonathan D.A. Jewell
//
// Semantic Web toolkit with RDF parsing, OWL reasoning, and SHACL validation.
// Implements RDF Triple model, Turtle line parser, and OWL class hierarchy helpers.
// Provides typed client bindings for the proven-semweb protocol.

module semweb

// --- Well-known RDF/OWL/SHACL namespace URIs ---

// ns_rdf is the RDF namespace URI.
pub const ns_rdf = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'

// ns_rdfs is the RDF Schema namespace URI.
pub const ns_rdfs = 'http://www.w3.org/2000/01/rdf-schema#'

// ns_owl is the OWL namespace URI.
pub const ns_owl = 'http://www.w3.org/2002/07/owl#'

// ns_xsd is the XML Schema Datatype namespace URI.
pub const ns_xsd = 'http://www.w3.org/2001/XMLSchema#'

// ns_shacl is the SHACL namespace URI.
pub const ns_shacl = 'http://www.w3.org/ns/shacl#'

// pred_type is the rdf:type predicate.
pub const pred_type = '${ns_rdf}type'

// pred_subclass_of is the rdfs:subClassOf predicate.
pub const pred_subclass_of = '${ns_rdfs}subClassOf'

// pred_domain is the rdfs:domain predicate.
pub const pred_domain = '${ns_rdfs}domain'

// pred_range is the rdfs:range predicate.
pub const pred_range = '${ns_rdfs}range'

// owl_class is the owl:Class IRI.
pub const owl_class = '${ns_owl}Class'

// --- RDF term types ---

// RdfTermKind classifies an RDF term.
pub enum RdfTermKind {
	iri        // IRI reference (absolute or prefixed)
	literal    // Literal value (plain, language-tagged, or typed)
	blank_node // Blank node (_:localname)
}

// RdfTerm represents a single RDF term (subject, predicate, or object).
pub struct RdfTerm {
pub:
	kind      RdfTermKind
	value     string   // IRI string, literal lexical form, or blank node identifier
	lang      string   // Language tag for lang-tagged literals (e.g. "en")
	datatype  string   // Datatype IRI for typed literals (empty = xsd:string)
}

// iri creates an IRI RDF term.
pub fn iri(value string) RdfTerm {
	return RdfTerm{ kind: .iri, value: value }
}

// literal creates a plain literal RDF term.
pub fn literal(value string) RdfTerm {
	return RdfTerm{ kind: .literal, value: value }
}

// typed_literal creates a typed literal RDF term.
pub fn typed_literal(value string, datatype string) RdfTerm {
	return RdfTerm{ kind: .literal, value: value, datatype: datatype }
}

// blank_node creates a blank node RDF term.
pub fn blank_node(id string) RdfTerm {
	return RdfTerm{ kind: .blank_node, value: id }
}

// str returns a Turtle-compatible string representation of a term.
pub fn (t RdfTerm) str() string {
	return match t.kind {
		.iri       { '<${t.value}>' }
		.blank_node { '_:${t.value}' }
		.literal   {
			if t.lang.len > 0 {
				'"${t.value}"@${t.lang}'
			} else if t.datatype.len > 0 {
				'"${t.value}"^^<${t.datatype}>'
			} else {
				'"${t.value}"'
			}
		}
	}
}

// --- Triple ---

// Triple represents an RDF triple (subject, predicate, object).
pub struct Triple {
pub:
	subject   RdfTerm   // Must be IRI or blank node
	predicate RdfTerm   // Must be IRI
	object    RdfTerm   // IRI, blank node, or literal
}

// str returns a Turtle serialisation of the triple (subject predicate object .).
pub fn (t Triple) str() string {
	return '${t.subject.str()} ${t.predicate.str()} ${t.object.str()} .'
}

// --- Graph ---

// Graph stores a collection of RDF triples keyed by subject IRI.
pub struct Graph {
pub mut:
	name    string
	triples []Triple
}

// add adds a triple to the graph.
pub fn (mut g Graph) add(t Triple) {
	g.triples << t
}

// triples_for returns all triples with a given subject IRI.
pub fn (g &Graph) triples_for(subject_iri string) []Triple {
	return g.triples.filter(it.subject.value == subject_iri)
}

// objects_of returns the object values for a given subject + predicate.
pub fn (g &Graph) objects_of(subject_iri string, predicate_iri string) []RdfTerm {
	return g.triples.filter(
		it.subject.value == subject_iri && it.predicate.value == predicate_iri
	).map(it.object)
}

// --- Turtle parser (single-line, <s> <p> <o> . form) ---

// parse_turtle_line parses a single Turtle triple line of the form:
//   <subject_iri> <predicate_iri> <object_iri_or_literal> .
// Supports: IRI objects <...>, plain literals "...", lang-tagged "..."@lang,
//           typed literals "..."^^<datatype>, and blank nodes _:id.
pub fn parse_turtle_line(line string) !Triple {
	trimmed := line.trim_space()
	if trimmed.len == 0 || trimmed.starts_with('#') {
		return error('empty or comment line')
	}
	// Strip trailing ' .' or '.'
	cleaned := if trimmed.ends_with(' .') {
		trimmed[..trimmed.len - 2].trim_space()
	} else if trimmed.ends_with('.') {
		trimmed[..trimmed.len - 1].trim_space()
	} else {
		trimmed
	}

	subject := parse_term_from_start(cleaned)!
	rest1 := cleaned[term_len(cleaned)..].trim_space()
	predicate := parse_term_from_start(rest1)!
	rest2 := rest1[term_len(rest1)..].trim_space()
	object := parse_term_from_start(rest2)!

	return Triple{ subject: subject, predicate: predicate, object: object }
}

// parse_term_from_start parses the first RDF term in a string.
fn parse_term_from_start(s string) !RdfTerm {
	if s.starts_with('<') {
		end := s.index('>') or { return error('unterminated IRI: ${s}') }
		return iri(s[1..end])
	}
	if s.starts_with('_:') {
		// Blank node: _:localname — ends at whitespace
		end_idx := find_token_end(s, 2)
		return blank_node(s[2..end_idx])
	}
	if s.starts_with('"') {
		return parse_literal_term(s)!
	}
	return error('cannot parse term from: ${s}')
}

// parse_literal_term parses a quoted literal possibly followed by @lang or ^^<type>.
fn parse_literal_term(s string) !RdfTerm {
	if s.len < 2 {
		return error('literal too short')
	}
	// Find closing quote
	mut i := 1
	for i < s.len && s[i] != `"` {
		if s[i] == `\\` { i++ }  // Skip escaped char
		i++
	}
	if i >= s.len {
		return error('unterminated literal: ${s}')
	}
	value := s[1..i]
	suffix := s[i+1..].trim_space()
	if suffix.starts_with('@') {
		lang := find_token_end_str(suffix[1..])
		return RdfTerm{ kind: .literal, value: value, lang: suffix[1..1+lang] }
	}
	if suffix.starts_with('^^') {
		dt_raw := suffix[2..].trim_space()
		if dt_raw.starts_with('<') {
			dt_end := dt_raw.index('>') or { return error('unterminated datatype IRI') }
			return typed_literal(value, dt_raw[1..dt_end])
		}
	}
	return literal(value)
}

// find_token_end returns the index after the current non-whitespace token starting at offset.
fn find_token_end(s string, start int) int {
	mut i := start
	for i < s.len && s[i] != ` ` && s[i] != `\t` && s[i] != `\n` {
		i++
	}
	return i
}

// find_token_end_str returns the length of the leading non-whitespace token.
fn find_token_end_str(s string) int {
	return find_token_end(s, 0)
}

// term_len returns the byte length of the first term in string s.
fn term_len(s string) int {
	if s.starts_with('<') {
		end := s.index('>') or { return s.len }
		return end + 1
	}
	if s.starts_with('_:') {
		return find_token_end(s, 2)
	}
	if s.starts_with('"') {
		mut i := 1
		for i < s.len && s[i] != `"` {
			if s[i] == `\\` { i++ }
			i++
		}
		i++  // include closing quote
		if i < s.len {
			rest := s[i..].trim_space()
			if rest.starts_with('@') {
				lang_end := find_token_end(rest, 1)
				return i + (s.len - i - rest.len) + lang_end
			}
			if rest.starts_with('^^') {
				dt_end := rest.index('>') or { return s.len }
				return i + (s.len - i - rest.len) + dt_end + 1
			}
		}
		return i
	}
	return find_token_end(s, 0)
}

// --- Turtle serialiser ---

// serialize_turtle serialises a graph to Turtle format with @prefix declarations.
pub fn serialize_turtle(g Graph, prefixes map[string]string) string {
	mut lines := []string{}
	for prefix, uri in prefixes {
		lines << '@prefix ${prefix}: <${uri}> .'
	}
	if prefixes.len > 0 {
		lines << ''
	}
	for t in g.triples {
		lines << t.str()
	}
	return lines.join('\n')
}

// --- OWL class hierarchy helpers ---

// subclass_of returns all direct superclasses of a class IRI in a graph.
pub fn subclass_of(g Graph, class_iri string) []string {
	return g.objects_of(class_iri, pred_subclass_of).map(it.value)
}

// instances_of returns all subject IRIs declared rdf:type class_iri.
pub fn instances_of(g Graph, class_iri string) []string {
	return g.triples.filter(
		it.predicate.value == pred_type && it.object.value == class_iri
	).map(it.subject.value)
}

// --- SHACL constraint types ---

// ShaclConstraintKind names common SHACL constraint component IRIs.
pub enum ShaclConstraintKind {
	min_count       // sh:minCount
	max_count       // sh:maxCount
	datatype        // sh:datatype
	node_kind       // sh:nodeKind
	class_constraint // sh:class
	pattern         // sh:pattern
}

// ShaclConstraint defines a single SHACL constraint on a property shape.
pub struct ShaclConstraint {
pub:
	kind    ShaclConstraintKind
	value   string   // Constraint value (count, IRI, regex, etc.)
	message string   // Human-readable violation message
}

// ShaclPropertyShape describes constraints on a property path.
pub struct ShaclPropertyShape {
pub:
	path        string             // Property IRI
	constraints []ShaclConstraint
}

// ShaclNodeShape defines a SHACL node shape for a target class.
pub struct ShaclNodeShape {
pub:
	target_class string
	properties   []ShaclPropertyShape
}

// ShaclReport represents a SHACL validation result.
pub struct ShaclReport {
pub:
	conforms   bool
	violations int
	warnings   int
}

// --- Engine lifecycle ---

// SemwebConfig holds Semantic Web toolkit parameters.
pub struct SemwebConfig {
pub:
	base_uri    string
	owl_profile OwlProfile = .owl_rl
	validate    bool = true
}

// OwlProfile selects the OWL reasoning profile.
pub enum OwlProfile {
	owl_el   // EL profile (polynomial reasoning)
	owl_ql   // QL profile (rewriting to SQL)
	owl_rl   // RL profile (rule-based)
	owl_dl   // DL profile (tableau)
	owl_full // Full OWL (undecidable)
}

// RdfFormat identifies the RDF serialisation format.
pub enum RdfFormat {
	turtle
	ntriples
	jsonld
	rdfxml
	trig
}

// RdfGraph represents a named RDF graph (legacy, kept for compatibility).
pub struct RdfGraph {
pub:
	name         string
	format       RdfFormat
	triple_count int
}

// SemwebEngine manages RDF graphs and reasoning.
pub struct SemwebEngine {
mut:
	config  SemwebConfig
	graphs  []RdfGraph
	store   map[string]Graph   // In-memory triple store keyed by graph name
}

// new_semweb_engine creates a new Semantic Web engine.
pub fn new_semweb_engine(config SemwebConfig) &SemwebEngine {
	return &SemwebEngine{
		config: config
		graphs: []RdfGraph{}
		store:  map[string]Graph{}
	}
}

// load_graph imports an RDF graph (legacy interface).
pub fn (mut e SemwebEngine) load_graph(graph RdfGraph) ! {
	if graph.name.len == 0 {
		return error('graph name must not be empty')
	}
	e.graphs << graph
	println('[semweb] loaded graph: ${graph.name} (${graph.format}, ${graph.triple_count} triples)')
}

// RdfTriple is a simple subject/predicate/object record (plain-string form for lightweight use).
pub struct RdfTriple {
pub:
	subject   string
	predicate string
	object_   string
}

// encode_turtle_triple serialises an RdfTriple as a Turtle statement.
pub fn encode_turtle_triple(t RdfTriple) string {
	subj := if t.subject.starts_with("http") { "<${t.subject}>" } else { t.subject }
	pred := if t.predicate.starts_with("http") { "<${t.predicate}>" } else { t.predicate }
	obj := if t.object_.starts_with('"') {
		t.object_
	} else if t.object_.starts_with("http") {
		"<${t.object_}>"
	} else {
		t.object_
	}
	return "${subj} ${pred} ${obj} ."
}

// parse_rdf_triple validates and constructs an RdfTriple from its components.
pub fn (e &SemwebEngine) parse_rdf_triple(subject string, predicate string, object_ string) !RdfTriple {
	if subject.len == 0 {
		return error("subject URI must not be empty")
	}
	if predicate.len == 0 {
		return error("predicate URI must not be empty")
	}
	if object_.len == 0 {
		return error("object must not be empty")
	}
	return RdfTriple{ subject: subject, predicate: predicate, object_: object_ }
}

// query_subjects returns all RdfTriple records for a given subject URI from the flat store.
pub fn (e &SemwebEngine) query_subjects(subject_uri string) ![]RdfTriple {
	if subject_uri.len == 0 {
		return error("subject_uri must not be empty")
	}
	mut results := []RdfTriple{}
	for _, g in e.store {
		for t in g.triples {
			if t.subject.value == subject_uri {
				results << RdfTriple{
					subject:   t.subject.value
					predicate: t.predicate.value
					object_:   t.object.value
				}
			}
		}
	}
	return results
}

// add_triple adds a triple to a named graph in the store, creating the graph if needed.
pub fn (mut e SemwebEngine) add_triple(graph_name string, t Triple) {
	if graph_name !in e.store {
		e.store[graph_name] = Graph{ name: graph_name }
	}
	e.store[graph_name].add(t)
}

// validate runs SHACL validation on a named graph (stub — real engine deferred).
pub fn (e &SemwebEngine) validate(graph_name string) !ShaclReport {
	println('[semweb] validating graph: ${graph_name}')
	return ShaclReport{ conforms: true, violations: 0, warnings: 0 }
}

// --- Tests ---

fn test_empty_graph_name_rejected() {
	mut engine := new_semweb_engine(SemwebConfig{ base_uri: 'http://example.org/' })
	engine.load_graph(RdfGraph{ name: '', format: .turtle, triple_count: 0 }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_parse_turtle_line_iri_triple() {
	line := '<http://example.org/s> <http://example.org/p> <http://example.org/o> .'
	t := parse_turtle_line(line) or { panic(err) }
	assert t.subject.kind == .iri
	assert t.subject.value == 'http://example.org/s'
	assert t.predicate.value == 'http://example.org/p'
	assert t.object.value == 'http://example.org/o'
}

fn test_parse_turtle_line_literal_object() {
	line := '<http://example.org/doc> <http://purl.org/dc/elements/1.1/title> "Hello World" .'
	t := parse_turtle_line(line) or { panic(err) }
	assert t.object.kind == .literal
	assert t.object.value == 'Hello World'
}

fn test_serialize_turtle_roundtrip() {
	mut g := Graph{ name: 'test' }
	g.add(Triple{
		subject:   iri('http://example.org/alice')
		predicate: iri(pred_type)
		object:    iri('http://schema.org/Person')
	})
	turtle := serialize_turtle(g, {'schema': 'http://schema.org/'})
	assert turtle.contains('<http://example.org/alice>')
	assert turtle.contains('@prefix schema:')
}

fn test_encode_turtle_triple_iri() {
	t := RdfTriple{
		subject:   "http://example.org/Alice"
		predicate: "http://xmlns.com/foaf/0.1/name"
		object_:   '"Alice"'
	}
	out := encode_turtle_triple(t)
	assert out.contains("<http://example.org/Alice>")
	assert out.contains('"Alice"')
	assert out.ends_with(".")
}

fn test_subclass_of_lookup() {
	mut g := Graph{ name: 'ont' }
	g.add(Triple{
		subject:   iri('http://example.org/Mammal')
		predicate: iri(pred_subclass_of)
		object:    iri('http://example.org/Animal')
	})
	supers := subclass_of(g, 'http://example.org/Mammal')
	assert supers.len == 1
	assert supers[0] == 'http://example.org/Animal'
}
