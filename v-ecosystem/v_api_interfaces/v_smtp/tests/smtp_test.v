// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// smtp_test -- Protocol conformance tests for v_smtp.
// Covers command string mapping, address validation, envelope parsing,
// response formatting, and server command processing.
module v_smtp

// test_command_to_string verifies wire-format keywords for all SMTP commands.
fn test_command_to_string() {
	assert command_to_string(.helo) == 'HELO'
	assert command_to_string(.ehlo) == 'EHLO'
	assert command_to_string(.mail_from) == 'MAIL FROM'
	assert command_to_string(.rcpt_to) == 'RCPT TO'
	assert command_to_string(.data) == 'DATA'
	assert command_to_string(.quit) == 'QUIT'
	assert command_to_string(.rset) == 'RSET'
	assert command_to_string(.vrfy) == 'VRFY'
	assert command_to_string(.noop) == 'NOOP'
	assert command_to_string(.start_tls) == 'STARTTLS'
	assert command_to_string(.auth) == 'AUTH'
}

// test_extension_to_string verifies EHLO keywords for all extensions.
fn test_extension_to_string() {
	assert extension_to_string(.start_tls) == 'STARTTLS'
	assert extension_to_string(.auth) == 'AUTH'
	assert extension_to_string(.size) == 'SIZE'
	assert extension_to_string(.pipelining) == 'PIPELINING'
	assert extension_to_string(.eight_bit_mime) == '8BITMIME'
}

// test_validate_address_valid verifies that well-formed addresses pass.
fn test_validate_address_valid() {
	assert validate_address('user@example.com') == true
	assert validate_address('<user@example.com>') == true
	assert validate_address('alice.bob@mail.example.org') == true
}

// test_validate_address_invalid verifies that malformed addresses fail.
fn test_validate_address_invalid() {
	assert validate_address('') == false
	assert validate_address('noatsign') == false
	assert validate_address('@nodomain') == false
	assert validate_address('user@') == false
	assert validate_address('user@nodot') == false
}

// test_format_response verifies SMTP wire-format response serialisation.
fn test_format_response() {
	resp := ResponseCode{
		code: 250
		message: 'OK'
	}
	assert format_response(resp) == '250 OK\r\n'
}

// test_parse_envelope_valid verifies successful envelope construction.
fn test_parse_envelope_valid() {
	env := parse_envelope('sender@example.com', ['rcpt@example.com'], 'Subject: Test\r\n\r\nBody')!
	assert env.from == 'sender@example.com'
	assert env.to.len == 1
	assert env.to[0] == 'rcpt@example.com'
	assert env.headers['Subject'] == 'Test'
}

// test_parse_envelope_invalid_sender verifies rejection of bad sender.
fn test_parse_envelope_invalid_sender() {
	parse_envelope('badsender', ['rcpt@example.com'], 'data') or {
		assert err.msg().contains('invalid sender')
		return
	}
	assert false, 'expected error for invalid sender'
}

// test_parse_envelope_no_recipients verifies rejection of empty recipient list.
fn test_parse_envelope_no_recipients() {
	parse_envelope('sender@example.com', [], 'data') or {
		assert err.msg().contains('at least one recipient')
		return
	}
	assert false, 'expected error for no recipients'
}

// test_server_process_helo verifies HELO command processing.
fn test_server_process_helo() {
	mut server := new_server(25, 'mail.example.com')
	resp := server.process_command(.helo, 'client.example.com')
	assert resp.code == 250
	assert resp.message.contains('Hello')
}

// test_server_process_ehlo verifies EHLO command includes extensions.
fn test_server_process_ehlo() {
	mut server := new_server(25, 'mail.example.com')
	resp := server.process_command(.ehlo, 'client.example.com')
	assert resp.code == 250
	assert resp.message.contains('STARTTLS')
	assert resp.message.contains('PIPELINING')
}

// test_server_process_quit verifies QUIT response code.
fn test_server_process_quit() {
	mut server := new_server(25, 'mail.example.com')
	resp := server.process_command(.quit, '')
	assert resp.code == 221
}

// test_server_process_noop verifies NOOP returns 250 OK.
fn test_server_process_noop() {
	mut server := new_server(25, 'mail.example.com')
	resp := server.process_command(.noop, '')
	assert resp.code == 250
}

// test_server_process_vrfy verifies VRFY returns 252 (ambiguous).
fn test_server_process_vrfy() {
	mut server := new_server(25, 'mail.example.com')
	resp := server.process_command(.vrfy, 'user')
	assert resp.code == 252
}

// test_server_process_mail_from_valid verifies MAIL FROM with valid address.
fn test_server_process_mail_from_valid() {
	mut server := new_server(25, 'mail.example.com')
	resp := server.process_command(.mail_from, 'user@example.com')
	assert resp.code == 250
}

// test_server_process_mail_from_invalid verifies MAIL FROM with bad address.
fn test_server_process_mail_from_invalid() {
	mut server := new_server(25, 'mail.example.com')
	resp := server.process_command(.mail_from, 'badaddr')
	assert resp.code == 553
}

// test_server_send_mail verifies that send_mail stores the envelope.
fn test_server_send_mail() {
	mut server := new_server(25, 'mail.example.com')
	env := parse_envelope('sender@example.com', ['rcpt@example.com'], 'Hello')!
	resp := server.send_mail(env)
	assert resp.code == 250
	assert server.envelopes.len == 1
}
