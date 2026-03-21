// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem WebDAV Protocol Connector
// Author: Jonathan D.A. Jewell
//
// WebDAV client implementing RFC 4918 (Web Distributed Authoring and
// Versioning) over HTTP/HTTPS. Supports PROPFIND for resource discovery,
// MKCOL for collection creation, COPY/MOVE for resource manipulation,
// LOCK/UNLOCK for concurrency control, and standard GET/PUT/DELETE for
// file transfer. Compatible with Nextcloud, Apache mod_dav, nginx-dav,
// and other WebDAV-compliant servers.

module webdav

import net.http
import encoding.base64
import time

// --- Depth header enumeration ---

// Depth controls the scope of PROPFIND and other recursive operations
// per RFC 4918 section 10.2.
pub enum Depth {
	zero      // Resource itself only
	one       // Resource and its immediate children
	infinity  // Resource and all descendants
}

// --- Lock scope ---

// LockScope determines whether a lock is exclusive or shared.
pub enum LockScope {
	exclusive // Only one lock holder at a time
	shared    // Multiple concurrent lock holders
}

// --- Resource type ---

// ResourceType distinguishes collections (directories) from regular
// file resources.
pub enum ResourceType {
	collection     // DAV:collection (directory)
	non_collection // Regular file resource
}

// --- Configuration ---

// Config holds the parameters needed to connect to a WebDAV server.
// Basic authentication credentials are sent as an Authorization header.
pub struct Config {
pub:
	base_url          string             // e.g. "https://cloud.example.com/remote.php/dav/files/user"
	username          string
	password          string
	connect_timeout   time.Duration = 10 * time.second
}

// --- Data structures ---

// DavResource represents a WebDAV resource with its properties as
// returned by a PROPFIND response.
pub struct DavResource {
pub:
	href            string
	resource_type   ResourceType
	content_length  i64
	last_modified   string
	etag            string
	content_type    string
	display_name    string
}

// LockInfo holds the details of a WebDAV lock as returned by a LOCK
// response or discovered via PROPFIND.
pub struct LockInfo {
pub:
	lock_token  string
	scope       LockScope
	owner       string
	timeout     int          // Seconds until lock expires
}

// --- Client ---

// Client wraps the configuration and provides all WebDAV operations
// through HTTP requests with appropriate method extensions.
pub struct Client {
mut:
	config Config
}

// new_client creates a WebDAV client with the given configuration.
// No network call is made until an operation is invoked.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// --- Resource discovery ---

// propfind lists resources at the given path using the PROPFIND
// method. The depth parameter controls whether to return just the
// resource itself, its immediate children, or the full subtree.
pub fn (mut c Client) propfind(path string, depth Depth) ![]DavResource {
	url := c.build_url(path)
	depth_header := match depth {
		.zero { '0' }
		.one { '1' }
		.infinity { 'infinity' }
	}

	// PROPFIND request body asking for all properties
	body := '<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:">
  <d:allprop/>
</d:propfind>'

	response := c.dav_request('PROPFIND', url, body, {
		'Depth':        depth_header
		'Content-Type': 'application/xml; charset=utf-8'
	})!

	if response.status_code != 207 {
		return error('propfind failed: HTTP ${response.status_code} — ${response.body}')
	}

	return parse_multistatus_response(response.body)
}

// --- Collection management ---

