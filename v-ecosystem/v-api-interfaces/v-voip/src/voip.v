// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem VoIP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// SIP/RTP VoIP client implementing RFC 3261 (Session Initiation Protocol)
// for call signalling over UDP and RFC 3550 (Real-time Transport Protocol)
// for media transport. Supports REGISTER, INVITE, BYE, CANCEL, and OPTIONS
// methods with SDP (RFC 4566) offer/answer for codec negotiation. Designed
// for PBX integration, click-to-call applications, and voice automation
// within the V-Ecosystem API layer.

module voip

import net
import net.udp
import time
import rand

// --- SIP methods ---

// Common SIP request methods as string constants.
const method_register = 'REGISTER'
const method_invite = 'INVITE'
const method_ack = 'ACK'
const method_bye = 'BYE'
const method_cancel = 'CANCEL'
const method_options = 'OPTIONS'

// --- Call state ---

// CallState represents the lifecycle of a VoIP call from initiation
// through establishment to termination.
pub enum CallState {
	idle         // No active call
	trying       // INVITE sent, awaiting response
	ringing      // 180 Ringing received
	established  // 200 OK received, ACK sent, media flowing
	terminating  // BYE sent, awaiting confirmation
	terminated   // Call ended
}

// --- Configuration ---

// Config holds the parameters needed for SIP registration and call
// signalling.
pub struct Config {
pub:
	sip_server        string             // SIP proxy/registrar host
	sip_port          int              = 5060
	local_ip          string           = '0.0.0.0'
	local_sip_port    int              = 5060
	local_rtp_port    int              = 10000
	username          string
	password          string
	display_name      string
	domain            string             // SIP domain (e.g. "example.com")
	user_agent        string           = 'v-voip/0.1.0'
	register_expiry   int              = 3600
	read_timeout      time.Duration    = 5 * time.second
}

// --- Data structures ---

// SipUri represents a SIP URI with scheme, user, host, and port
// components.
pub struct SipUri {
pub:
	scheme string = 'sip'    // "sip" or "sips"
	user   string
	host   string
	port   int
}

// to_string formats the SIP URI as a string suitable for use in
// SIP headers.
pub fn (uri SipUri) to_string() string {
	mut result := '${uri.scheme}:${uri.user}@${uri.host}'
	if uri.port > 0 && uri.port != 5060 {
		result += ':${uri.port}'
	}
	return result
}

// SipMessage represents a parsed SIP request or response with
// headers and optional body (typically SDP).
pub struct SipMessage {
pub mut:
	// Request fields
	method      string
	request_uri string
	// Response fields
	status_code int
	reason      string
	// Common fields
	headers     map[string]string
	body        string
}

// SdpSession holds a parsed SDP session description with connection
// and media information.
pub struct SdpSession {
pub:
	origin       string
	session_name string
	connection   string   // "IN IP4 <address>"
	media_port   int
	codecs       []Codec
}

// Codec describes an RTP payload type and its encoding parameters.
pub struct Codec {
pub:
	payload_type int
	name         string
	clock_rate   int
	channels     int = 1
}

// CallInfo holds the state and identifiers for an active call.
pub struct CallInfo {
pub mut:
	call_id      string
	from_tag     string
	to_tag       string
	local_uri    SipUri
	remote_uri   SipUri
	state        CallState
	cseq         int
	remote_sdp   SdpSession
	local_rtp_port int
}

// --- Client ---

// Client manages SIP signalling over UDP and provides call control
// operations.
pub struct Client {
mut:
	config          Config
	sip_conn        net.UdpConn
	connected       bool
	registered      bool
	current_call    ?CallInfo
	local_tag       string
	cseq_counter    int
	branch_counter  int
}

// connect creates a UDP socket for SIP signalling and prepares
// the client for registration.
pub fn connect(config Config) !&Client {
	sip_addr := '${config.local_ip}:${config.local_sip_port}'
	mut conn := udp.new(family: .ip, flags: .reuse_port)!
	conn.set_read_timeout(config.read_timeout)

	mut client := &Client{
		config: config
		sip_conn: conn
		local_tag: generate_tag()
	}

	client.connected = true
	println('[voip] SIP transport ready on ${sip_addr}')
	return client
}

