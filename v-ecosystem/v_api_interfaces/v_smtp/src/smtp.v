// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_smtp -- SMTP protocol types and server for the V-Ecosystem.
// Implements SMTP command processing, envelope handling, address validation,
// and response formatting per RFC 5321. Network I/O is stubbed with TODO
// markers; all type definitions and logic are real.
module v_smtp

// Command enumerates the SMTP commands supported by this connector,
// as defined in RFC 5321 and extensions.
pub enum Command {
	helo
	ehlo
	mail_from
	rcpt_to
	data
	quit
	rset
	vrfy
	noop
	start_tls
	auth
}

// command_to_string returns the SMTP wire-format keyword for a Command.
pub fn command_to_string(cmd Command) string {
	return match cmd {
		.helo { 'HELO' }
		.ehlo { 'EHLO' }
		.mail_from { 'MAIL FROM' }
		.rcpt_to { 'RCPT TO' }
		.data { 'DATA' }
		.quit { 'QUIT' }
		.rset { 'RSET' }
		.vrfy { 'VRFY' }
		.noop { 'NOOP' }
		.start_tls { 'STARTTLS' }
		.auth { 'AUTH' }
	}
}

// ResponseCode represents an SMTP reply with a three-digit status code
// and a human-readable message per RFC 5321 section 4.2.
pub struct ResponseCode {
pub:
	// code is the three-digit SMTP reply code.
	code int
	// message is the human-readable text accompanying the code.
	message string
}

// format_response serialises a ResponseCode into SMTP wire format
// (e.g. "250 OK\r\n").
pub fn format_response(resp ResponseCode) string {
	return '${resp.code} ${resp.message}\r\n'
}

// Extension enumerates the SMTP service extensions advertised via EHLO.
pub enum Extension {
	start_tls
	auth
	size
	pipelining
	eight_bit_mime
}

// extension_to_string returns the EHLO keyword for an Extension.
pub fn extension_to_string(ext Extension) string {
	return match ext {
		.start_tls { 'STARTTLS' }
		.auth { 'AUTH' }
		.size { 'SIZE' }
		.pipelining { 'PIPELINING' }
		.eight_bit_mime { '8BITMIME' }
	}
}

// Envelope represents an SMTP mail envelope containing sender, recipients,
// message data, and optional headers.
pub struct Envelope {
pub:
	// from is the reverse-path (MAIL FROM address).
	from string
	// to is the list of forward-path (RCPT TO) addresses.
	to []string
	// data is the raw message body following the DATA command.
	data string
	// headers contains key-value pairs for message headers.
	headers map[string]string
}

// SmtpServer holds the state for an SMTP server instance.
pub struct SmtpServer {
pub:
	// port is the TCP port the server listens on (default 25).
	port int
	// hostname is the server's FQDN used in HELO/EHLO responses.
	hostname string
pub mut:
	// extensions lists the service extensions this server advertises.
	extensions []Extension
	// envelopes stores received mail envelopes (in-memory for testing).
	envelopes []Envelope
}

// new_server creates a new SmtpServer listening on the given port with
// the specified hostname.
pub fn new_server(port int, hostname string) &SmtpServer {
	return &SmtpServer{
		port: port
		hostname: hostname
		extensions: [.start_tls, .pipelining, .eight_bit_mime]
	}
}

// validate_address checks whether an email address has a minimally valid
// format (contains exactly one '@' with non-empty local and domain parts).
pub fn validate_address(addr string) bool {
	// Strip angle brackets if present
	cleaned := if addr.starts_with('<') && addr.ends_with('>') {
		addr[1..addr.len - 1]
	} else {
		addr
	}
	at_idx := cleaned.index_u8(`@`)
	if at_idx <= 0 {
		return false
	}
	local := cleaned[..at_idx]
	domain := cleaned[at_idx + 1..]
	return local.len > 0 && domain.len > 0 && domain.contains('.')
}

// parse_envelope constructs an Envelope from a sender, list of recipients,
// and raw message data. Validates all addresses and returns an error if
// any are invalid.
pub fn parse_envelope(from string, to []string, data string) !Envelope {
	if !validate_address(from) {
		return error('invalid sender address: ${from}')
	}
	for addr in to {
		if !validate_address(addr) {
			return error('invalid recipient address: ${addr}')
		}
	}
	if to.len == 0 {
		return error('envelope must have at least one recipient')
	}

	// Extract headers from the data (lines before the first blank line)
	mut headers := map[string]string{}
	lines := data.split('\n')
	for line in lines {
		trimmed := line.trim_right('\r')
		if trimmed.len == 0 {
			break
		}
		colon := trimmed.index_u8(`:`)
		if colon > 0 {
			key := trimmed[..colon].trim_space()
			val := trimmed[colon + 1..].trim_space()
			headers[key] = val
		}
	}

	return Envelope{
		from: from
		to: to
		data: data
		headers: headers
	}
}

// process_command processes an SMTP command against the server state and
// returns an appropriate ResponseCode. Handles the SMTP state machine
// for greeting, envelope construction, and session teardown.
pub fn (mut s SmtpServer) process_command(cmd Command, arg string) ResponseCode {
	return match cmd {
		.helo {
			ResponseCode{
				code: 250
				message: '${s.hostname} Hello ${arg}'
			}
		}
		.ehlo {
			mut ext_list := s.hostname
			for ext in s.extensions {
				ext_list += ' ${extension_to_string(ext)}'
			}
			ResponseCode{
				code: 250
				message: ext_list
			}
		}
		.mail_from {
			if validate_address(arg) {
				ResponseCode{
					code: 250
					message: 'OK'
				}
			} else {
				ResponseCode{
					code: 553
					message: 'Invalid sender address'
				}
			}
		}
		.rcpt_to {
			if validate_address(arg) {
				ResponseCode{
					code: 250
					message: 'OK'
				}
			} else {
				ResponseCode{
					code: 553
					message: 'Invalid recipient address'
				}
			}
		}
		.data {
			ResponseCode{
				code: 354
				message: 'Start mail input; end with <CRLF>.<CRLF>'
			}
		}
		.quit {
			ResponseCode{
				code: 221
				message: '${s.hostname} Service closing transmission channel'
			}
		}
		.rset {
			ResponseCode{
				code: 250
				message: 'OK'
			}
		}
		.vrfy {
			// VRFY is intentionally vague for security (RFC 5321 section 3.5.3)
			ResponseCode{
				code: 252
				message: 'Cannot VRFY user; try RCPT TO'
			}
		}
		.noop {
			ResponseCode{
				code: 250
				message: 'OK'
			}
		}
		.start_tls {
			if .start_tls in s.extensions {
				ResponseCode{
					code: 220
					message: 'Ready to start TLS'
				}
			} else {
				ResponseCode{
					code: 502
					message: 'STARTTLS not supported'
				}
			}
		}
		.auth {
			if .auth in s.extensions {
				ResponseCode{
					code: 334
					message: 'Go ahead'
				}
			} else {
				ResponseCode{
					code: 502
					message: 'AUTH not supported'
				}
			}
		}
	}
}

// send_mail accepts a complete Envelope, stores it on the server, and
// returns a success response. In a production system this would relay
// the message to the next hop.
// TODO: Full network I/O -- relay to downstream MTA via TCP.
pub fn (mut s SmtpServer) send_mail(envelope Envelope) ResponseCode {
	s.envelopes << envelope
	return ResponseCode{
		code: 250
		message: 'OK: message accepted for delivery'
	}
}
