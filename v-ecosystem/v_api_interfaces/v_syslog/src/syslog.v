// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_syslog — Syslog server (RFC 5424) for log collection.
// Maps to proven-servers/protocols/proven-syslog.
//
// Implements RFC 5424 and RFC 3164 message parsing and formatting,
// a configurable syslog server with pluggable handlers, and
// priority/facility/severity encoding. Network I/O is stubbed.
module v_syslog

import time

// Facility represents the syslog facility codes as defined in RFC 5424
// Section 6.2.1. Values correspond to the numerical codes 0-23.
pub enum Facility {
	kern       = 0
	user       = 1
	mail       = 2
	daemon     = 3
	auth       = 4
	syslog     = 5
	lpr        = 6
	news       = 7
	uucp       = 8
	cron       = 9
	authpriv   = 10
	ftp        = 11
	local0     = 16
	local1     = 17
	local2     = 18
	local3     = 19
	local4     = 20
	local5     = 21
	local6     = 22
	local7     = 23
}

// Severity represents the syslog severity levels as defined in
// RFC 5424 Section 6.2.1. Lower values are more severe.
pub enum Severity {
	emergency = 0
	alert     = 1
	critical  = 2
	err       = 3
	warning   = 4
	notice    = 5
	info      = 6
	debug     = 7
}

// TransportProtocol specifies whether the syslog server listens on
// UDP, TCP, or TLS-wrapped TCP.
pub enum TransportProtocol {
	udp
	tcp
	tls
}

// StructuredDataElement represents a single SD-ELEMENT from RFC 5424.
// Each element has an SD-ID and zero or more key-value parameters.
pub struct StructuredDataElement {
pub:
	// id is the SD-ID (e.g. "timeQuality", "origin", "meta").
	id string
	// params maps SD-PARAM-NAME to SD-PARAM-VALUE.
	params map[string]string
}

// SyslogMessage represents a parsed syslog message conforming to
// RFC 5424. All fields are populated by the parser; optional fields
// use empty strings when absent.
pub struct SyslogMessage {
pub:
	// facility is the message's facility code.
	facility Facility
	// severity is the message's severity level.
	severity Severity
	// timestamp is the message timestamp (RFC 5424 TIMESTAMP).
	timestamp time.Time
	// hostname identifies the machine that sent the message.
	hostname string
	// app_name is the application or process name.
	app_name string
	// proc_id is the process ID or other identifier (NILVALUE = "-").
	proc_id string
	// msg_id is a message type identifier (NILVALUE = "-").
	msg_id string
	// structured_data holds zero or more SD-ELEMENTs.
	structured_data []StructuredDataElement
	// message is the free-form message text (MSG part).
	message string
}

// SyslogServer is a configurable syslog receiver that accepts messages
// via UDP, TCP, or TLS and dispatches them to a handler function.
pub struct SyslogServer {
pub:
	// port is the port the server listens on (default 514).
	port int = 514
	// protocol selects the transport layer (UDP, TCP, or TLS).
	protocol TransportProtocol = .udp
	// buffer_size is the maximum message size in bytes (default 8192).
	buffer_size int = 8192
pub mut:
	// handler is the callback invoked for each received message.
	// Set via set_handler().
	handler fn (SyslogMessage) = unsafe { nil }
}

// new_server creates a new SyslogServer listening on the given port
// using UDP transport. Call set_handler() before serve().
pub fn new_server(port int) &SyslogServer {
	return &SyslogServer{
		port: port
	}
}

// serve starts the syslog server, binding to the configured port and
// protocol. Incoming messages are parsed and dispatched to the handler.
// This function blocks until the server is shut down.
pub fn (mut s SyslogServer) serve() ! {
	if s.port < 1 || s.port > 65535 {
		return error('invalid port: ${s.port}')
	}
	// TODO: Bind network socket (UDP/TCP/TLS) on s.port and receive
	// syslog messages. Parse each with parse_rfc5424() and dispatch
	// to s.handler.
	println('[v_syslog] server listening on port ${s.port} (${s.protocol})')
}

// set_handler registers the callback function that will be invoked
// for each received syslog message. Must be called before serve().
pub fn (mut s SyslogServer) set_handler(handler fn (SyslogMessage)) {
	s.handler = handler
}

