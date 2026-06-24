// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/transport.v — Transport layer for MCP communication.
//
// Implements the stdio transport with Content-Length header framing
// as required by the MCP specification. The stdio transport reads
// from stdin and writes to stdout, using a "Content-Length: N\r\n\r\n"
// header before each JSON-RPC message body.

module v_mcp

import os
import io

// --- Content-Length framing -------------------------------------------------------

// write_message writes a JSON-RPC message to stdout with Content-Length
// header framing per the MCP specification. The format is:
//
//   Content-Length: <byte_count>\r\n
//   \r\n
//   <json_body>
//
// This ensures compliant framing regardless of message content.
pub fn write_message(body string) {
	header := 'Content-Length: ${body.len}\r\n\r\n'
	mut out := os.stdout()
	out.write(header.bytes()) or {}
	out.write(body.bytes()) or {}
	out.flush()
}

// read_message reads a single Content-Length-framed JSON-RPC message
// from stdin. Parses the Content-Length header to determine how many
// bytes to read for the body.
//
// Returns the raw JSON body string, or an error if stdin is closed
// or the framing is malformed.
pub fn read_message() !string {
	mut reader := io.new_buffered_reader(reader: os.stdin())

	// Read the Content-Length header line.
	header_line := reader.read_line() or {
		return error('stdin closed or read error')
	}

	trimmed := header_line.trim_space()
	if !trimmed.starts_with('Content-Length:') {
		return error('Expected Content-Length header, got: "${trimmed}"')
	}

	length_str := trimmed.all_after(':').trim_space()
	content_length := length_str.int()
	if content_length <= 0 {
		return error('Invalid Content-Length: "${length_str}"')
	}

	if content_length > max_content_size {
		return error('Content-Length ${content_length} exceeds maximum ${max_content_size}')
	}

	// Read the blank separator line (\r\n).
	separator := reader.read_line() or {
		return error('Expected blank line after Content-Length header')
	}
	if separator.trim_space().len > 0 {
		return error('Expected blank separator line, got: "${separator}"')
	}

	// Read exactly content_length bytes for the body.
	mut body_buf := []u8{len: content_length}
	mut total_read := 0
	for total_read < content_length {
		bytes_read := reader.read(mut body_buf[total_read..]) or {
			return error('Failed to read message body: ${err}')
		}
		if bytes_read == 0 {
			return error('Unexpected EOF reading message body (read ${total_read}/${content_length} bytes)')
		}
		total_read += bytes_read
	}

	return body_buf.bytestr()
}

// --- Logging (stderr) -------------------------------------------------------------

// log_to_stderr writes a diagnostic message to stderr. MCP servers must
// not write anything to stdout except framed JSON-RPC messages; all
// diagnostic output goes to stderr.
pub fn log_to_stderr(message string) {
	mut err_out := os.stderr()
	err_out.write('${message}\n'.bytes()) or {}
	err_out.flush()
}