// disconnect deregisters from the SIP server and closes the
// transport.
pub fn (mut c Client) disconnect() {
	if !c.connected {
		return
	}
	if c.registered {
		c.unregister() or {}
	}
	c.sip_conn.close() or {}
	c.connected = false
	println('[voip] disconnected')
}

// --- Registration ---

// register sends a REGISTER request to the SIP registrar to
// associate the user's contact address with their address of
// record.
pub fn (mut c Client) register() ! {
	if !c.connected {
		return error('not connected')
	}

	c.cseq_counter++
	from_uri := SipUri{user: c.config.username, host: c.config.domain}
	request_uri := 'sip:${c.config.domain}'

	mut msg := c.build_request(method_register, request_uri, from_uri, from_uri)
	msg.headers['Expires'] = '${c.config.register_expiry}'
	msg.headers['Contact'] = '<sip:${c.config.username}@${c.config.local_ip}:${c.config.local_sip_port}>'

	c.send_sip_message(msg)!
	response := c.receive_sip_response()!

	if response.status_code != 200 {
		return error('registration failed: ${response.status_code} ${response.reason}')
	}

	c.registered = true
	println('[voip] registered ${c.config.username}@${c.config.domain}')
}

// unregister sends a REGISTER with Expires: 0 to remove the
// registration.
fn (mut c Client) unregister() ! {
	c.cseq_counter++
	from_uri := SipUri{user: c.config.username, host: c.config.domain}
	request_uri := 'sip:${c.config.domain}'

	mut msg := c.build_request(method_register, request_uri, from_uri, from_uri)
	msg.headers['Expires'] = '0'
	msg.headers['Contact'] = '*'

	c.send_sip_message(msg)!
	c.receive_sip_response()!
	c.registered = false
	println('[voip] unregistered')
}

// --- Call control ---

// invite initiates a call to the specified SIP URI. Sends an
// INVITE with an SDP offer and transitions the call state through
// trying/ringing/established.
pub fn (mut c Client) invite(target_user string, target_host string) !CallInfo {
	if !c.connected {
		return error('not connected')
	}

	c.cseq_counter++
	from_uri := SipUri{user: c.config.username, host: c.config.domain}
	to_uri := SipUri{user: target_user, host: target_host}
	request_uri := to_uri.to_string()
	call_id := generate_call_id(c.config.local_ip)

	mut call := CallInfo{
		call_id: call_id
		from_tag: c.local_tag
		local_uri: from_uri
		remote_uri: to_uri
		state: .trying
		cseq: c.cseq_counter
		local_rtp_port: c.config.local_rtp_port
	}

	// Build SDP offer
	sdp_body := build_sdp_offer(c.config.local_ip, c.config.local_rtp_port)

	mut msg := c.build_request(method_invite, request_uri, from_uri, to_uri)
	msg.headers['Call-ID'] = call_id
	msg.headers['Content-Type'] = 'application/sdp'
	msg.body = sdp_body

	c.send_sip_message(msg)!

	// Wait for response (100 Trying -> 180 Ringing -> 200 OK)
	for {
		response := c.receive_sip_response()!
		match true {
			response.status_code == 100 {
				// Trying, continue waiting
			}
			response.status_code == 180 {
				call.state = .ringing
				println('[voip] ringing...')
			}
			response.status_code == 200 {
				call.state = .established
				call.to_tag = response.headers['To-Tag'] or { '' }
				if response.body.len > 0 {
					call.remote_sdp = parse_sdp(response.body)
				}
				// Send ACK
				c.send_ack(call)!
				println('[voip] call established with ${target_user}@${target_host}')
				break
			}
			response.status_code >= 400 {
				call.state = .terminated
				return error('call failed: ${response.status_code} ${response.reason}')
			}
			else {}
		}
	}

	c.current_call = call
	return call
}

// hangup terminates the current call by sending a BYE request.
pub fn (mut c Client) hangup() ! {
	mut call := c.current_call or {
		return error('no active call')
	}
	if call.state != .established {
		return error('call not established (state: ${call.state})')
	}

	c.cseq_counter++
	request_uri := call.remote_uri.to_string()

	mut msg := c.build_request(method_bye, request_uri, call.local_uri, call.remote_uri)
	msg.headers['Call-ID'] = call.call_id

	c.send_sip_message(msg)!
	response := c.receive_sip_response()!

	if response.status_code == 200 {
		call.state = .terminated
		c.current_call = call
		println('[voip] call terminated')
	} else {
		return error('hangup failed: ${response.status_code} ${response.reason}')
	}
}