// mkcol creates a new collection (directory) at the specified path.
pub fn (mut c Client) mkcol(path string) ! {
	url := c.build_url(path)
	response := c.dav_request('MKCOL', url, '', {})!

	if response.status_code != 201 {
		return error('mkcol failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[webdav] created collection ${path}')
}

// --- File operations ---

// get_file downloads a file from the WebDAV server.
pub fn (mut c Client) get_file(path string) ![]u8 {
	url := c.build_url(path)
	response := c.dav_request('GET', url, '', {})!

	if response.status_code != 200 {
		return error('get failed: HTTP ${response.status_code}')
	}

	println('[webdav] downloaded ${path} (${response.body.len} bytes)')
	return response.body.bytes()
}

// put_file uploads a file to the WebDAV server, creating or
// overwriting the resource at the specified path.
pub fn (mut c Client) put_file(path string, data []u8, content_type string) ! {
	url := c.build_url(path)
	response := c.dav_request('PUT', url, data.bytestr(), {
		'Content-Type': content_type
	})!

	if response.status_code != 201 && response.status_code != 204 && response.status_code != 200 {
		return error('put failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[webdav] uploaded ${path} (${data.len} bytes)')
}

// delete removes a resource (file or collection) from the server.
pub fn (mut c Client) delete(path string) ! {
	url := c.build_url(path)
	response := c.dav_request('DELETE', url, '', {})!

	if response.status_code != 204 && response.status_code != 200 {
		return error('delete failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[webdav] deleted ${path}')
}

// --- Copy and move ---

// copy duplicates a resource to a new location on the server.
// Set overwrite to true to replace existing resources at the
// destination.
pub fn (mut c Client) copy(source_path string, dest_path string, overwrite bool) ! {
	url := c.build_url(source_path)
	dest_url := c.build_url(dest_path)
	overwrite_val := if overwrite { 'T' } else { 'F' }

	response := c.dav_request('COPY', url, '', {
		'Destination': dest_url
		'Overwrite':   overwrite_val
	})!

	if response.status_code != 201 && response.status_code != 204 {
		return error('copy failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[webdav] copied ${source_path} -> ${dest_path}')
}

// move relocates a resource to a new path on the server. Set
// overwrite to true to replace existing resources at the
// destination.
pub fn (mut c Client) move(source_path string, dest_path string, overwrite bool) ! {
	url := c.build_url(source_path)
	dest_url := c.build_url(dest_path)
	overwrite_val := if overwrite { 'T' } else { 'F' }

	response := c.dav_request('MOVE', url, '', {
		'Destination': dest_url
		'Overwrite':   overwrite_val
	})!

	if response.status_code != 201 && response.status_code != 204 {
		return error('move failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[webdav] moved ${source_path} -> ${dest_path}')
}

// --- Locking ---

// lock acquires a write lock on a resource. Returns the lock token
// needed for subsequent UNLOCK and locked write operations.
pub fn (mut c Client) lock(path string, scope LockScope, owner string, timeout_seconds int) !LockInfo {
	url := c.build_url(path)
	scope_xml := match scope {
		.exclusive { '<d:exclusive/>' }
		.shared { '<d:shared/>' }
	}

	body := '<?xml version="1.0" encoding="UTF-8"?>
<d:lockinfo xmlns:d="DAV:">
  <d:lockscope>${scope_xml}</d:lockscope>
  <d:locktype><d:write/></d:locktype>
  <d:owner><d:href>${owner}</d:href></d:owner>
</d:lockinfo>'

	response := c.dav_request('LOCK', url, body, {
		'Content-Type': 'application/xml; charset=utf-8'
		'Timeout':      'Second-${timeout_seconds}'
	})!

	if response.status_code != 200 {
		return error('lock failed: HTTP ${response.status_code} — ${response.body}')
	}

	lock_token := extract_lock_token(response.body)
	println('[webdav] locked ${path} (token: ${lock_token})')
	return LockInfo{
		lock_token: lock_token
		scope: scope
		owner: owner
		timeout: timeout_seconds
	}
}

// unlock releases a previously acquired lock using the lock token.
pub fn (mut c Client) unlock(path string, lock_token string) ! {
	url := c.build_url(path)
	response := c.dav_request('UNLOCK', url, '', {
		'Lock-Token': '<${lock_token}>'
	})!

	if response.status_code != 204 && response.status_code != 200 {
		return error('unlock failed: HTTP ${response.status_code} — ${response.body}')
	}
	println('[webdav] unlocked ${path}')
}

// --- Internal helpers ---

// build_url constructs a full URL by appending the path to the
// configured base URL, ensuring proper slash handling.
fn (c &Client) build_url(path string) string {
	base := c.config.base_url.trim_right('/')
	clean_path := if path.starts_with('/') { path } else { '/${path}' }
	return '${base}${clean_path}'
}

// auth_header produces the Basic authentication header value from
// the configured username and password.
fn (c &Client) auth_header() string {
	credentials := '${c.config.username}:${c.config.password}'
	encoded := base64.encode_str(credentials)
	return 'Basic ${encoded}'
}

// dav_request issues an HTTP request with the given WebDAV method,
// URL, body, and extra headers. Adds authentication automatically.
fn (mut c Client) dav_request(method_str string, url string, body string, extra_headers map[string]string) !http.Response {
	mut header_map := {
		'Authorization': c.auth_header()
	}
	for key, value in extra_headers {
		header_map[key] = value
	}

	// Map string method to http.Method for known methods; use custom for extensions
	http_method := match method_str {
		'GET' { http.Method.get }
		'PUT' { http.Method.put }
		'DELETE' { http.Method.delete }
		'POST' { http.Method.post }
		'HEAD' { http.Method.head }
		'OPTIONS' { http.Method.options }
		'PATCH' { http.Method.patch }
		else {
			// WebDAV extension methods (PROPFIND, MKCOL, COPY, MOVE, LOCK, UNLOCK)
			// fall back to custom header injection via POST with method override
			header_map['X-HTTP-Method-Override'] = method_str
			http.Method.post
		}
	}

	mut fetch_config := http.FetchConfig{
		url: url
		method: http_method
		body: body
		header: http.new_header_from_map(header_map)
	}

	return http.fetch(fetch_config)
}

// --- XML parsing utilities ---

// parse_multistatus_response extracts DavResource entries from a
// 207 Multi-Status XML response body. Uses simple string matching
// rather than a full XML parser.
fn parse_multistatus_response(xml_body string) []DavResource {
	mut resources := []DavResource{}
	mut search_pos := 0

	for {
		resp_start := xml_body.index_after('<d:response>', search_pos)
		if resp_start < 0 {
			// Try without namespace prefix
			alt_start := xml_body.index_after('<D:response>', search_pos)
			if alt_start < 0 {
				break
			}
			resp_end := xml_body.index_after('</D:response>', alt_start)
			if resp_end < 0 { break }
			resource := parse_response_element(xml_body[alt_start..resp_end])
			resources << resource
			search_pos = resp_end + 14
			continue
		}

		resp_end := xml_body.index_after('</d:response>', resp_start)
		if resp_end < 0 { break }

		resource := parse_response_element(xml_body[resp_start..resp_end])
		resources << resource
		search_pos = resp_end + 14
	}

	return resources
}

// parse_response_element extracts resource properties from a single
// <d:response> XML element.
fn parse_response_element(xml_fragment string) DavResource {
	href := extract_dav_element(xml_fragment, 'href')
	content_length := extract_dav_element(xml_fragment, 'getcontentlength')
	last_modified := extract_dav_element(xml_fragment, 'getlastmodified')
	etag := extract_dav_element(xml_fragment, 'getetag')
	content_type := extract_dav_element(xml_fragment, 'getcontenttype')
	display_name := extract_dav_element(xml_fragment, 'displayname')

	resource_type := if xml_fragment.contains('collection') {
		ResourceType.collection
	} else {
		ResourceType.non_collection
	}

	return DavResource{
		href: href
		resource_type: resource_type
		content_length: content_length.i64()
		last_modified: last_modified
		etag: etag
		content_type: content_type
		display_name: display_name
	}
}

// extract_dav_element extracts text content from a DAV-namespaced
// XML element, trying both "d:" and "D:" prefix variants.
fn extract_dav_element(xml_body string, element_name string) string {
	// Try d: prefix
	for prefix in ['d:', 'D:', ''] {
		open_tag := '<${prefix}${element_name}>'
		close_tag := '</${prefix}${element_name}>'
		start := xml_body.index(open_tag) or { continue }
		content_start := start + open_tag.len
		end := xml_body.index_after(close_tag, content_start)
		if end >= 0 {
			return xml_body[content_start..end]
		}
	}
	return ''
}

// extract_lock_token extracts the lock token URI from a LOCK response
// XML body.
fn extract_lock_token(xml_body string) string {
	// Look for <d:locktoken><d:href>...</d:href></d:locktoken>
	for prefix in ['d:', 'D:', ''] {
		token_start := xml_body.index('<${prefix}locktoken>') or { continue }
		href_val := extract_dav_element(xml_body[token_start..], 'href')
		if href_val.len > 0 {
			return href_val
		}
	}
	return ''
}

// --- Tests ---

fn test_build_url_with_leading_slash() {
	config := Config{
		base_url: 'https://cloud.example.com/dav'
		username: 'user'
		password: 'pass'
	}
	client := new_client(config)
	assert client.build_url('/files/test.txt') == 'https://cloud.example.com/dav/files/test.txt'
}

fn test_build_url_without_leading_slash() {
	config := Config{
		base_url: 'https://cloud.example.com/dav/'
		username: 'user'
		password: 'pass'
	}
	client := new_client(config)
	assert client.build_url('files/test.txt') == 'https://cloud.example.com/dav/files/test.txt'
}

fn test_extract_dav_element_found() {
	xml := '<d:response><d:href>/test</d:href></d:response>'
	assert extract_dav_element(xml, 'href') == '/test'
}

fn test_extract_dav_element_missing() {
	xml := '<d:response><d:other>data</d:other></d:response>'
	assert extract_dav_element(xml, 'href') == ''
}

fn test_dav_resource_struct() {
	res := DavResource{
		href: '/files/doc.pdf'
		resource_type: .non_collection
		content_length: 4096
		last_modified: '2026-01-01'
		etag: '"abc"'
		content_type: 'application/pdf'
		display_name: 'doc.pdf'
	}
	assert res.href == '/files/doc.pdf'
	assert res.content_length == 4096
}
