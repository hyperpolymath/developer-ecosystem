// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Security information and event management with correlation and incident response Connector
// Author: Jonathan D.A. Jewell
//
// Security information and event management with correlation and incident response.
// Provides typed client bindings for the proven-siem protocol.

module siem

import os
import time
import net

// --- Event source ---

// EventSourceType classifies the SIEM event source.
pub enum EventSourceType {
	firewall
	ids_ips
	endpoint
	application
	cloud
	identity
}

// --- Incident severity ---

// IncidentSeverity classifies security incident severity.
pub enum IncidentSeverity {
	info
	low
	medium
	high
	critical
}

// --- SIEM event type ---

// SiemEventType classifies security-relevant event categories.
pub enum SiemEventType {
	login               // Successful authentication
	logout              // Session termination
	failed_auth         // Failed authentication attempt
	privilege_escalation // Privilege escalation (sudo, su, UAC)
	data_exfil          // Suspected data exfiltration
}

// --- Data structures ---

// SecurityEvent represents a normalised security event.
pub struct SecurityEvent {
pub:
	event_id    string
	source_type EventSourceType
	timestamp   i64
	severity    IncidentSeverity
	message     string
	raw_log     string
}

// SiemEvent is a richer security event with classification metadata.
pub struct SiemEvent {
pub:
	event_id    string
	event_type  SiemEventType
	source_type EventSourceType
	timestamp   i64
	severity    IncidentSeverity
	src_ip      string
	dst_ip      string
	username    string
	message     string
	raw_log     string
}

// SiemAlert represents a correlated security alert raised by a rule.
pub struct SiemAlert {
pub:
	alert_id    string
	rule_id     string
	severity    IncidentSeverity
	description string
	event_ids   []string
	raised_at   i64
}

// CorrelationRule defines an event correlation rule.
pub struct CorrelationRule {
pub:
	rule_id     string
	name        string
	pattern     string      // Correlation pattern expression
	window_secs int = 300   // Time window for correlation
	threshold   int = 1     // Event count threshold
}

// SiemConfig holds SIEM parameters.
pub struct SiemConfig {
pub:
	index_prefix  string = "siem-"
	retention_days int = 90
	max_eps       int = 10000  // Maximum events per second
}

// SiemEngine manages security events and correlation.
pub struct SiemEngine {
mut:
	config  SiemConfig
	rules   []CorrelationRule
	events  []SecurityEvent
	siem_events []SiemEvent
	alerts  []SiemAlert
}

// --- Engine lifecycle ---

// new_siem_engine creates a new SIEM engine.
pub fn new_siem_engine(config SiemConfig) &SiemEngine {
	return &SiemEngine{
		config: config
		rules:  []CorrelationRule{}
		events: []SecurityEvent{}
		siem_events: []SiemEvent{}
		alerts: []SiemAlert{}
	}
}

// add_rule registers a correlation rule.
pub fn (mut e SiemEngine) add_rule(rule CorrelationRule) ! {
	if rule.rule_id.len == 0 {
		return error("rule_id must not be empty")
	}
	e.rules << rule
	println("[siem] added correlation rule: ${rule.name} (window=${rule.window_secs}s)")
}

// ingest ingests a security event.
pub fn (mut e SiemEngine) ingest(event SecurityEvent) ! {
	if event.event_id.len == 0 {
		return error("event_id must not be empty")
	}
	e.events << event
}

// ingest_event ingests a richly-typed SiemEvent into the engine.
pub fn (mut e SiemEngine) ingest_event(event SiemEvent) ! {
	if event.event_id.len == 0 {
		return error("event_id must not be empty")
	}
	e.siem_events << event
	println("[siem] ingested ${event.event_type} event from ${event.src_ip}")
}

// correlate applies all registered rules to the buffered events
// within the given time window and returns any alerts raised.
pub fn (mut e SiemEngine) correlate(window_secs int) ![]SiemAlert {
	if window_secs <= 0 {
		return error("correlation window must be positive")
	}
	mut new_alerts := []SiemAlert{}
	cutoff := time.now().unix() - i64(window_secs)
	for rule in e.rules {
		mut matching := []string{}
		for ev in e.siem_events {
			if ev.timestamp >= cutoff {
				matching << ev.event_id
			}
		}
		if matching.len >= rule.threshold {
			alert := SiemAlert{
				alert_id: "alert-${rule.rule_id}-${time.now().unix()}"
				rule_id: rule.rule_id
				severity: .medium
				description: "Rule '${rule.name}' triggered (${matching.len} events)"
				event_ids: matching
				raised_at: time.now().unix()
			}
			e.alerts << alert
			new_alerts << alert
			println("[siem] ALERT: ${alert.description}")
		}
	}
	return new_alerts
}

// get_alerts returns all stored alerts at or above the given severity.
pub fn (e &SiemEngine) get_alerts(severity IncidentSeverity) ![]SiemAlert {
	mut results := []SiemAlert{}
	for alert in e.alerts {
		if int(alert.severity) >= int(severity) {
			results << alert
		}
	}
	return results
}

// --- CEF formatting ---

// format_cef serialises a SiemEvent to ArcSight Common Event Format (CEF:0).
// Format: CEF:0|Vendor|Product|Version|EventClassId|Name|Severity|Extension
pub fn format_cef(event SiemEvent) string {
	severity_num := match event.severity {
		.info     { "1" }
		.low      { "3" }
		.medium   { "5" }
		.high     { "7" }
		.critical { "10" }
	}
	ext := "src=${event.src_ip} dst=${event.dst_ip} suser=${event.username} msg=${event.message}"
	return "CEF:0|hyperpolymath|v-siem|1.0|${event.event_type}|${event.event_type}|${severity_num}|${ext}"
}

// --- Tests ---

fn test_empty_rule_id_rejected() {
	mut engine := new_siem_engine(SiemConfig{})
	engine.add_rule(CorrelationRule{ rule_id: "", name: "test", pattern: "", window_secs: 300, threshold: 1 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_format_cef_structure() {
	event := SiemEvent{
		event_id:    "e001"
		event_type:  .failed_auth
		source_type: .identity
		timestamp:   1700000000
		severity:    .high
		src_ip:      "10.0.0.1"
		dst_ip:      "10.0.0.2"
		username:    "bob"
		message:     "repeated auth failure"
		raw_log:     ""
	}
	cef := format_cef(event)
	assert cef.starts_with("CEF:0|")
	assert cef.contains("src=10.0.0.1")
	assert cef.contains("suser=bob")
}

fn test_format_cef_severity_mapping() {
	event := SiemEvent{
		event_id: "e002"
		event_type: .data_exfil
		source_type: .endpoint
		timestamp: 0
		severity: .critical
		src_ip: ""
		dst_ip: ""
		username: ""
		message: "large outbound transfer"
		raw_log: ""
	}
	cef := format_cef(event)
	assert cef.contains("|10|")
}

fn test_correlate_negative_window_rejected() {
	mut engine := new_siem_engine(SiemConfig{})
	engine.correlate(-1) or {
		assert err.str().contains("must be positive")
		return
	}
	assert false
}