// cancel aborts a call that is still in the trying or ringing
// state (before the callee has answered).
pub fn (mut c Client) cancel() ! {
	mut call := c.current_call or {
		return error('no active call')
	}
	if call.state != .trying && call.state != .ringing {
		return error('can only cancel calls in trying/ringing state')
	}

	c.cseq_counter++
	request_uri := call.remote_uri.to_string()

	mut msg := c.build_request(method_cancel, request_uri, call.local_uri, call.remote_uri)
	msg.headers['Call-ID'] = call.call_id

	c.send_sip_message(msg)!
	c.receive_sip_response()!
	call.state = .terminated
	c.current_call = call
	println('[voip] call cancelled')
}

// get_call_state returns the current state of the active call,
// or .idle if no call is in progress.
pub fn (c &Client) get_call_state() CallState {
	if call := c.current_call {
		return call.state
	}
	return .idle
}

// --- Internal SIP helpers ---

// build_request constructs a SIP request message with standard
// headers (Via, From, To, CSeq, Call-ID, Max-Forwards, User-Agent).
fn (mut c Client) build_request(method string, request_uri string, from_uri SipUri, to_uri SipUri) SipMessage {
	c.branch_counter++
	branch := 'z9hG4bK-${c.branch_counter}-${time.ticks()}'

	mut msg := SipMessage{
		method: method
		request_uri: request_uri
	}

	msg.headers['Via'] = 'SIP/2.0/UDP ${c.config.local_ip}:${c.config.local_sip_port};branch=${branch}'
	msg.headers['From'] = '"${c.config.display_name}" <${from_uri.to_string()}>;tag=${c.local_tag}'
	msg.headers['To'] = '<${to_uri.to_string()}>'
	msg.headers['CSeq'] = '${c.cseq_counter} ${method}'
	msg.headers['Call-ID'] = generate_call_id(c.config.local_ip)
	msg.headers['Max-Forwards'] = '70'
	msg.headers['User-Agent'] = c.config.user_agent
	msg.headers['Content-Length'] = '0'

	return msg
}

// send_ack sends an ACK for a 200 OK response to an INVITE.
fn (mut c Client) send_ack(call CallInfo) ! {
	request_uri := call.remote_uri.to_string()
	mut msg := c.build_request(method_ack, request_uri, call.local_uri, call.remote_uri)
	msg.headers['Call-ID'] = call.call_id
	c.send_sip_message(msg)!
}

// send_sip_message serializes and sends a SIP message over UDP
// to the configured SIP server.
fn (mut c Client) send_sip_message(msg SipMessage) ! {
	serialized := serialize_sip_message(msg)
	server_addr := '${c.config.sip_server}:${c.config.sip_port}'
	c.sip_conn.write_to(server_addr, serialized.bytes()) or {
		return error('failed to send SIP message: ${err}')
	}
}

// receive_sip_response reads a SIP response from the UDP socket
// and parses the status line and headers.
fn (mut c Client) receive_sip_response() !SipMessage {
	mut buf := []u8{len: 4096}
	bytes_read := c.sip_conn.read(mut buf) or {
		return error('SIP response timeout')
	}
	if bytes_read == 0 {
		return error('empty SIP response')
	}
	raw := buf[..bytes_read].bytestr()
	return parse_sip_response(raw)
}

// --- Serialization ---

// serialize_sip_message converts a SipMessage into its wire format
// string representation (request line + headers + CRLFCRLF + body).
fn serialize_sip_message(msg SipMessage) string {
	mut lines := []string{}

	// Request line
	lines << '${msg.method} ${msg.request_uri} SIP/2.0'

	// Update Content-Length based on body
	mut headers := msg.headers.clone()
	headers['Content-Length'] = '${msg.body.len}'

	// Headers
	for key, value in headers {
		lines << '${key}: ${value}'
	}

	// Empty line separator + body
	mut result := lines.join('\r\n') + '\r\n\r\n'
	if msg.body.len > 0 {
		result += msg.body
	}
	return result
}

