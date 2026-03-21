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
}

// --- Engine lifecycle ---

// new_siem_engine creates a new SIEM engine.
pub fn new_siem_engine(config SiemConfig) &SiemEngine {
	return &SiemEngine{
		config: config
		rules:  []CorrelationRule{}
		events: []SecurityEvent{}
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

// --- Tests ---

fn test_empty_rule_id_rejected() {
	mut engine := new_siem_engine(SiemConfig{})
	engine.add_rule(CorrelationRule{ rule_id: "", name: "test", pattern: "", window_secs: 300, threshold: 1 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
