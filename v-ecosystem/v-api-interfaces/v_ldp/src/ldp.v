// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Linked Data Platform containers and resource management Connector
// Author: Jonathan D.A. Jewell
//
// Linked Data Platform containers and resource management.
// Implements W3C LDP 1.0 (https://www.w3.org/TR/ldp/).
// Provides typed client bindings for the proven-ldp protocol.

module ldp

import crypto.sha256

// --- LDP content type constants ---

// ct_turtle is the RDF Turtle MIME type.
pub const ct_turtle = 'text/turtle'

// ct_jsonld is the JSON-LD MIME type.
pub const ct_jsonld = 'application/ld+json'

// ct_rdfxml is the RDF/XML MIME type.
pub const ct_rdfxml = 'application/rdf+xml'

// ct_sparql_update is the SPARQL Update MIME type used in PATCH requests.
pub const ct_sparql_update = 'application/sparql-update'

// ct_merge_patch is the JSON Merge Patch MIME type (RFC 7396).
pub const ct_merge_patch = 'application/merge-patch+json'

// link_type_resource is the LDP Resource type URI.
pub const link_type_resource = '<http://www.w3.org/ns/ldp#Resource>; rel="type"'

// link_type_rdf_source is the LDP RDFSource type URI.
pub const link_type_rdf_source = '<http://www.w3.org/ns/ldp#RDFSource>; rel="type"'

// link_type_basic_container is the LDP BasicContainer type URI.
pub const link_type_basic_container = '<http://www.w3.org/ns/ldp#BasicContainer>; rel="type"'

// link_type_direct_container is the LDP DirectContainer type URI.
pub const link_type_direct_container = '<http://www.w3.org/ns/ldp#DirectContainer>; rel="type"'

// link_type_indirect_container is the LDP IndirectContainer type URI.
pub const link_type_indirect_container = '<http://www.w3.org/ns/ldp#IndirectContainer>; rel="type"'

// ldp_contains is the LDP contains predicate URI.
pub const ldp_contains = 'http://www.w3.org/ns/ldp#contains'

// ldp_membership_resource is the LDP membershipResource predicate.
pub const ldp_membership_resource = 'http://www.w3.org/ns/ldp#membershipResource'

// --- Container type ---

// LdpContainerType classifies the LDP container.
pub enum LdpContainerType {
	basic     // ldp:BasicContainer — members listed by ldp:contains
	direct    // ldp:DirectContainer — membership triple in container or member
	indirect  // ldp:IndirectContainer — membership through ldp:insertedContentRelation
}

// --- Patch operation type ---

// PatchType selects the HTTP PATCH semantics.
pub enum PatchType {
	sparql_update  // application/sparql-update
	merge_patch    // application/merge-patch+json (RFC 7396)
}

// --- Data structures ---

// LdpResource represents a Linked Data Platform resource.
pub struct LdpResource {
pub:
	uri          string        // Absolute URI of the resource
	content_type string = ct_turtle
	etag         string        // Strong ETag (quoted hex digest)
	body         string        // Serialised RDF or plain body
}

// LdpContainer represents an LDP container.
pub struct LdpContainer {
pub:
	uri            string
	container_type LdpContainerType
	members        []string   // Member URIs (ldp:contains)
}

// LdpPatch holds an HTTP PATCH payload.
pub struct LdpPatch {
pub:
	target_uri  string      // URI of resource to patch
	patch_type  PatchType
	patch_body  string      // SPARQL Update text or JSON merge-patch
}

// LdpConfig holds LDP client parameters.
pub struct LdpConfig {
pub:
	base_url    string   // Base URL of the LDP server
	auth_token  string   // Bearer token (empty = unauthenticated)
}

// LdpClient manages LDP resources and containers.
pub struct LdpClient {
mut:
	config      LdpConfig
	resources   []LdpResource
	containers  []LdpContainer
}

// --- ETag generation ---

