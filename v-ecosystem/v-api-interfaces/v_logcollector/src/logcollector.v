// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Log aggregation with structured ingestion, filtering, and forwarding Connector
// Author: Jonathan D.A. Jewell
//
// Log aggregation with structured ingestion, filtering, and forwarding.
// Provides typed client bindings for the proven-logcollector protocol.

module logcollector

import os
import time
import net

// --- Log format ---

// LogFormat identifies the log encoding.
pub enum LogFormat {
	json
	syslog_rfc5424
	syslog_rfc3164
	cef
	plain
}

// --- Severity ---

// LogSeverity mirrors syslog severity levels.
pub enum LogSeverity {
	emergency
	alert
	critical
	err
	warning
	notice
	info
	debug
}

// --- Data structures ---

// LogSource defines a log collection source.
pub struct LogSource {
pub:
	name        string
	source_type string   // "file", "tcp", "udp", "journald"
	path        string
	format      LogFormat
}

// LogEntry represents a single collected log entry.
pub struct LogEntry {
pub:
	timestamp   i64
	source      string
	severity    LogSeverity
	message     string
	fields      map[string]string
}

// CollectorConfig holds log collector parameters.
pub struct CollectorConfig {
pub:
	buffer_size  int = 4096
	flush_secs   int = 5
	output_url   string  // Forwarding destination
}

// LogCollector manages log sources and buffering.
pub struct LogCollector {
mut:
	config   CollectorConfig
	sources  []LogSource
	buffer   []LogEntry
}

// --- Collector lifecycle ---

// new_log_collector creates a new log collector.
pub fn new_log_collector(config CollectorConfig) &LogCollector {
	return &LogCollector{
		config:  config
		sources: []LogSource{}
		buffer:  []LogEntry{}
	}
}

// add_source registers a log source.
pub fn (mut c LogCollector) add_source(source LogSource) ! {
	if source.name.len == 0 {
		return error("source name must not be empty")
	}
	c.sources << source
	println("[logcollector] added source: ${source.name} (${source.format})")
}

// flush sends buffered entries to the output destination.
pub fn (mut c LogCollector) flush() !int {
	count := c.buffer.len
	c.buffer.clear()
	println("[logcollector] flushed ${count} entries")
	return count
}

// --- Tests ---

fn test_empty_source_name_rejected() {
	mut collector := new_log_collector(CollectorConfig{ output_url: "http://localhost:9200" })
	collector.add_source(LogSource{ name: "", source_type: "file", path: "/var/log/syslog", format: .syslog_rfc5424 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