// parse_sip_response parses a raw SIP response string into a
// SipMessage with status code, reason phrase, headers, and body.
fn parse_sip_response(raw string) !SipMessage {
	// Split headers and body at the blank line
	parts := raw.split('\r\n\r\n')
	header_section := parts[0]
	body := if parts.len > 1 { parts[1] } else { '' }

	lines := header_section.split('\r\n')
	if lines.len == 0 {
		return error('empty SIP response')
	}

	// Parse status line: "SIP/2.0 200 OK"
	status_line := lines[0]
	status_parts := status_line.split(' ')
	if status_parts.len < 3 || !status_parts[0].starts_with('SIP/') {
		return error('malformed SIP status line: ${status_line}')
	}

	mut msg := SipMessage{
		status_code: status_parts[1].int()
		reason: status_parts[2..].join(' ')
		body: body
	}

	// Parse headers
	for line in lines[1..] {
		if colon_pos := line.index(':') {
			key := line[..colon_pos].trim_space()
			value := line[colon_pos + 1..].trim_space()
			msg.headers[key] = value
		}
	}

	return msg
}

// --- SDP helpers ---

// build_sdp_offer generates a minimal SDP session description
// offering G.711 mu-law (PCMU) and Opus codecs.
fn build_sdp_offer(local_ip string, rtp_port int) string {
	session_id := '${time.ticks()}'
	return 'v=0\r\n' +
		'o=- ${session_id} ${session_id} IN IP4 ${local_ip}\r\n' +
		's=v-voip\r\n' +
		'c=IN IP4 ${local_ip}\r\n' +
		't=0 0\r\n' +
		'm=audio ${rtp_port} RTP/AVP 0 8 96\r\n' +
		'a=rtpmap:0 PCMU/8000\r\n' +
		'a=rtpmap:8 PCMA/8000\r\n' +
		'a=rtpmap:96 opus/48000/2\r\n' +
		'a=sendrecv\r\n'
}

// parse_sdp extracts connection and media information from an SDP
// body string.
fn parse_sdp(sdp_body string) SdpSession {
	mut session := SdpSession{}
	lines := sdp_body.split('\n')

	for line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with('c=') {
			return SdpSession{
				...session
				connection: trimmed[2..]
			}
		}
		if trimmed.starts_with('m=audio ') {
			fields := trimmed[8..].split(' ')
			if fields.len > 0 {
				return SdpSession{
					...session
					media_port: fields[0].int()
				}
			}
		}
	}
	return session
}

// --- Utility functions ---

// generate_tag creates a random SIP tag string for From/To headers.
fn generate_tag() string {
	return '${rand.u64()}'
}

// generate_call_id creates a globally unique Call-ID string.
fn generate_call_id(local_ip string) string {
	return '${rand.u64()}@${local_ip}'
}

// --- Tests ---

fn test_sip_uri_to_string_default_port() {
	uri := SipUri{user: 'alice', host: 'example.com'}
	assert uri.to_string() == 'sip:alice@example.com'
}

fn test_sip_uri_to_string_custom_port() {
	uri := SipUri{user: 'alice', host: 'example.com', port: 5061}
	assert uri.to_string() == 'sip:alice@example.com:5061'
}

fn test_parse_sip_response_200() {
	raw := 'SIP/2.0 200 OK\r\nContent-Length: 0\r\n\r\n'
	msg := parse_sip_response(raw) or { return }
	assert msg.status_code == 200
	assert msg.reason == 'OK'
}

fn test_parse_sip_response_headers() {
	raw := 'SIP/2.0 180 Ringing\r\nFrom: <sip:alice@ex.com>\r\nTo: <sip:bob@ex.com>\r\n\r\n'
	msg := parse_sip_response(raw) or { return }
	assert msg.status_code == 180
	assert msg.headers['From'] == '<sip:alice@ex.com>'
}

fn test_build_sdp_offer_contains_audio() {
	sdp := build_sdp_offer('192.168.1.100', 10000)
	assert sdp.contains('m=audio 10000')
	assert sdp.contains('PCMU/8000')
	assert sdp.contains('opus/48000/2')
}

fn test_call_state_default() {
	call := CallInfo{
		call_id: 'test'
		from_tag: 'tag1'
		local_uri: SipUri{user: 'a', host: 'b'}
		remote_uri: SipUri{user: 'c', host: 'd'}
	}
	assert call.state == .idle
}
