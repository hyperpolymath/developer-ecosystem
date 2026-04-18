// SPDX-License-Identifier: PMPL-1.0-or-later
//
// redis_client.v — Redis Client for Cache and Audit Log
//
// Provides two capabilities:
//   1. Result caching with TTL — avoids hammering backend probes
//   2. Audit log — append-only list of PolicyDecision/AuditEvent records
//
// Uses raw Redis RESP protocol over TCP for zero external dependencies.
// Redis is available at the REDIS_URL environment variable (default redis://redis:6379).

module main

import net
import os

// RedisClient holds a TCP connection to the Redis server.
// Connection is lazily established on first use.
pub struct RedisClient {
mut:
	conn ?net.TcpConn
	host string
	port int
}

// new_redis_client creates a RedisClient from the REDIS_URL environment
// variable. Falls back to redis://localhost:6379 if unset.
// Does NOT connect immediately — connection is deferred to first command.
pub fn new_redis_client() RedisClient {
	redis_url := os.getenv('REDIS_URL')
	mut host := 'redis'
	mut port := 6379

	if redis_url.len > 0 {
		// Parse redis://host:port
		stripped := redis_url.replace('redis://', '')
		parts := stripped.split(':')
		if parts.len >= 1 {
			host = parts[0]
		}
		if parts.len >= 2 {
			port = parts[1].int()
			if port == 0 {
				port = 6379
			}
		}
	}

	return RedisClient{
		conn: none
		host: host
		port: port
	}
}

// ensure_connected establishes a TCP connection to Redis if not
// already connected. Returns an error if connection fails.
fn (mut c RedisClient) ensure_connected() ! {
	if c.conn != none {
		return
	}
	c.conn = net.dial_tcp('${c.host}:${c.port}') or {
		return error('redis: failed to connect to ${c.host}:${c.port}: ${err}')
	}
}

// send_command sends a raw RESP command to Redis and returns the response.
// Uses the RESP protocol: *<argc>\r\n$<len>\r\n<arg>\r\n ...
fn (mut c RedisClient) send_command(args []string) !string {
	c.ensure_connected()!
	mut conn := c.conn or { return error('redis: not connected') }

	// Build RESP array
	mut buf := '*${args.len}\r\n'
	for arg in args {
		buf += '\$${arg.len}\r\n${arg}\r\n'
	}

	conn.write(buf.bytes()) or {
		// Connection may have been dropped — retry once
		c.conn = none
		c.ensure_connected()!
		conn = c.conn or { return error('redis: reconnect failed') }
		conn.write(buf.bytes()) or {
			return error('redis: write failed after reconnect: ${err}')
		}
	}

	// Read response (up to 8KB — sufficient for most operations)
	mut response := []u8{len: 8192}
	bytes_read := conn.read(mut response) or {
		return error('redis: read failed: ${err}')
	}
	return response[..bytes_read].bytestr()
}

// cache_result stores a value in Redis with a TTL in seconds.
// Key is prefixed with "aerie:cache:" to namespace entries.
pub fn (mut c RedisClient) cache_result(key string, value string, ttl int) {
	prefixed_key := 'aerie:cache:${key}'
	c.send_command(['SET', prefixed_key, value, 'EX', ttl.str()]) or {
		eprintln('redis: cache_result failed: ${err}')
	}
}

// get_cached retrieves a cached value by key. Returns empty string
// if the key does not exist or Redis is unreachable.
pub fn (mut c RedisClient) get_cached(key string) string {
	prefixed_key := 'aerie:cache:${key}'
	response := c.send_command(['GET', prefixed_key]) or {
		return ''
	}
	// RESP bulk string: $<len>\r\n<data>\r\n or $-1\r\n for nil
	if response.starts_with('\$-1') {
		return ''
	}
	lines := response.split('\r\n')
	if lines.len >= 2 {
		return lines[1]
	}
	return ''
}

// log_audit appends an AuditEvent to the Redis list "aerie:audit".
// Events are serialised as JSON strings. The list is capped at 10000
// entries using LTRIM to prevent unbounded growth.
pub fn (mut c RedisClient) log_audit(event AuditEvent) {
	event_json := audit_event_to_json(event)
	c.send_command(['RPUSH', 'aerie:audit', event_json]) or {
		eprintln('redis: log_audit RPUSH failed: ${err}')
		return
	}
	// Cap the audit log at 10000 entries
	c.send_command(['LTRIM', 'aerie:audit', '-10000', '-1']) or {
		eprintln('redis: log_audit LTRIM failed: ${err}')
	}
}

// get_audit_log retrieves the most recent `limit` audit events from
// the Redis list. Returns them as JSON strings (caller parses as needed).
pub fn (mut c RedisClient) get_audit_log(limit int) []string {
	capped := if limit <= 0 { 50 } else { limit }
	response := c.send_command(['LRANGE', 'aerie:audit', '-${capped}', '-1']) or {
		return []
	}
	// Parse RESP array response
	return parse_resp_array(response)
}

// audit_event_to_json serialises an AuditEvent to a JSON string.
fn audit_event_to_json(event AuditEvent) string {
	tags_json := if event.tags.len == 0 {
		'[]'
	} else {
		'["' + event.tags.join('","') + '"]'
	}
	return '{"event_id":"${event.event_id}","valid_time":"${event.valid_time}","tx_time":"${event.tx_time}","severity":"${event.severity}","message":"${event.message}","tags":${tags_json}}'
}

// parse_resp_array extracts string elements from a RESP array response.
// Format: *<count>\r\n$<len>\r\n<data>\r\n ...
fn parse_resp_array(response string) []string {
	mut results := []string{}
	lines := response.split('\r\n')
	if lines.len == 0 || !lines[0].starts_with('*') {
		return results
	}

	mut i := 1
	for i < lines.len {
		if lines[i].starts_with('\$') {
			// Next line is the data
			if i + 1 < lines.len {
				results << lines[i + 1]
				i += 2
			} else {
				break
			}
		} else {
			i += 1
		}
	}
	return results
}
