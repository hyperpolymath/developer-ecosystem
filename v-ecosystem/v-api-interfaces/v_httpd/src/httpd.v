// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem HTTP server management with virtual hosts, TLS, and reverse proxy Connector
// Author: Jonathan D.A. Jewell
//
// HTTP server management with virtual hosts, TLS, and reverse proxy.
// Provides typed client bindings for the proven-httpd protocol.

module httpd

import os
import time
import net

// --- TLS version ---

// TlsVersion selects the minimum TLS protocol version.
pub enum TlsVersion {
	tls12
	tls13
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

// --- Data structures ---

// VirtualHost defines an HTTP virtual host.
pub struct VirtualHost {
pub:
	hostname    string
	document_root string
	tls_cert    string
	tls_key     string
	min_tls     TlsVersion = .tls13
}

// HttpdConfig holds HTTP server parameters.
pub struct HttpdConfig {
pub:
	listen_addr  string = "0.0.0.0"
	listen_port  int = 443
	worker_count int = 4
}

// HttpdManager manages HTTP server virtual hosts.
pub struct HttpdManager {
mut:
	config  HttpdConfig
	vhosts  []VirtualHost
}

// --- Manager lifecycle ---

// new_httpd_manager creates a new HTTP server manager.
pub fn new_httpd_manager(config HttpdConfig) &HttpdManager {
	return &HttpdManager{
		config: config
		vhosts: []VirtualHost{}
	}
}

// add_vhost registers a virtual host.
pub fn (mut m HttpdManager) add_vhost(vhost VirtualHost) ! {
	if vhost.hostname.len == 0 {
		return error("hostname must not be empty")
	}
	m.vhosts << vhost
	println("[httpd] added vhost: ${vhost.hostname} (TLS ${vhost.min_tls})")
}

// reload signals the server to reload configuration.
pub fn (m &HttpdManager) reload() !int {
	println("[httpd] reloading ${m.vhosts.len} virtual hosts")
	return m.vhosts.len
}

// --- Tests ---

fn test_empty_hostname_rejected() {
	mut mgr := new_httpd_manager(HttpdConfig{})
	mgr.add_vhost(VirtualHost{ hostname: "", document_root: "/var/www", tls_cert: "", tls_key: "" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
