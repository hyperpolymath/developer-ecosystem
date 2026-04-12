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

import time
import rand

// --- Protocol constants ---

// Prefix used for all generated canary token identifiers.
const canary_token_prefix = "CT-"

// Minimum label length for a canary token.
const canary_min_label_len = 1

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
	tarpit         // TCP tarpit (slow-down attacker)
	canary_token   // Generic canary token
	decoy_file     // Decoy file with embedded beacon
}

// --- Alert severity ---

// AlertSeverity grades the importance of a deception interaction.
pub enum AlertSeverity {
	info        // Automated scan / bot
	warning     // Possible reconnaissance
	critical    // Active intrusion attempt
}

// --- Data structures ---

// DecoyConfig specifies deployment parameters for a decoy asset.
pub struct DecoyConfig {
pub:
	label       string    // Human-readable label
	location    string    // Network address or file path
	ttl_secs    int = 0   // Lifetime in seconds (0 = indefinite)
	alert_on_trigger bool = true
}

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

// deploy_decoy_config creates and activates a deception asset from a DecoyConfig.
pub fn (mut e DeceptionEngine) deploy_decoy_config(decoy_type DecoyType, config DecoyConfig) !string {
	if config.label.len == 0 {
		return error("decoy label must not be empty")
	}
	id := "decoy-${rand.int_in_range(10000, 99999) or { 10000 }}"
	decoy := Decoy{
		id:         id
		kind:       decoy_type
		name:       config.label
		location:   config.location
		created_at: time.now().unix()
		is_active:  true
	}
	e.decoys[id] = decoy
	println("[deception] deployed ${decoy_type} '${config.label}' id=${id}")
	return id
}

// check_triggered reports whether a decoy with the given ID has been interacted with.
pub fn (e &DeceptionEngine) check_triggered(decoy_id string) !bool {
	if decoy_id.len == 0 {
		return error("decoy_id must not be empty")
	}
	if decoy_id !in e.decoys {
		return error("decoy '${decoy_id}' not found")
	}
	triggered := e.alerts.any(it.decoy_id == decoy_id)
	return triggered
}

// list_decoys returns the IDs of all deployed decoys.
pub fn (e &DeceptionEngine) list_decoys() ![]string {
	mut ids := []string{}
	for id, _ in e.decoys {
		ids << id
	}
	return ids
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

// --- Canary token helpers ---

// generate_canary_token produces a unique canary token string for the given label.
// Format: CT-<label>-<random_hex>
pub fn generate_canary_token(label string) string {
	if label.len == 0 {
		return "${canary_token_prefix}invalid-000000"
	}
	rand_part := u64(rand.int_in_range(0, 0xFFFFFF) or { 0xABCDEF })
	return "${canary_token_prefix}${label}-${rand_part:06X}"
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

fn test_generate_canary_token_format() {
	token := generate_canary_token("admin-creds")
	assert token.starts_with(canary_token_prefix)
	assert token.contains("admin-creds")
}

fn test_generate_canary_token_empty_label() {
	token := generate_canary_token("")
	// Should not panic; returns sentinel value
	assert token.starts_with(canary_token_prefix)
}

fn test_list_decoys_reflects_deployed() {
	mut eng := new_deception_engine(DeceptionConfig{})
	eng.deploy_decoy(.fake_cred, "aws-keys", "/home/user/.aws/credentials") or { panic(err) }
	eng.deploy_decoy(.honeytoken, "db-pass", "/etc/app/db.conf") or { panic(err) }
	ids := eng.list_decoys() or { panic(err) }
	assert ids.len == 2
}

fn test_deploy_decoy_config_empty_label_rejected() {
	mut eng := new_deception_engine(DeceptionConfig{})
	eng.deploy_decoy_config(.canary_token, DecoyConfig{ label: "", location: "/tmp" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_record_interaction_updates_alerts() {
	mut eng := new_deception_engine(DeceptionConfig{})
	d := eng.deploy_decoy(.honeytoken, "db-pass", "/etc/db.conf") or { panic(err) }
	eng.record_interaction(d.id, "192.168.1.1", .warning) or { panic(err) }
	triggered := eng.check_triggered(d.id) or { panic(err) }
	assert triggered == true
}

fn test_check_triggered_unknown_decoy_errors() {
	eng := new_deception_engine(DeceptionConfig{})
	eng.check_triggered("ghost-id") or {
		assert err.str().contains("not found")
		return
	}
	assert false
}