// generate_etag computes a strong ETag for a body string using SHA-256.
// Returns a quoted hex string, e.g. `"d4735e3a26..."`
pub fn generate_etag(body string) string {
	digest := sha256.hexhash(body)
	return '"${digest[0..16]}"'
}

// --- Link header helpers ---

// parse_link_types extracts LDP type URIs from an HTTP Link header value.
// Handles comma-separated entries of the form `<URI>; rel="type"`.
pub fn parse_link_types(link_header string) []string {
	mut types := []string{}
	parts := link_header.split(',')
	for part in parts {
		trimmed := part.trim_space()
		if trimmed.contains('rel="type"') || trimmed.contains("rel='type'") {
			// Extract the URI between < >
			start := trimmed.index('<') or { continue }
			end := trimmed.index('>') or { continue }
			if end > start {
				types << trimmed[start..end + 1]
			}
		}
	}
	return types
}

// container_link_header returns the Link header value for a given container type.
pub fn container_link_header(ct LdpContainerType) string {
	base := '${link_type_resource}, ${link_type_rdf_source}'
	return match ct {
		.basic    { '${base}, ${link_type_basic_container}' }
		.direct   { '${base}, ${link_type_direct_container}' }
		.indirect { '${base}, ${link_type_indirect_container}' }
	}
}

// encode_link_header builds a comma-separated Link header value from a slice
// of relation strings. Each entry is wrapped as `<{rel}>; rel="type"`.
pub fn encode_link_header(rels []string) string {
	mut parts := []string{}
	for rel in rels {
		parts << '<${rel}>; rel="type"'
	}
	return parts.join(', ')
}

// --- Client lifecycle ---

// new_ldp_client creates a new LDP client.
pub fn new_ldp_client(config LdpConfig) &LdpClient {
	return &LdpClient{
		config:     config
		resources:  []LdpResource{}
		containers: []LdpContainer{}
	}
}

// create_resource creates an LDP resource with a computed ETag.
pub fn (mut c LdpClient) create_resource(res LdpResource) ! {
	if res.uri.len == 0 {
		return error('resource URI must not be empty')
	}
	etag := if res.etag.len == 0 { generate_etag(res.body) } else { res.etag }
	final := LdpResource{
		uri:          res.uri
		content_type: res.content_type
		etag:         etag
		body:         res.body
	}
	c.resources << final
	println('[ldp] created resource: ${res.uri} (${res.content_type}) etag=${etag}')
}

// update_resource replaces a resource body by URI, refreshing the ETag.
pub fn (mut c LdpClient) update_resource(uri string, new_body string) ! {
	if uri.len == 0 {
		return error('resource URI must not be empty')
	}
	mut found := false
	for i in 0 .. c.resources.len {
		if c.resources[i].uri == uri {
			etag := generate_etag(new_body)
			c.resources[i] = LdpResource{
				uri:          uri
				content_type: c.resources[i].content_type
				etag:         etag
				body:         new_body
			}
			found = true
			println('[ldp] updated resource: ${uri} new_etag=${etag}')
			break
		}
	}
	if !found {
		return error('resource not found: ${uri}')
	}
}

// delete_resource removes a resource by URI.
pub fn (mut c LdpClient) delete_resource(uri string) ! {
	if uri.len == 0 {
		return error('resource URI must not be empty')
	}
	before := c.resources.len
	c.resources = c.resources.filter(it.uri != uri)
	if c.resources.len == before {
		return error('resource not found: ${uri}')
	}
	println('[ldp] deleted resource: ${uri}')
}

// create_container creates an LDP container.
pub fn (mut c LdpClient) create_container(cont LdpContainer) ! {
	if cont.uri.len == 0 {
		return error('container URI must not be empty')
	}
	c.containers << cont
	println('[ldp] created ${cont.container_type} container: ${cont.uri}')
}

