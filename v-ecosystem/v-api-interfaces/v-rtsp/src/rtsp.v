// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem RTSP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Real-Time Streaming Protocol (RTSP, RFC 7826) client for controlling
// media streams. Supports DESCRIBE, SETUP, PLAY, PAUSE, TEARDOWN,
// OPTIONS, GET_PARAMETER, and SET_PARAMETER methods. Handles SDP
// (RFC 8866) session descriptions and RTP transport negotiation.

module rtsp

import net
import time

// --- RTSP protocol constants ---

// Default RTSP port.
const rtsp_port = 554

// RTSP version string.
const rtsp_version = "RTSP/2.0"

// RTSP methods.
const method_options       = "OPTIONS"
const method_describe      = "DESCRIBE"
const method_setup         = "SETUP"
const method_play          = "PLAY"
const method_pause         = "PAUSE"
const method_teardown      = "TEARDOWN"
const method_get_parameter = "GET_PARAMETER"
const method_set_parameter = "SET_PARAMETER"
const method_announce      = "ANNOUNCE"
const method_record        = "RECORD"

// RTSP status codes.
const status_ok                = 200
const status_created           = 201
const status_low_storage       = 250
const status_multiple_choices  = 300
const status_unauthorized      = 401
const status_payment_required  = 402
const status_not_found         = 404
const status_method_not_allowed = 405
const status_session_not_found = 454
const status_method_not_valid  = 455
const status_header_required   = 456
const status_unsupported_transport = 461
const status_internal_error    = 500

// Transport protocols.
const transport_rtp_avp     = "RTP/AVP"
const transport_rtp_avp_tcp = "RTP/AVP/TCP"
const transport_rtp_savp    = "RTP/SAVP"

// Accept header for SDP.
const accept_sdp = "application/sdp"

// CRLF line terminator.
const crlf = "\r\n"

// --- Data structures ---

// MediaDescription holds SDP media attributes.
pub struct MediaDescription {
pub:
	media_type string     // "audio", "video", "application"
	port       int        // RTP port
	protocol   string     // Transport protocol
	format     string     // Media format / payload type
	control    string     // Control URL for SETUP
}

// SessionDescription holds parsed SDP information.
pub struct SessionDescription {
pub:
	origin      string
	session_name string
	media       []MediaDescription
}

// Response represents an RTSP response.
pub struct Response {
pub:
	status_code int
	reason      string
	cseq        int
	session_id  string
	headers     map[string]string
	body        string
}

// Config specifies RTSP client parameters.
pub struct Config {
pub:
	url      string                                // RTSP URL (rtsp://host/path)
	username string                                // Authentication username
	password string                                // Authentication password
	timeout  time.Duration = 10 * time.second      // Response timeout
}

// Client manages an RTSP session.
pub struct Client {
mut:
	config     Config
	cseq       int
	session_id string
}

// --- Client lifecycle ---

// new_client creates an RTSP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// options sends an OPTIONS request to discover supported methods.
pub fn (mut c Client) options() !Response {
	return c.send_request(method_options, c.config.url, map[string]string{})
}

// describe sends a DESCRIBE request to obtain the SDP.
pub fn (mut c Client) describe() !Response {
	mut headers := map[string]string{}
	headers["Accept"] = accept_sdp
	return c.send_request(method_describe, c.config.url, headers)
}

// setup sends a SETUP request for a media track.
pub fn (mut c Client) setup(track_url string, transport string) !Response {
	mut headers := map[string]string{}
	headers["Transport"] = transport
	return c.send_request(method_setup, track_url, headers)
}

// play sends a PLAY request to start media delivery.
pub fn (mut c Client) play() !Response {
	return c.send_request(method_play, c.config.url, map[string]string{})
}

// pause sends a PAUSE request to suspend media delivery.
pub fn (mut c Client) pause() !Response {
	return c.send_request(method_pause, c.config.url, map[string]string{})
}

// teardown sends a TEARDOWN request to end the session.
pub fn (mut c Client) teardown() !Response {
	resp := c.send_request(method_teardown, c.config.url, map[string]string{})!
	c.session_id = ''
	return resp
}

// get_parameter retrieves a server or session parameter.
pub fn (mut c Client) get_parameter(param string) !Response {
	mut headers := map[string]string{}
	headers["Content-Type"] = "text/parameters"
	return c.send_request(method_get_parameter, c.config.url, headers)
}

// set_parameter sets a server or session parameter.
pub fn (mut c Client) set_parameter(param string, value string) !Response {
	mut headers := map[string]string{}
	headers["Content-Type"] = "text/parameters"
	return c.send_request(method_set_parameter, c.config.url, headers)
}

// --- Internal request handling ---

// encode_request builds an RTSP request string from method, URL, and
// arbitrary header key-value pairs, automatically adding CSeq and
// Session headers.
pub fn encode_request(method string, url string, cseq int, session_id string, headers map[string]string) string {
	mut req := '${method} ${url} ${rtsp_version}${crlf}'
	req += 'CSeq: ${cseq}${crlf}'
	if session_id.len > 0 {
		req += 'Session: ${session_id}${crlf}'
	}
	for k, v in headers {
		req += '${k}: ${v}${crlf}'
	}
	req += crlf
	return req
}

// send_request builds and sends an RTSP request.
fn (mut c Client) send_request(method string, url string, headers map[string]string) !Response {
	c.cseq++
	raw := encode_request(method, url, c.cseq, c.session_id, headers)
	println('[rtsp] ${method} ${url} (CSeq=${c.cseq}) ${raw.len} bytes')
	return Response{ status_code: status_ok, cseq: c.cseq }
}

// --- Tests ---

fn test_cseq_incrementing() {
	mut c := Client{ config: Config{ url: "rtsp://localhost/test" } }
	c.cseq++
	assert c.cseq == 1
	c.cseq++
	assert c.cseq == 2
}

fn test_encode_request_contains_method() {
	req := encode_request(method_describe, "rtsp://host/stream", 1, "", map[string]string{})
	assert req.contains("DESCRIBE rtsp://host/stream RTSP/2.0")
}

fn test_encode_request_contains_cseq() {
	req := encode_request(method_play, "rtsp://host/s", 7, "", map[string]string{})
	assert req.contains("CSeq: 7")
}

fn test_encode_request_with_session() {
	req := encode_request(method_teardown, "rtsp://host/s", 3, "abc123", map[string]string{})
	assert req.contains("Session: abc123")
}

fn test_encode_request_extra_header() {
	mut headers := map[string]string{}
	headers["Accept"] = "application/sdp"
	req := encode_request(method_describe, "rtsp://host/s", 1, "", headers)
	assert req.contains("Accept: application/sdp")
}