// parse_rfc5424 parses a raw syslog message string according to
// RFC 5424 format: <PRI>VERSION TIMESTAMP HOSTNAME APP-NAME PROCID
// MSGID STRUCTURED-DATA MSG.
pub fn parse_rfc5424(raw string) !SyslogMessage {
	if raw.len == 0 {
		return error('empty syslog message')
	}
	// Extract PRI value from angle brackets.
	if raw[0] != `<` {
		return error('missing PRI: expected "<" at start')
	}
	pri_end := raw.index('>') or { return error('missing PRI: no closing ">"') }
	pri_str := raw[1..pri_end]
	pri_val := pri_str.int()
	facility, severity := from_priority(pri_val)

	// After PRI: "VERSION SP TIMESTAMP SP HOSTNAME SP APP-NAME SP PROCID SP MSGID SP SD SP MSG"
	remainder := raw[pri_end + 1..].trim_left(' ')

	// Split into fields. RFC 5424 has at least 7 space-separated header fields.
	parts := remainder.split(' ')
	if parts.len < 7 {
		return error('malformed RFC 5424 message: insufficient fields (got ${parts.len})')
	}

	// parts[0] = VERSION (should be "1")
	// parts[1] = TIMESTAMP
	// parts[2] = HOSTNAME
	// parts[3] = APP-NAME
	// parts[4] = PROCID
	// parts[5] = MSGID
	// parts[6..] = STRUCTURED-DATA + MSG

	hostname := if parts[2] == '-' { '' } else { parts[2] }
	app_name := if parts[3] == '-' { '' } else { parts[3] }
	proc_id := if parts[4] == '-' { '' } else { parts[4] }
	msg_id := if parts[5] == '-' { '' } else { parts[5] }

	// Parse structured data and message from the remainder.
	sd_and_msg := parts[6..].join(' ')
	mut sd_elements := []StructuredDataElement{}
	mut msg := ''

	if sd_and_msg.starts_with('[') {
		// Parse structured data elements.
		mut pos := 0
		for pos < sd_and_msg.len && sd_and_msg[pos] == `[` {
			end_bracket := sd_and_msg.index_after(']', pos)
			if end_bracket == -1 {
				break
			}
			sd_content := sd_and_msg[pos + 1..end_bracket]
			sd_parts := sd_content.split(' ')
			if sd_parts.len > 0 {
				mut params := map[string]string{}
				for sp in sd_parts[1..] {
					eq_idx := sp.index('=') or { continue }
					param_name := sp[..eq_idx]
					mut param_val := sp[eq_idx + 1..]
					// Strip surrounding quotes.
					if param_val.len >= 2 && param_val[0] == `"` {
						param_val = param_val[1..param_val.len - 1]
					}
					params[param_name] = param_val
				}
				sd_elements << StructuredDataElement{
					id: sd_parts[0]
					params: params
				}
			}
			pos = end_bracket + 1
		}
		if pos < sd_and_msg.len {
			msg = sd_and_msg[pos..].trim_left(' ')
		}
	} else if sd_and_msg != '-' {
		msg = sd_and_msg
	}

	// Parse timestamp. RFC 5424 uses ISO 8601 / RFC 3339 format.
	ts := time.parse_rfc3339(parts[1]) or { time.now() }

	return SyslogMessage{
		facility: facility
		severity: severity
		timestamp: ts
		hostname: hostname
		app_name: app_name
		proc_id: proc_id
		msg_id: msg_id
		structured_data: sd_elements
		message: msg
	}
}

// parse_rfc3164 parses a raw syslog message in legacy BSD format
// (RFC 3164): <PRI>TIMESTAMP HOSTNAME MSG.
pub fn parse_rfc3164(raw string) !SyslogMessage {
	if raw.len == 0 {
		return error('empty syslog message')
	}
	if raw[0] != `<` {
		return error('missing PRI: expected "<" at start')
	}
	pri_end := raw.index('>') or { return error('missing PRI: no closing ">"') }
	pri_str := raw[1..pri_end]
	pri_val := pri_str.int()
	facility, severity := from_priority(pri_val)

	remainder := raw[pri_end + 1..]
	// RFC 3164 timestamp is "Mmm dd HH:MM:SS" (15 chars).
	if remainder.len < 16 {
		return error('malformed RFC 3164 message: too short')
	}

	// Split the rest by spaces to extract hostname and message.
	parts := remainder.split(' ').filter(it.len > 0)
	// parts[0..3] = timestamp fields (e.g. "Mar", "20", "12:34:56")
	// parts[3] = hostname
	// parts[4..] = message
	hostname := if parts.len > 3 { parts[3] } else { '' }
	msg := if parts.len > 4 { parts[4..].join(' ') } else { '' }

	return SyslogMessage{
		facility: facility
		severity: severity
		timestamp: time.now()
		hostname: hostname
		app_name: ''
		proc_id: ''
		msg_id: ''
		structured_data: []StructuredDataElement{}
		message: msg
	}
}

// format_rfc5424 serialises a SyslogMessage into RFC 5424 wire format.
pub fn (m SyslogMessage) format_rfc5424() string {
	pri := priority(m.facility, m.severity)
	ts := m.timestamp.format_rfc3339()
	hostname := if m.hostname.len == 0 { '-' } else { m.hostname }
	app_name := if m.app_name.len == 0 { '-' } else { m.app_name }
	proc_id := if m.proc_id.len == 0 { '-' } else { m.proc_id }
	msg_id := if m.msg_id.len == 0 { '-' } else { m.msg_id }

	mut sd := '-'
	if m.structured_data.len > 0 {
		mut sd_parts := []string{}
		for elem in m.structured_data {
			mut param_strs := []string{}
			for key, val in elem.params {
				param_strs << '${key}="${val}"'
			}
			if param_strs.len > 0 {
				sd_parts << '[${elem.id} ${param_strs.join(' ')}]'
			} else {
				sd_parts << '[${elem.id}]'
			}
		}
		sd = sd_parts.join('')
	}

	return '<${pri}>1 ${ts} ${hostname} ${app_name} ${proc_id} ${msg_id} ${sd} ${m.message}'
}

// priority computes the PRI value from a facility and severity,
// as defined in RFC 5424: PRI = facility * 8 + severity.
pub fn priority(facility Facility, severity Severity) int {
	return int(facility) * 8 + int(severity)
}

// from_priority decodes a PRI value into its facility and severity
// components.
pub fn from_priority(pri int) (Facility, Severity) {
	fac := pri / 8
	sev := pri % 8
	return unsafe { Facility(fac) }, unsafe { Severity(sev) }
}
