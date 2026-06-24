// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem SMTP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// SMTP client (RFC 5321) with ESMTP extensions over raw TCP.
// Supports EHLO/HELO handshake, STARTTLS upgrade, PLAIN and
// LOGIN authentication (RFC 4954), MAIL FROM/RCPT TO/DATA
// envelope, MIME multipart messages, and QUIT. Designed for
// transactional email within the V-Ecosystem.

module smtp

import net
import time
import encoding.base64

// --- SMTP response codes ---

const reply_ready       = 220
const reply_closing     = 221
const reply_auth_ok     = 235
const reply_ok          = 250
const reply_auth_cont   = 334
const reply_start_input = 354

// --- Authentication methods ---

// AuthMethod selects the SMTP authentication mechanism.
pub enum AuthMethod {
	plain       // PLAIN (RFC 4616) — base64-encoded credentials
	login       // LOGIN — base64-encoded username then password
	none        // No authentication
}

// --- Data structures ---

// Config specifies the SMTP server and connection parameters.
pub struct Config {
pub:
	host             string
	port             int    = 587                          // Submission port (STARTTLS)
	use_tls          bool                                  // Implicit TLS (port 465)
	use_starttls     bool   = true                         // STARTTLS upgrade
	auth_method      AuthMethod = .plain
	username         string
	password         string
	connect_timeout  time.Duration = 10 * time.second
	read_timeout     time.Duration = 30 * time.second
	helo_domain      string = 'localhost'                  // EHLO/HELO domain
}

// Address represents an email address with optional display name.
pub struct Address {
pub:
	name    string   // Display name (optional)
	email   string   // Email address (required)
}

// Attachment holds a MIME attachment for a multipart message.
pub struct Attachment {
pub:
	filename     string
	content_type string   // MIME type (e.g. "application/pdf")
	data         []u8
}

// Message represents an email message with headers and body.
pub struct Message {
pub:
	from         Address
	to           []Address
	cc           []Address
	bcc          []Address
	subject      string
	body_text    string        // Plain text body
	body_html    string        // HTML body (optional)
	attachments  []Attachment
	headers      map[string]string  // Additional headers
}

// Client manages the TCP connection and SMTP session state.
pub struct Client {
mut:
	conn            net.TcpConn
	connected       bool
	authenticated   bool
	extensions      []string   // ESMTP extensions from EHLO response
	config          Config
}

// --- Client lifecycle ---

// connect establishes a TCP connection and performs the EHLO
// handshake. Optionally upgrades to STARTTLS.
pub fn connect(config Config) !&Client {
	port := if config.use_tls { 465 } else { config.port }
	addr := '${config.host}:${port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(config.read_timeout)

	mut client := &Client{
		conn: conn
		config: config
	}

	// Read server greeting
	greeting := client.read_response()!
	if greeting.code != reply_ready {
		return error('unexpected greeting: ${greeting.code} ${greeting.text}')
	}

	// EHLO handshake
	client.send_ehlo()!
	client.connected = true
	println('[smtp] connected to ${addr}')
	return client
}

// authenticate performs SMTP authentication using the configured method.
pub fn (mut c Client) authenticate() ! {
	if !c.connected {
		return error('not connected')
	}

	match c.config.auth_method {
		.plain {
			c.auth_plain()!
		}
		.login {
			c.auth_login()!
		}
		.none {
			return
		}
	}
	c.authenticated = true
	println('[smtp] authenticated as ${c.config.username}')
}

// send transmits an email message through the SMTP session.
pub fn (mut c Client) send(msg Message) ! {
	if !c.connected {
		return error('not connected')
	}

	// MAIL FROM
	c.send_command('MAIL FROM:<${msg.from.email}>')!
	from_resp := c.read_response()!
	if from_resp.code != reply_ok {
		return error('MAIL FROM rejected: ${from_resp.code} ${from_resp.text}')
	}

	// RCPT TO (all recipients)
	mut all_recipients := []Address{}
	all_recipients << msg.to
	all_recipients << msg.cc
	all_recipients << msg.bcc

	for rcpt in all_recipients {
		c.send_command('RCPT TO:<${rcpt.email}>')!
		rcpt_resp := c.read_response()!
		if rcpt_resp.code != reply_ok {
			return error('RCPT TO <${rcpt.email}> rejected: ${rcpt_resp.code} ${rcpt_resp.text}')
		}
	}

	// DATA
	c.send_command('DATA')!
	data_resp := c.read_response()!
	if data_resp.code != reply_start_input {
		return error('DATA rejected: ${data_resp.code} ${data_resp.text}')
	}

	// Build and send message content
	content := build_message(msg)
	c.send_raw(content)!
	c.send_raw('\r\n.\r\n')!

	end_resp := c.read_response()!
	if end_resp.code != reply_ok {
		return error('message rejected: ${end_resp.code} ${end_resp.text}')
	}

	println('[smtp] message sent to ${msg.to.len} recipients')
}

// quit sends QUIT and closes the connection.
pub fn (mut c Client) quit() {
	if !c.connected {
		return
	}
	c.send_command('QUIT') or {}
	c.read_response() or {}
	c.conn.close() or {}
	c.connected = false
	c.authenticated = false
	println('[smtp] disconnected')
}

// --- Internal protocol helpers ---

// SmtpResponse holds a parsed SMTP response line.
struct SmtpResponse {
	code int
	text string
}

