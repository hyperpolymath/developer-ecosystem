// SPDX-License-Identifier: MPL-2.0
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
	fake_credential // Alias for fake_cred with explicit TTL semantics
	tarpit         // TCP tarpit (slow-down attacker)
	canary_token   // Generic canary token
	honeydoc       // Document with embedded callback beacon
	phantom_service // Listening socket mimicking a real service
	decoy_file     // Decoy file with embedded beacon
}

// default_ttl returns the recommended lifetime (seconds) for this decoy type.
// A value of 0 means the asset does not auto-expire and must be removed manually.
pub fn (d DecoyType) default_ttl() i64 {
	return match d {
		.fake_credential  { i64(86400)   } // 24 hours
		.fake_cred        { i64(86400)   } // 24 hours
		.phantom_service  { i64(3600)    } // 1 hour
		.honeydoc         { i64(604800)  } // 7 days
		.canary_token     { i64(2592000) } // 30 days
		.canary_dns       { i64(2592000) } // 30 days
		.canary_http      { i64(2592000) } // 30 days
		.canary_email     { i64(2592000) } // 30 days
		.honeypot         { i64(0)       } // indefinite
		.honeytoken       { i64(2592000) } // 30 days
		.breadcrumb       { i64(86400)   } // 24 hours
		.tarpit           { i64(0)       } // indefinite
		.decoy_file       { i64(604800)  } // 7 days
	}
}

// --- Alert severity ---

// AlertSeverity grades the importance of a deception interaction.
pub enum AlertSeverity {
	info        // Automated scan / bot
	warning     // Possible reconnaissance
	critical    // Active intrusion attempt
}

// --- Data structures ---

// Canarytoken is a trackable token planted in a decoy artefact.
// When an attacker interacts with the artefact the token fires, recording
// the source IP and trigger timestamp.
pub struct Canarytoken {
pub:
	id              string     // Unique token identifier (CT-<label>-<hex>)
	decoy_type      DecoyType  // Category of artefact this token is embedded in
	planted_at_unix i64        // Unix timestamp when the token was deployed
	ttl_secs        i64        // Lifetime in seconds (0 = never auto-expires)
pub mut:
	triggered       bool       // True once the token has fired
	trigger_source  string     // Source IP or identifier of the activating party
	trigger_time    i64        // Unix timestamp of the first trigger event
}

// MovingTargetPolicy defines the rotation schedule and capacity limits for
// the deception engine's active decoy pool.
pub struct MovingTargetPolicy {
pub:
	rotation_interval_secs int           // Seconds between rotation sweeps
	max_decoys             int = 50      // Hard cap on active canarytokens
pub mut:
	active_decoys          []Canarytoken // Currently active canarytokens
}

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

// DeceptionEngine manages deception assets, canarytokens, and alerts.
pub struct DeceptionEngine {
mut:
	config  DeceptionConfig
	decoys  map[string]Decoy
	tokens  map[string]Canarytoken
	alerts  []InteractionAlert
	policy  MovingTargetPolicy
}

// --- Engine lifecycle ---

// new_deception_engine creates a new deception engine.
pub fn new_deception_engine(config DeceptionConfig) &DeceptionEngine {
	return &DeceptionEngine{
		config:  config
		decoys:  map[string]Decoy{}
		tokens:  map[string]Canarytoken{}
		alerts:  []InteractionAlert{}
		policy:  MovingTargetPolicy{
			rotation_interval_secs: 3600
			max_decoys:             50
			active_decoys:          []Canarytoken{}
		}
	}
}

// deploy_canarytoken creates and registers a Canarytoken for the given type and label.
// Returns an error if the engine is at capacity per MovingTargetPolicy.max_decoys.
pub fn (mut e DeceptionEngine) deploy_canarytoken(kind DecoyType, label string) !Canarytoken {
	if label.len < canary_min_label_len {
		return error("canarytoken label must be at least ${canary_min_label_len} character(s)")
	}
	if e.policy.active_decoys.len >= e.policy.max_decoys {
		return error("decoy capacity limit reached: ${e.policy.max_decoys} active decoys")
	}
	id := generate_canary_token(label)
	ttl := kind.default_ttl()
	tok := Canarytoken{
		id:              id
		decoy_type:      kind
		planted_at_unix: time.now().unix()
		ttl_secs:        ttl
		triggered:       false
		trigger_source:  ""
		trigger_time:    0
	}
	e.tokens[id] = tok
	e.policy.active_decoys << tok
	println("[deception] canarytoken deployed id=${id} ttl=${ttl}s")
	return tok
}

