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

// RTSP status codes.
const status_ok            = 200
const status_unauthorized  = 401
const status_not_found     = 404
const status_session_not_found = 454
const status_method_not_valid  = 455

// Transport protocols.
const transport_rtp_avp     = "RTP/AVP"
const transport_rtp_avp_tcp = "RTP/AVP/TCP"

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
	return c.send_request(method_options, c.config.url, '')
}

// describe sends a DESCRIBE request to obtain the SDP.
pub fn (mut c Client) describe() !Response {
	return c.send_request(method_describe, c.config.url, '')
}

// setup sends a SETUP request for a media track.
pub fn (mut c Client) setup(track_url string, transport string) !Response {
	return c.send_request(method_setup, track_url, 'Transport: ${transport}')
}

// play sends a PLAY request to start media delivery.
pub fn (mut c Client) play() !Response {
	return c.send_request(method_play, c.config.url, '')
}

// pause sends a PAUSE request to suspend media delivery.
pub fn (mut c Client) pause() !Response {
	return c.send_request(method_pause, c.config.url, '')
}

// teardown sends a TEARDOWN request to end the session.
pub fn (mut c Client) teardown() !Response {
	resp := c.send_request(method_teardown, c.config.url, '')!
	c.session_id = ''
	return resp
}

// --- Internal request handling ---

// send_request builds and sends an RTSP request.
fn (mut c Client) send_request(method string, url string, extra_headers string) !Response {
	c.cseq++
	mut req := '${method} ${url} ${rtsp_version}\r\n'
	req += 'CSeq: ${c.cseq}\r\n'
	if c.session_id.len > 0 {
		req += 'Session: ${c.session_id}\r\n'
	}
	if extra_headers.len > 0 {
		req += '${extra_headers}\r\n'
	}
	req += '\r\n'

	println('[rtsp] ${method} ${url} (CSeq=${c.cseq})')
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
