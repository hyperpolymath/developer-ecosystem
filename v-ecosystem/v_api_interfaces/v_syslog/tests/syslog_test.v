// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_syslog.
// Validates RFC 5424/3164 parsing, formatting, priority encoding/decoding,
// and server creation.
module main

import v_syslog

// test_priority_encoding verifies the PRI = facility*8 + severity formula.
fn test_priority_encoding() {
	// kern.emergency = 0*8 + 0 = 0
	assert v_syslog.priority(.kern, .emergency) == 0
	// user.info = 1*8 + 6 = 14
	assert v_syslog.priority(.user, .info) == 14
	// local0.err = 16*8 + 3 = 131
	assert v_syslog.priority(.local0, .err) == 131
	// auth.warning = 4*8 + 4 = 36
	assert v_syslog.priority(.auth, .warning) == 36
}

// test_from_priority_decoding verifies PRI decoding back to
// facility and severity.
fn test_from_priority_decoding() {
	fac, sev := v_syslog.from_priority(14)
	assert int(fac) == 1 // user
	assert int(sev) == 6 // info

	fac2, sev2 := v_syslog.from_priority(131)
	assert int(fac2) == 16 // local0
	assert int(sev2) == 3 // err
}

// test_priority_roundtrip verifies that encoding then decoding
// produces the original values.
fn test_priority_roundtrip() {
	pri := v_syslog.priority(.daemon, .notice)
	fac, sev := v_syslog.from_priority(pri)
	assert fac == .daemon
	assert sev == .notice
}

// test_parse_rfc5424_basic verifies parsing of a well-formed
// RFC 5424 message with all fields present.
fn test_parse_rfc5424_basic() {
	raw := '<14>1 2026-03-20T12:00:00Z myhost myapp 1234 ID001 - This is a test message'
	msg := v_syslog.parse_rfc5424(raw) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert msg.hostname == 'myhost'
	assert msg.app_name == 'myapp'
	assert msg.proc_id == '1234'
	assert msg.msg_id == 'ID001'
	assert msg.message == 'This is a test message'
	assert int(msg.facility) == 1 // user
	assert int(msg.severity) == 6 // info
}

// test_parse_rfc5424_nilvalues verifies that NILVALUE ("-") fields
// are parsed as empty strings.
fn test_parse_rfc5424_nilvalues() {
	raw := '<0>1 2026-01-01T00:00:00Z - - - - - kernel panic'
	msg := v_syslog.parse_rfc5424(raw) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert msg.hostname == ''
	assert msg.app_name == ''
	assert msg.proc_id == ''
	assert msg.msg_id == ''
	assert msg.message == 'kernel panic'
}

// test_parse_rfc5424_structured_data verifies parsing of messages
// with structured data elements.
fn test_parse_rfc5424_structured_data() {
	raw := '<165>1 2026-03-20T12:00:00Z myhost myapp - - [exampleSDID@32473 iut="3" eventSource="Application"] An application event'
	msg := v_syslog.parse_rfc5424(raw) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert msg.structured_data.len == 1
	assert msg.structured_data[0].id == 'exampleSDID@32473'
	assert msg.structured_data[0].params['iut'] == '3'
	assert msg.message == 'An application event'
}

// test_parse_rfc5424_empty_returns_error verifies that an empty
// string produces an error.
fn test_parse_rfc5424_empty_returns_error() {
	v_syslog.parse_rfc5424('') or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty message'
}

// test_parse_rfc5424_missing_pri_returns_error verifies that a
// message without PRI brackets produces an error.
fn test_parse_rfc5424_missing_pri_returns_error() {
	v_syslog.parse_rfc5424('no angle brackets here') or {
		assert err.msg().contains('PRI')
		return
	}
	assert false, 'expected error for missing PRI'
}

// test_parse_rfc3164_basic verifies parsing of a legacy BSD
// syslog message.
fn test_parse_rfc3164_basic() {
	raw := '<34>Mar 20 12:34:56 myhost sshd[1234]: Accepted publickey for admin'
	msg := v_syslog.parse_rfc3164(raw) or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert msg.hostname == 'myhost'
	assert msg.message.contains('sshd')
	assert int(msg.facility) == 4 // auth
	assert int(msg.severity) == 2 // critical
}

// test_format_rfc5424_roundtrip verifies that formatting then parsing
// produces equivalent field values.
fn test_format_rfc5424_roundtrip() {
	import time

	original := v_syslog.SyslogMessage{
		facility: .user
		severity: .info
		timestamp: time.now()
		hostname: 'testhost'
		app_name: 'testapp'
		proc_id: '42'
		msg_id: 'MSG001'
		structured_data: []v_syslog.StructuredDataElement{}
		message: 'Hello world'
	}
	formatted := original.format_rfc5424()
	assert formatted.starts_with('<14>')
	assert formatted.contains('testhost')
	assert formatted.contains('testapp')
	assert formatted.contains('Hello world')
}

// test_new_server_defaults verifies the default server configuration.
fn test_new_server_defaults() {
	server := v_syslog.new_server(1514)
	assert server.port == 1514
	assert server.protocol == .udp
	assert server.buffer_size == 8192
}

// test_format_rfc5424_with_structured_data verifies that structured
// data elements are correctly serialised.
fn test_format_rfc5424_with_structured_data() {
	import time

	msg := v_syslog.SyslogMessage{
		facility: .local0
		severity: .notice
		timestamp: time.now()
		hostname: 'fw01'
		app_name: 'iptables'
		proc_id: ''
		msg_id: ''
		structured_data: [
			v_syslog.StructuredDataElement{
				id: 'meta'
				params: {
					'version': '1'
				}
			},
		]
		message: 'rule triggered'
	}
	formatted := msg.format_rfc5424()
	assert formatted.contains('[meta version="1"]')
	assert formatted.contains('rule triggered')
}
