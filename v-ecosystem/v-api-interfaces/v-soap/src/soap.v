// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem SOAP/XML Envelope Builder and Parser
// Author: Jonathan D.A. Jewell
//
// Builds SOAP 1.1/1.2 envelopes, parses response XML to extract body
// content, and calls WSDL-described endpoints over HTTP. Useful for
// legacy enterprise integrations (banking, ERP, government services)
// that still mandate SOAP.

module soap

import net.http

// --- SOAP envelope structures ---

// SoapVersion selects the namespace and content type.
pub enum SoapVersion {
	v1_1
	v1_2
}

// Envelope represents a complete SOAP message with optional header
// and a required body element.
pub struct Envelope {
pub mut:
	version    SoapVersion = .v1_1
	headers    []Header
	body       string // Raw XML body content
	action     string // SOAPAction HTTP header value
}

// Header is a single SOAP header block with an optional namespace.
pub struct Header {
pub:
	namespace string
	name      string
	value     string
}

// ParsedResponse holds the result of parsing a SOAP response.
pub struct ParsedResponse {
pub:
	status_code int
	body        string   // Extracted <Body> inner XML
	fault_code  string   // Non-empty if a SOAP Fault was returned
	fault_str   string
	raw         string   // Full response body
}

// --- Envelope builder ---

// namespace_uri returns the correct SOAP namespace for the version.
fn namespace_uri(v SoapVersion) string {
	return match v {
		.v1_1 { 'http://schemas.xmlsoap.org/soap/envelope/' }
		.v1_2 { 'http://www.w3.org/2003/05/soap-envelope' }
	}
}

// content_type returns the correct HTTP Content-Type for the version.
fn content_type(v SoapVersion) string {
	return match v {
		.v1_1 { 'text/xml; charset=utf-8' }
		.v1_2 { 'application/soap+xml; charset=utf-8' }
	}
}

// new_envelope creates a SOAP envelope with the given body XML.
pub fn new_envelope(body string) &Envelope {
	return &Envelope{
		body: body
	}
}

// add_header appends a SOAP header block to the envelope.
pub fn (mut e Envelope) add_header(name string, value string, namespace string) {
	e.headers << Header{
		namespace: namespace
		name: name
		value: value
	}
}

// set_action sets the SOAPAction header value (SOAP 1.1) or the
// action parameter on the Content-Type (SOAP 1.2).
pub fn (mut e Envelope) set_action(action string) {
	e.action = action
}

// build serialises the envelope to a complete XML string.
pub fn (e &Envelope) build() string {
	ns := namespace_uri(e.version)
	mut xml := '<?xml version="1.0" encoding="UTF-8"?>\n'
	xml += '<soap:Envelope xmlns:soap="${ns}">\n'

	if e.headers.len > 0 {
		xml += '  <soap:Header>\n'
		for h in e.headers {
			if h.namespace.len > 0 {
				xml += '    <${h.name} xmlns="${h.namespace}">${esc_xml(h.value)}</${h.name}>\n'
			} else {
				xml += '    <${h.name}>${esc_xml(h.value)}</${h.name}>\n'
			}
		}
		xml += '  </soap:Header>\n'
	}

	xml += '  <soap:Body>\n'
	xml += '    ${e.body}\n'
	xml += '  </soap:Body>\n'
	xml += '</soap:Envelope>'
	return xml
}

// --- HTTP caller ---

// call sends the SOAP envelope to the given endpoint URL and parses
// the response.
pub fn (e &Envelope) call(endpoint string) !ParsedResponse {
	payload := e.build()
	ct := content_type(e.version)

	mut config := http.FetchConfig{
		url: endpoint
		method: .post
		header: http.new_header_from_map({
			'Content-Type': ct
		})
		data: payload
	}

	// SOAPAction header for 1.1
	if e.version == .v1_1 && e.action.len > 0 {
		config.header.add_custom('SOAPAction', '"${e.action}"') or {}
	}

	resp := http.fetch(config)!
	return parse_response(resp.status_code, resp.body)
}

// --- Response parser ---

// parse_response extracts the SOAP Body content and detects Faults.
pub fn parse_response(status_code int, raw string) ParsedResponse {
	body := extract_tag(raw, 'Body')
	fault_code := extract_tag(raw, 'faultcode')
	fault_str := extract_tag(raw, 'faultstring')

	return ParsedResponse{
		status_code: status_code
		body: body
		fault_code: fault_code
		fault_str: fault_str
		raw: raw
	}
}

// --- Simple XML tag extraction ---

// extract_tag finds the content between <tag> and </tag>, handling
// namespace prefixes (e.g., soap:Body). Returns empty string if not
// found.
fn extract_tag(xml string, tag string) string {
	// Try with common namespace prefixes first, then bare tag
	for prefix in ['soap:', 'SOAP-ENV:', 'soapenv:', 'S:', ''] {
		open := '<${prefix}${tag}'
		close := '</${prefix}${tag}>'
		start := xml.index(open) or { continue }
		// Find the end of the opening tag (handle attributes)
		tag_end := xml[start..].index('>') or { continue }
		content_start := start + tag_end + 1
		end := xml.index(close) or { continue }
		if end > content_start {
			return xml[content_start..end].trim_space()
		}
	}
	return ''
}

// esc_xml escapes the five XML special characters.
fn esc_xml(s string) string {
	return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&apos;')
}

// --- Tests ---

fn test_build_envelope_1_1() {
	mut env := new_envelope('<GetPrice xmlns="urn:example"><item>Widget</item></GetPrice>')
	env.set_action('urn:example/GetPrice')
	env.add_header('AuthToken', 'abc123', 'urn:auth')
	xml := env.build()

	assert xml.contains('schemas.xmlsoap.org')
	assert xml.contains('<GetPrice')
	assert xml.contains('AuthToken')
	assert xml.contains('abc123')
}

fn test_build_envelope_1_2() {
	mut env := new_envelope('<Ping/>')
	env.version = .v1_2
	xml := env.build()

	assert xml.contains('www.w3.org/2003/05/soap-envelope')
	assert xml.contains('<Ping/>')
}

fn test_parse_response_with_fault() {
	raw := '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><soap:Fault><faultcode>soap:Server</faultcode><faultstring>Internal error</faultstring></soap:Fault></soap:Body></soap:Envelope>'
	result := parse_response(500, raw)

	assert result.fault_code == 'soap:Server'
	assert result.fault_str == 'Internal error'
}

fn test_extract_body() {
	raw := '<soap:Envelope><soap:Body><Result>42</Result></soap:Body></soap:Envelope>'
	result := parse_response(200, raw)

	assert result.body.contains('42')
}