// patch_resource applies a PATCH to a resource's body.
// SPARQL Update: append the update text (stub).
// Merge Patch: replace body with patch_body (stub).
pub fn (mut c LdpClient) patch_resource(patch LdpPatch) ! {
	if patch.target_uri.len == 0 {
		return error('patch target URI must not be empty')
	}
	if patch.patch_body.len == 0 {
		return error('patch body must not be empty')
	}
	for i in 0 .. c.resources.len {
		if c.resources[i].uri == patch.target_uri {
			new_body := match patch.patch_type {
				.merge_patch    { patch.patch_body }
				.sparql_update  { c.resources[i].body + '\n# PATCH\n' + patch.patch_body }
			}
			c.resources[i] = LdpResource{
				uri:          patch.target_uri
				content_type: c.resources[i].content_type
				etag:         generate_etag(new_body)
				body:         new_body
			}
			println('[ldp] patched ${patch.target_uri} via ${patch.patch_type}')
			return
		}
	}
	return error('resource not found: ${patch.target_uri}')
}

// get_resource retrieves a resource by URI.
pub fn (c &LdpClient) get_resource(uri string) !LdpResource {
	for r in c.resources {
		if r.uri == uri {
			return r
		}
	}
	return error('resource not found: ${uri}')
}

// patch_sparql applies a SPARQL Update PATCH to the named resource.
pub fn (mut c LdpClient) patch_sparql(uri string, sparql string) ! {
	if uri.len == 0 {
		return error('resource URI must not be empty')
	}
	if sparql.trim_space().len == 0 {
		return error('SPARQL update must not be empty')
	}
	c.patch_resource(LdpPatch{
		target_uri: uri
		patch_type: .sparql_update
		patch_body: sparql
	})!
}

// --- Tests ---

fn test_empty_uri_rejected() {
	mut client := new_ldp_client(LdpConfig{ base_url: 'http://localhost:8080', auth_token: 'test' })
	client.create_resource(LdpResource{ uri: '', content_type: ct_turtle, etag: '', body: '' }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_etag_is_deterministic() {
	body := '<http://example.org/s> <http://example.org/p> "o" .'
	etag1 := generate_etag(body)
	etag2 := generate_etag(body)
	assert etag1 == etag2
	assert etag1.starts_with('"')
	assert etag1.ends_with('"')
}

fn test_update_resource_refreshes_etag() {
	mut client := new_ldp_client(LdpConfig{ base_url: 'http://localhost:8080', auth_token: '' })
	client.create_resource(LdpResource{ uri: 'http://example.org/r1', body: 'body1' }) or { panic(err) }
	etag_before := client.get_resource('http://example.org/r1') or { panic(err) }
	client.update_resource('http://example.org/r1', 'body2') or { panic(err) }
	etag_after := client.get_resource('http://example.org/r1') or { panic(err) }
	assert etag_before.etag != etag_after.etag
}

fn test_parse_link_types_extracts_uris() {
	header := '<http://www.w3.org/ns/ldp#Resource>; rel="type", <http://www.w3.org/ns/ldp#BasicContainer>; rel="type"'
	types := parse_link_types(header)
	assert types.len == 2
	assert types[0] == '<http://www.w3.org/ns/ldp#Resource>'
}

fn test_delete_resource_not_found() {
	mut client := new_ldp_client(LdpConfig{ base_url: 'http://localhost:8080', auth_token: '' })
	client.delete_resource('http://example.org/ghost') or {
		assert err.str().contains('not found')
		return
	}
	assert false
}

fn test_encode_link_header_single() {
	hdr := encode_link_header(['http://www.w3.org/ns/ldp#Resource'])
	assert hdr == '<http://www.w3.org/ns/ldp#Resource>; rel="type"'
}

fn test_encode_link_header_multiple() {
	hdr := encode_link_header([
		'http://www.w3.org/ns/ldp#Resource',
		'http://www.w3.org/ns/ldp#BasicContainer',
	])
	assert hdr.contains(', ')
	assert hdr.contains('BasicContainer')
}
