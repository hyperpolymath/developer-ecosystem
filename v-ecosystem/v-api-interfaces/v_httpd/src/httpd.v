// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem HTTP server management with virtual hosts, TLS, and reverse proxy Connector
// Author: Jonathan D.A. Jewell
//
// HTTP server management with virtual hosts, TLS, and reverse proxy.
// Enforces TLS 1.3 by default and validates route conflict detection.
// Provides typed client bindings for the proven-httpd protocol.

module httpd

// --- HTTP status code map ---

// http_status returns the standard reason phrase for a numeric status code.
pub fn http_status(code int) string {
	return match code {
		100 { 'Continue' }
		200 { 'OK' }
		201 { 'Created' }
		204 { 'No Content' }
		301 { 'Moved Permanently' }
		302 { 'Found' }
		304 { 'Not Modified' }
		400 { 'Bad Request' }
		401 { 'Unauthorized' }
		403 { 'Forbidden' }
		404 { 'Not Found' }
		405 { 'Method Not Allowed' }
		409 { 'Conflict' }
		410 { 'Gone' }
		429 { 'Too Many Requests' }
		500 { 'Internal Server Error' }
		502 { 'Bad Gateway' }
		503 { 'Service Unavailable' }
		else { 'Unknown' }
	}
}

// --- MIME type map ---

// mime_type returns the MIME type for a common file extension.
pub fn mime_type(ext string) string {
	return match ext {
		'html', 'htm' { 'text/html; charset=utf-8' }
		'css'         { 'text/css' }
		'js'          { 'application/javascript' }
		'json'        { 'application/json' }
		'png'         { 'image/png' }
		'jpg', 'jpeg' { 'image/jpeg' }
		'svg'         { 'image/svg+xml' }
		'pdf'         { 'application/pdf' }
		'txt'         { 'text/plain; charset=utf-8' }
		'wasm'        { 'application/wasm' }
		else          { 'application/octet-stream' }
	}
}

// --- Default constants ---

// default_https_port is the standard HTTPS port.
pub const default_https_port = 443

// default_http_port is the standard HTTP port.
pub const default_http_port = 80

// default_worker_count is the default number of server worker threads.
pub const default_worker_count = 4

// access_log_combined is the Apache Combined Log Format pattern name.
pub const access_log_combined = 'combined'

// access_log_common is the Apache Common Log Format pattern name.
pub const access_log_common = 'common'

// --- TLS version ---

// TlsVersion selects the minimum TLS protocol version.
pub enum TlsVersion {
	tls12  // TLS 1.2 (RFC 5246) — legacy, avoid
	tls13  // TLS 1.3 (RFC 8446) — required default
}

// --- HTTP method ---

// HttpMethod identifies allowed HTTP methods.
pub enum HttpMethod {
	get
	post
	put
	delete_method
	patch
	head
	options
}

// method_str returns the uppercase string representation of an HttpMethod.
pub fn (m HttpMethod) str() string {
	return match m {
		.get           { 'GET' }
		.post          { 'POST' }
		.put           { 'PUT' }
		.delete_method { 'DELETE' }
		.patch         { 'PATCH' }
		.head          { 'HEAD' }
		.options       { 'OPTIONS' }
	}
}

// --- Request / Response types ---

// HttpRequest represents an incoming HTTP request.
pub struct HttpRequest {
pub:
	method  HttpMethod
	path    string       // Request path without query string
	query   string       // Raw query string (after '?')
	headers map[string]string
	body    string
}

// HttpResponse holds an outgoing HTTP response.
pub struct HttpResponse {
pub mut:
	status   int = 200
	headers  map[string]string
	body     string
}

// --- Route registration ---

// Route maps a method + path pattern to a symbolic handler name.
pub struct Route {
pub:
	method       HttpMethod
	path_pattern string   // Exact path or prefix ending with '*'
	handler_name string   // Symbolic handler identifier
}

// --- Data structures ---

// VirtualHost defines an HTTP virtual host with TLS enforcement.
pub struct VirtualHost {
pub:
	hostname      string         // Server Name (SNI)
	document_root string         // Filesystem path for static files
	tls_cert      string         // Path to PEM certificate
	tls_key       string         // Path to PEM private key
	min_tls       TlsVersion = .tls13
	hsts_max_age  int = 31536000 // HTTP Strict Transport Security max-age (seconds)
	routes        []Route        // Registered routes for this vhost
}

// HttpdConfig holds HTTP server parameters.
pub struct HttpdConfig {
pub:
	listen_addr    string = '0.0.0.0'
	listen_port    int = default_https_port
	worker_count   int = default_worker_count
	access_log_fmt string = access_log_combined
}

// AccessLogEntry represents a single access log record.
pub struct AccessLogEntry {
pub:
	client_ip    string
	method       HttpMethod
	path         string
	status       int
	bytes_sent   int
	user_agent   string
	timestamp_ms i64
}

// HttpdManager manages HTTP server virtual hosts and routes.
pub struct HttpdManager {
mut:
	config  HttpdConfig
	vhosts  []VirtualHost
	log     []AccessLogEntry
}

// --- Manager lifecycle ---

