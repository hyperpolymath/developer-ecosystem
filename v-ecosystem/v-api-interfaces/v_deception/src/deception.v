// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Cyber deception connector for honeypots, honeytokens, and decoy services Connector
// Author: Jonathan D.A. Jewell
//
// Cyber deception framework client. Deploys and manages honeypots,
// honeytokens, breadcrumbs, and decoy services. Supports canary tokens
// (DNS, HTTP, email), network honeypots, fake credential stores, and
// alert generation on interaction. Designed for intrusion detection
// through deception-based defence.

module deception

import net
import time
import rand

// --- Decoy type ---

// DecoyType identifies the kind of deception asset.
pub enum DecoyType {
	honeypot       // Network service honeypot
	honeytoken     // Embedded trackable token
	breadcrumb     // Planted credential/path
	canary_dns     // DNS canary token
	canary_http    // HTTP canary token
	canary_email   // Email canary token
	fake_cred      // Fake credential store
}

// --- Alert severity ---

// AlertSeverity grades the importance of a deception interaction.
pub enum AlertSeverity {
	info        // Automated scan / bot
	warning     // Possible reconnaissance
	critical    // Active intrusion attempt
}

// --- Data structures ---

// Decoy represents a deployed deception asset.
pub struct Decoy {
pub:
	id          string
	kind        DecoyType
	name        string
	location    string     // Network address or file path
	created_at  i64
	is_active   bool
}

// InteractionAlert records a detected interaction with a decoy.
pub struct InteractionAlert {
pub:
	decoy_id    string
	source_ip   string
	timestamp   i64
	severity    AlertSeverity
	details     string
}

// DeceptionConfig holds deception framework parameters.
pub struct DeceptionConfig {
pub:
	alert_webhook  string    // Webhook URL for alerts
	log_all        bool = true
	auto_deploy    bool = false
}

// DeceptionEngine manages deception assets.
pub struct DeceptionEngine {
mut:
	config  DeceptionConfig
	decoys  map[string]Decoy
	alerts  []InteractionAlert
}

// --- Engine lifecycle ---

// new_deception_engine creates a new deception engine.
pub fn new_deception_engine(config DeceptionConfig) &DeceptionEngine {
	return &DeceptionEngine{
		config: config
		decoys: map[string]Decoy{}
		alerts: []InteractionAlert{}
	}
}

// deploy_decoy creates and activates a deception asset.
pub fn (mut e DeceptionEngine) deploy_decoy(kind DecoyType, name string, location string) !Decoy {
	if name.len == 0 {
		return error("decoy name must not be empty")
	}
	id := "decoy-${rand.int_in_range(1000, 9999) or { 1000 }}"
	decoy := Decoy{
		id: id
		kind: kind
		name: name
		location: location
		created_at: time.now().unix()
		is_active: true
	}
	e.decoys[id] = decoy
	println("[deception] deployed ${kind} '${name}' at ${location}")
	return decoy
}

// record_interaction logs an interaction with a decoy.
pub fn (mut e DeceptionEngine) record_interaction(decoy_id string, source_ip string, severity AlertSeverity) ! {
	if decoy_id !in e.decoys {
		return error("decoy '${decoy_id}' not found")
	}
	alert := InteractionAlert{
		decoy_id: decoy_id
		source_ip: source_ip
		timestamp: time.now().unix()
		severity: severity
		details: "interaction detected"
	}
	e.alerts << alert
	println("[deception] ALERT: ${severity} from ${source_ip} on ${decoy_id}")
}

// --- Tests ---

fn test_empty_decoy_name_rejected() {
	mut eng := new_deception_engine(DeceptionConfig{})
	eng.deploy_decoy(.honeypot, "", "10.0.0.1") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
