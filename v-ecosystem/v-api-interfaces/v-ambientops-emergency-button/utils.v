// SPDX-License-Identifier: PMPL-1.0-or-later
// Shared utilities for system-emergency-room
// HIGH-006: Atomic file writes with temp+rename pattern
// HIGH-008: Structured logging infrastructure

module main

import os
import rand
import time

// Atomic write: write to temp file, then rename
// Prevents file corruption if process crashes during write
fn atomic_write_file(path string, content string) ! {
	// Create temp file in same directory (ensures same filesystem for atomic rename)
	dir := os.dir(path)
	basename := os.file_name(path)
	temp_name := '.${basename}.${rand.hex(8)}.tmp'
	temp_path := os.join_path(dir, temp_name)

	// Write to temp file
	os.write_file(temp_path, content) or {
		return error('Failed to write temp file: ${err}')
	}

	// Rename temp to final (atomic on POSIX, near-atomic on Windows)
	os.mv(temp_path, path) or {
		// Clean up temp file on failure
		os.rm(temp_path) or {}
		return error('Failed to rename temp file: ${err}')
	}
}

// Safe append: read existing, append, atomic write
fn atomic_append_file(path string, content string) ! {
	existing := os.read_file(path) or { '' }
	atomic_write_file(path, existing + content)!
}

// Schema version constant for all outputs
const schema_version = '1.0.0'

// Structured log entry for machine-readable logging
struct LogEntry {
	timestamp  string
	level      string  // info, warn, error, debug
	component  string  // which part of the system
	message    string
	context    map[string]string  // additional key-value pairs
}

fn format_log_entry(entry LogEntry) string {
	mut parts := ['ts=${entry.timestamp}', 'level=${entry.level}', 'component=${entry.component}']

	// Escape message for structured format
	escaped_msg := entry.message.replace('"', '\\"').replace('\n', '\\n')
	parts << 'msg="${escaped_msg}"'

	for key, value in entry.context {
		escaped_val := value.replace('"', '\\"').replace('\n', '\\n')
		parts << '${key}="${escaped_val}"'
	}

	return parts.join(' ')
}

// Write a structured log entry to the incident's structured.log file
fn log_structured(logs_path string, level string, component string, message string, context map[string]string) {
	log_file := os.join_path(logs_path, 'structured.log')

	entry := LogEntry{
		timestamp: time.now().format_rfc3339()
		level: level
		component: component
		message: message
		context: context
	}

	line := format_log_entry(entry) + '\n'

	// Append to log file (best effort - don't fail on logging errors)
	atomic_append_file(log_file, line) or {}
}

// Convenience functions for each log level
fn log_info(logs_path string, component string, message string) {
	log_structured(logs_path, 'info', component, message, map[string]string{})
}

fn log_warn(logs_path string, component string, message string) {
	log_structured(logs_path, 'warn', component, message, map[string]string{})
}

fn log_error(logs_path string, component string, message string, context map[string]string) {
	log_structured(logs_path, 'error', component, message, context)
}

fn log_debug(logs_path string, component string, message string) {
	log_structured(logs_path, 'debug', component, message, map[string]string{})
}