// new_httpd_manager creates a new HTTP server manager.
pub fn new_httpd_manager(config HttpdConfig) &HttpdManager {
	return &HttpdManager{
		config: config
		vhosts: []VirtualHost{}
		log:    []AccessLogEntry{}
	}
}

// add_vhost registers a virtual host, enforcing TLS 1.3 minimum.
pub fn (mut m HttpdManager) add_vhost(vhost VirtualHost) ! {
	if vhost.hostname.len == 0 {
		return error('hostname must not be empty')
	}
	if vhost.min_tls == .tls12 {
		return error('TLS 1.2 is disallowed; set min_tls to .tls13')
	}
	for v in m.vhosts {
		if v.hostname == vhost.hostname {
			return error('duplicate vhost: ${vhost.hostname}')
		}
	}
	m.vhosts << vhost
	println('[httpd] added vhost: ${vhost.hostname} (TLS ${vhost.min_tls})')
}

// remove_vhost removes a virtual host by hostname.
pub fn (mut m HttpdManager) remove_vhost(hostname string) ! {
	before := m.vhosts.len
	m.vhosts = m.vhosts.filter(it.hostname != hostname)
	if m.vhosts.len == before {
		return error('vhost not found: ${hostname}')
	}
	println('[httpd] removed vhost: ${hostname}')
}

// add_route registers a route on a named virtual host.
// Returns an error if a route with the same method + path_pattern already exists.
pub fn (mut m HttpdManager) add_route(hostname string, route Route) ! {
	if route.path_pattern.len == 0 {
		return error('route path pattern must not be empty')
	}
	if route.handler_name.len == 0 {
		return error('route handler name must not be empty')
	}
	for i in 0 .. m.vhosts.len {
		if m.vhosts[i].hostname == hostname {
			for r in m.vhosts[i].routes {
				if r.method == route.method && r.path_pattern == route.path_pattern {
					return error('route conflict: ${route.method.str()} ${route.path_pattern} already registered on ${hostname}')
				}
			}
			m.vhosts[i] = VirtualHost{
				hostname:      m.vhosts[i].hostname
				document_root: m.vhosts[i].document_root
				tls_cert:      m.vhosts[i].tls_cert
				tls_key:       m.vhosts[i].tls_key
				min_tls:       m.vhosts[i].min_tls
				hsts_max_age:  m.vhosts[i].hsts_max_age
				routes:        append_route(m.vhosts[i].routes, route)
			}
			println('[httpd] registered ${route.method.str()} ${route.path_pattern} -> ${route.handler_name} on ${hostname}')
			return
		}
	}
	return error('vhost not found: ${hostname}')
}

// append_route is a helper that returns routes with the new route appended.
fn append_route(routes []Route, r Route) []Route {
	mut updated := routes.clone()
	updated << r
	return updated
}

// reload signals the server to reload configuration.
// Returns the number of active virtual hosts.
pub fn (m &HttpdManager) reload() !int {
	println('[httpd] reloading ${m.vhosts.len} virtual hosts')
	return m.vhosts.len
}

// record_access appends an entry to the in-memory access log.
pub fn (mut m HttpdManager) record_access(entry AccessLogEntry) {
	m.log << entry
}

// format_access_log_entry formats an access log entry in Combined Log Format.
pub fn format_access_log_entry(e AccessLogEntry) string {
	return '${e.client_ip} - - [${e.timestamp_ms}] "${e.method.str()} ${e.path} HTTP/1.1" ${e.status} ${e.bytes_sent}'
}

// --- Tests ---

fn test_empty_hostname_rejected() {
	mut mgr := new_httpd_manager(HttpdConfig{})
	mgr.add_vhost(VirtualHost{ hostname: '', document_root: '/var/www', tls_cert: '', tls_key: '' }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_tls12_vhost_rejected() {
	mut mgr := new_httpd_manager(HttpdConfig{})
	mgr.add_vhost(VirtualHost{ hostname: 'example.com', min_tls: .tls12 }) or {
		assert err.str().contains('TLS 1.2 is disallowed')
		return
	}
	assert false
}

fn test_duplicate_vhost_rejected() {
	mut mgr := new_httpd_manager(HttpdConfig{})
	mgr.add_vhost(VirtualHost{ hostname: 'example.com', min_tls: .tls13 }) or { panic(err) }
	mgr.add_vhost(VirtualHost{ hostname: 'example.com', min_tls: .tls13 }) or {
		assert err.str().contains('duplicate vhost')
		return
	}
	assert false
}

fn test_route_conflict_detected() {
	mut mgr := new_httpd_manager(HttpdConfig{})
	mgr.add_vhost(VirtualHost{ hostname: 'api.example.com', min_tls: .tls13 }) or { panic(err) }
	mgr.add_route('api.example.com', Route{ method: .get, path_pattern: '/users', handler_name: 'list_users' }) or { panic(err) }
	mgr.add_route('api.example.com', Route{ method: .get, path_pattern: '/users', handler_name: 'dup_handler' }) or {
		assert err.str().contains('route conflict')
		return
	}
	assert false
}

fn test_mime_type_lookup() {
	assert mime_type('html') == 'text/html; charset=utf-8'
	assert mime_type('wasm') == 'application/wasm'
	assert mime_type('xyz') == 'application/octet-stream'
}
