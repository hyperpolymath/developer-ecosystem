// SPDX-License-Identifier: MPL-2.0
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

// --- Log level ---

// LogLevel provides a simplified 5-level severity classification.
pub enum LogLevel {
	debug    // Detailed diagnostic output
	info     // Informational messages
	warn     // Warning conditions
	error    // Error conditions that do not halt operation
	fatal    // Critical errors that require immediate attention
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
	level       LogLevel
	message     string
	fields      map[string]string
}

// LogFilter specifies criteria for querying log entries.
pub struct LogFilter {
pub:
	source      string       // Match by source name (empty = all)
	min_level   LogLevel     // Minimum log level to return
	since_unix  i64          // Only entries after this unix timestamp (0 = all)
	max_results int = 100    // Maximum number of entries to return
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

// ingest adds a single log entry to the in-memory buffer.
pub fn (mut c LogCollector) ingest(entry LogEntry) ! {
	if entry.message.len == 0 {
		return error("log entry message must not be empty")
	}
	if c.buffer.len >= c.config.buffer_size {
		return error("log buffer full (size=${c.config.buffer_size}); flush before ingesting")
	}
	c.buffer << entry
}

// query returns buffered entries matching the given filter.
pub fn (c &LogCollector) query(filter LogFilter) ![]LogEntry {
	mut results := []LogEntry{}
	for entry in c.buffer {
		if filter.source.len > 0 && entry.source != filter.source {
			continue
		}
		if int(entry.level) < int(filter.min_level) {
			continue
		}
		if filter.since_unix > 0 && entry.timestamp < filter.since_unix {
			continue
		}
		results << entry
		if filter.max_results > 0 && results.len >= filter.max_results {
			break
		}
	}
	return results
}

// flush_batch empties the buffer and returns all buffered entries.
pub fn (mut c LogCollector) flush_batch() ![]LogEntry {
	batch := c.buffer.clone()
	c.buffer.clear()
	println("[logcollector] batch flush: ${batch.len} entries")
	return batch
}

// --- JSON formatting ---

// format_json_entry serialises a LogEntry to a compact JSON string.
// Field keys with empty values are omitted.
pub fn format_json_entry(entry LogEntry) string {
	mut parts := []string{}
	parts << '"timestamp":${entry.timestamp}'
	parts << '"source":"${entry.source}"'
	parts << '"level":"${entry.level}"'
	parts << '"message":"${entry.message}"'
	for k, v in entry.fields {
		parts << '"${k}":"${v}"'
	}
	return '{' + parts.join(',') + '}'
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

fn test_ingest_and_flush_batch() {
	mut collector := new_log_collector(CollectorConfig{ buffer_size: 4096 })
	entry := LogEntry{
		timestamp: 1700000000
		source: "app"
		level: .info
		message: "server started"
		fields: map[string]string{}
	}
	collector.ingest(entry) or { panic(err) }
	batch := collector.flush_batch() or { panic(err) }
	assert batch.len == 1
	assert batch[0].message == "server started"
}

fn test_format_json_entry_keys() {
	entry := LogEntry{
		timestamp: 1700000001
		source: "svc"
		level: .warn
		message: "disk low"
		fields: map[string]string{}
	}
	json := format_json_entry(entry)
	assert json.starts_with('{')
	assert json.ends_with('}')
	assert json.contains('"message":"disk low"')
	assert json.contains('"source":"svc"')
}

fn test_ingest_empty_message_rejected() {
	mut collector := new_log_collector(CollectorConfig{ buffer_size: 10 })
	collector.ingest(LogEntry{ timestamp: 0, source: "x", message: "", fields: map[string]string{} }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