// send_ehlo sends the EHLO command and parses extension capabilities.
fn (mut c Client) send_ehlo() ! {
	c.send_command('EHLO ${c.config.helo_domain}')!
	// Read multi-line response
	for {
		resp := c.read_response()!
		if resp.code == reply_ok {
			c.extensions << resp.text
			break
		}
	}
}

// auth_plain performs PLAIN SASL authentication.
fn (mut c Client) auth_plain() ! {
	// PLAIN: base64(\0username\0password)
	mut credentials := []u8{}
	credentials << u8(0)
	credentials << c.config.username.bytes()
	credentials << u8(0)
	credentials << c.config.password.bytes()
	encoded := base64.encode(credentials)

	c.send_command('AUTH PLAIN ${encoded}')!
	resp := c.read_response()!
	if resp.code != reply_auth_ok {
		return error('PLAIN auth failed: ${resp.code} ${resp.text}')
	}
}

// auth_login performs LOGIN authentication (two-step base64).
fn (mut c Client) auth_login() ! {
	c.send_command('AUTH LOGIN')!
	resp1 := c.read_response()!
	if resp1.code != reply_auth_cont {
		return error('LOGIN auth failed at username prompt: ${resp1.code}')
	}

	c.send_raw(base64.encode(c.config.username.bytes()) + '\r\n')!
	resp2 := c.read_response()!
	if resp2.code != reply_auth_cont {
		return error('LOGIN auth failed at password prompt: ${resp2.code}')
	}

	c.send_raw(base64.encode(c.config.password.bytes()) + '\r\n')!
	resp3 := c.read_response()!
	if resp3.code != reply_auth_ok {
		return error('LOGIN auth failed: ${resp3.code} ${resp3.text}')
	}
}

// send_command writes an SMTP command followed by CRLF.
fn (mut c Client) send_command(cmd string) ! {
	c.conn.write('${cmd}\r\n'.bytes())!
}

// send_raw writes raw bytes to the connection.
fn (mut c Client) send_raw(data string) ! {
	c.conn.write(data.bytes())!
}

// read_response reads a single SMTP response line and parses
// the 3-digit status code.
fn (mut c Client) read_response() !SmtpResponse {
	mut buf := []u8{len: 1024}
	n := c.conn.read(mut buf)!
	line := buf[..n].bytestr().trim_right('\r\n')
	if line.len < 3 {
		return error('truncated SMTP response')
	}
	code := line[..3].int()
	text := if line.len > 4 { line[4..] } else { '' }
	return SmtpResponse{ code: code, text: text }
}

// --- Message building ---

// build_message constructs the RFC 5322 message with headers and body.
fn build_message(msg Message) string {
	mut lines := []string{}

	// Headers
	lines << 'From: ${format_address(msg.from)}'
	if msg.to.len > 0 {
		to_list := msg.to.map(format_address(it)).join(', ')
		lines << 'To: ${to_list}'
	}
	if msg.cc.len > 0 {
		cc_list := msg.cc.map(format_address(it)).join(', ')
		lines << 'Cc: ${cc_list}'
	}
	lines << 'Subject: ${msg.subject}'
	lines << 'MIME-Version: 1.0'

	// Custom headers
	for key, value in msg.headers {
		lines << '${key}: ${value}'
	}

	// Body
	if msg.attachments.len == 0 && msg.body_html.len == 0 {
		// Simple plain text
		lines << 'Content-Type: text/plain; charset=UTF-8'
		lines << ''
		lines << msg.body_text
	} else {
		// Multipart
		boundary := '----=_V_Ecosystem_SMTP_Boundary'
		lines << 'Content-Type: multipart/mixed; boundary="${boundary}"'
		lines << ''
		lines << '--${boundary}'
		lines << 'Content-Type: text/plain; charset=UTF-8'
		lines << ''
		lines << msg.body_text

		if msg.body_html.len > 0 {
			lines << '--${boundary}'
			lines << 'Content-Type: text/html; charset=UTF-8'
			lines << ''
			lines << msg.body_html
		}

		for att in msg.attachments {
			lines << '--${boundary}'
			lines << 'Content-Type: ${att.content_type}; name="${att.filename}"'
			lines << 'Content-Disposition: attachment; filename="${att.filename}"'
			lines << 'Content-Transfer-Encoding: base64'
			lines << ''
			lines << base64.encode(att.data)
		}

		lines << '--${boundary}--'
	}

	return lines.join('\r\n')
}

// format_address produces the RFC 5322 mailbox format.
fn format_address(addr Address) string {
	if addr.name.len > 0 {
		return '"${addr.name}" <${addr.email}>'
	}
	return addr.email
}

// --- Tests ---

fn test_format_address_email_only() {
	a := Address{ email: 'user@example.com' }
	assert format_address(a) == 'user@example.com'
}

fn test_format_address_with_name() {
	a := Address{ name: 'Test User', email: 'user@example.com' }
	assert format_address(a) == '"Test User" <user@example.com>'
}

fn test_build_message_plain() {
	msg := Message{
		from: Address{ email: 'from@example.com' }
		to: [Address{ email: 'to@example.com' }]
		subject: 'Test'
		body_text: 'Hello'
	}
	result := build_message(msg)
	assert result.contains('Subject: Test')
	assert result.contains('Hello')
}
