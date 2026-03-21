// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Intrusion detection with signature and anomaly-based rule engines Connector
// Author: Jonathan D.A. Jewell
//
// Intrusion detection with signature and anomaly-based rule engines.
// Provides typed client bindings for the proven-ids protocol.

module ids

import os
import time
import net

// --- Detection mode ---

// DetectionMode selects the IDS analysis approach.
pub enum DetectionMode {
	signature    // Pattern matching
	anomaly      // Statistical deviation
	hybrid       // Both methods
}

// --- Alert severity ---

// AlertSeverity classifies detection severity.
pub enum AlertSeverity {
	info
	low
	medium
	high
	critical
}

// --- Data structures ---

// IdsRule defines a single detection rule.
pub struct IdsRule {
pub:
	sid         int          // Signature ID
	name        string
	mode        DetectionMode
	pattern     string       // Match pattern or threshold
	severity    AlertSeverity
	enabled     bool = true
}

// IdsAlert represents a fired detection alert.
pub struct IdsAlert {
pub:
	rule_sid    int
	src_addr    string
	dst_addr    string
	timestamp   i64
	severity    AlertSeverity
	payload_hex string
}

// IdsConfig holds IDS engine parameters.
pub struct IdsConfig {
pub:
	interface_name string = "eth0"
	mode           DetectionMode = .hybrid
	log_path       string = "/var/log/ids"
}

// IdsEngine manages IDS rules and alerts.
pub struct IdsEngine {
mut:
	config  IdsConfig
	rules   []IdsRule
	alerts  []IdsAlert
}

// --- Engine lifecycle ---

// new_ids_engine creates a new IDS engine.
pub fn new_ids_engine(config IdsConfig) &IdsEngine {
	return &IdsEngine{
		config: config
		rules:  []IdsRule{}
		alerts: []IdsAlert{}
	}
}

// add_rule loads a detection rule.
pub fn (mut e IdsEngine) add_rule(rule IdsRule) ! {
	if rule.name.len == 0 {
		return error("rule name must not be empty")
	}
	e.rules << rule
	println("[ids] loaded rule SID:${rule.sid} (${rule.mode}): ${rule.name}")
}

// get_alerts returns alerts above a given severity.
pub fn (e &IdsEngine) get_alerts(min_severity AlertSeverity) []IdsAlert {
	return e.alerts.filter(it.severity == min_severity)
}

// --- Tests ---

fn test_empty_rule_name_rejected() {
	mut engine := new_ids_engine(IdsConfig{})
	engine.add_rule(IdsRule{ sid: 1, name: "", mode: .signature, pattern: "", severity: .high }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