// trigger_token marks a canarytoken as triggered and records the source.
// Returns an error if the token ID is unknown.
pub fn (mut e DeceptionEngine) trigger_token(token_id string, source_ip string) ! {
	if token_id !in e.tokens {
		return error("canarytoken '${token_id}' not found")
	}
	mut tok := e.tokens[token_id]
	tok.triggered = true
	tok.trigger_source = source_ip
	tok.trigger_time = time.now().unix()
	e.tokens[token_id] = tok
	for i, t in e.policy.active_decoys {
		if t.id == token_id {
			e.policy.active_decoys[i] = tok
			break
		}
	}
	e.alerts << InteractionAlert{
		decoy_id:  token_id
		source_ip: source_ip
		timestamp: tok.trigger_time
		severity:  .critical
		details:   "canarytoken triggered"
	}
	println("[deception] TRIGGER token=${token_id} source=${source_ip}")
}

// rotate_decoys removes canarytokens whose TTL has elapsed.
// Tokens with ttl_secs == 0 are never removed. Returns count of removed tokens.
pub fn (mut e DeceptionEngine) rotate_decoys() int {
	now := time.now().unix()
	mut removed := 0
	mut remaining := []Canarytoken{}
	for tok in e.policy.active_decoys {
		if tok.ttl_secs > 0 && tok.planted_at_unix + tok.ttl_secs < now {
			e.tokens.delete(tok.id)
			removed++
		} else {
			remaining << tok
		}
	}
	e.policy.active_decoys = remaining
	return removed
}

// active_count returns the number of currently active canarytokens.
pub fn (e &DeceptionEngine) active_count() int {
	return e.policy.active_decoys.len
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

fn test_trigger_records_source() {
	mut eng := new_deception_engine(DeceptionConfig{})
	tok := eng.deploy_canarytoken(.canary_token, "admin") or { panic(err) }
	assert !tok.triggered
	eng.trigger_token(tok.id, "10.0.0.42") or { panic(err) }
	updated := eng.tokens[tok.id]
	assert updated.triggered
	assert updated.trigger_source == "10.0.0.42"
}

fn test_decoy_count_enforced() {
	mut eng := new_deception_engine(DeceptionConfig{})
	eng.policy.max_decoys = 2
	eng.deploy_canarytoken(.fake_cred, "key-1") or { panic(err) }
	eng.deploy_canarytoken(.honeydoc, "doc-1") or { panic(err) }
	eng.deploy_canarytoken(.canary_token, "extra") or {
		assert err.str().contains("capacity limit")
		return
	}
	assert false, "expected capacity limit error"
}

fn test_expired_removal() {
	mut eng := new_deception_engine(DeceptionConfig{})
	past := time.now().unix() - 10
	expired_tok := Canarytoken{
		id:              "CT-old-AABBCC"
		decoy_type:      .fake_cred
		planted_at_unix: past
		ttl_secs:        i64(1)
		triggered:       false
		trigger_source:  ""
		trigger_time:    0
	}
	eng.tokens[expired_tok.id] = expired_tok
	eng.policy.active_decoys << expired_tok
	fresh_tok := Canarytoken{
		id:              "CT-fresh-DDEEFF"
		decoy_type:      .honeydoc
		planted_at_unix: time.now().unix()
		ttl_secs:        i64(86400)
		triggered:       false
		trigger_source:  ""
		trigger_time:    0
	}
	eng.tokens[fresh_tok.id] = fresh_tok
	eng.policy.active_decoys << fresh_tok
	removed := eng.rotate_decoys()
	assert removed == 1
	assert eng.active_count() == 1
}

fn test_fake_credential_default_ttl() {
	assert DecoyType.fake_cred.default_ttl() == i64(86400)
}

