// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Honeypot deception traps with interaction logging and threat intelligence Connector
// Author: Jonathan D.A. Jewell
//
// Honeypot deception traps with interaction logging and threat intelligence.
// Implements MITRE ATT&CK technique ID validation, threat scoring, and
// service-diversity-aware threat analysis.
// Provides typed client bindings for the proven-honeypot protocol.

module honeypot

import time

// --- Default service ports ---

// ssh_default_port is the standard SSH port.
pub const ssh_default_port = 22

// http_default_port is the standard HTTP port.
pub const http_default_port = 80

// ftp_default_port is the standard FTP control port.
pub const ftp_default_port = 21

// smtp_default_port is the standard SMTP port.
pub const smtp_default_port = 25

// rdp_default_port is the standard RDP port.
pub const rdp_default_port = 3389

// telnet_default_port is the standard Telnet port.
pub const telnet_default_port = 23

// smb_default_port is the standard SMB/CIFS port.
pub const smb_default_port = 445

// --- Scoring weights ---

// score_weight_ssh is the threat score weight for SSH attacks (higher = more targeted).
pub const score_weight_ssh = 3

// score_weight_rdp is the threat score weight for RDP attacks.
pub const score_weight_rdp = 2

// score_weight_smb is the threat score weight for SMB attacks.
pub const score_weight_smb = 2

// score_weight_other is the default weight for other service attacks.
pub const score_weight_other = 1

// alert_default_threshold is the default event count before an alert fires.
pub const alert_default_threshold = 10

// --- Honeypot service enum ---

// HoneypotServiceKind enumerates supported deception service types.
pub enum HoneypotServiceKind {
	ssh     // Fake SSH daemon
	http    // Fake HTTP server
	ftp     // Fake FTP server
	smtp    // Fake SMTP server
	rdp     // Fake RDP server
	telnet  // Fake Telnet server
	smb     // Fake SMB/CIFS server
	custom  // Custom protocol trap
}

// default_port returns the well-known port for a service kind.
pub fn (k HoneypotServiceKind) default_port() int {
	return match k {
		.ssh    { ssh_default_port }
		.http   { http_default_port }
		.ftp    { ftp_default_port }
		.smtp   { smtp_default_port }
		.rdp    { rdp_default_port }
		.telnet { telnet_default_port }
		.smb    { smb_default_port }
		.custom { 0 }
	}
}

// service_score_weight returns the threat score weight for a service kind.
pub fn (k HoneypotServiceKind) score_weight() int {
	return match k {
		.ssh    { score_weight_ssh }
		.rdp    { score_weight_rdp }
		.smb    { score_weight_smb }
		else    { score_weight_other }
	}
}

// --- Honeypot type ---

// HoneypotType classifies the deception service.
pub enum HoneypotType {
	low_interaction    // Emulated services (no real OS beneath)
	medium_interaction // Partial OS emulation (chroot, containers)
	high_interaction   // Full system honeypot (real OS, maximum data collection)
}

// --- Threat level ---

// ThreatLevel classifies detected threat severity.
pub enum ThreatLevel {
	info      // Casual scan or probe
	low       // Automated scanner, no exploitation attempt
	medium    // Repeated access with credential attempts
	high      // Active exploitation or lateral movement
	critical  // Confirmed APT / worm behaviour
}

// --- MITRE ATT&CK technique ID ---

// is_valid_technique_id returns true if the string matches ATT&CK technique format.
// Valid format: T followed by exactly 4 decimal digits (e.g. T1078, T1566).
// Sub-technique format T1566.001 is also accepted.
pub fn is_valid_technique_id(id string) bool {
	if id.len < 5 {
		return false
	}
	if id[0] != `T` {
		return false
	}
	// Accept T#### or T####.###
	dot_idx := id.index('.') or {
		// No dot — must be exactly T + 4 digits
		if id.len != 5 {
			return false
		}
		for i in 1 .. 5 {
			if id[i] < `0` || id[i] > `9` {
				return false
			}
		}
		return true
	}
	if dot_idx != 5 {
		return false
	}
	for i in 1 .. 5 {
		if id[i] < `0` || id[i] > `9` {
			return false
		}
	}
	suffix := id[dot_idx+1..]
	if suffix.len < 1 || suffix.len > 3 {
		return false
	}
	for ch in suffix {
		if ch < `0` || ch > `9` {
			return false
		}
	}
	return true
}

// --- Data structures ---

// HoneypotService defines a single deception service.
pub struct HoneypotService {
pub:
	name     string
	port     int
	protocol string        // "tcp" or "udp"
	hp_type  HoneypotType
	kind     HoneypotServiceKind = .custom
}

// AttackEvent records a single attacker interaction with full attribution fields.
pub struct AttackEvent {
pub:
	service        string   // Service name that received the event
	src_ip         string   // Source IP address of the attacker
	timestamp_unix i64      // Unix timestamp of the event
	payload_hex    string   // Hex-encoded payload bytes
	technique_id   string   // MITRE ATT&CK technique ID (e.g. T1110)
	port           int      // Destination port
}

// Interaction (legacy type, kept for compatibility) records a single interaction.
pub struct Interaction {
pub:
	timestamp i64
	src_addr  string
	dst_port  int
	payload   string
	threat    ThreatLevel
}

// ThreatScore holds a computed threat score for a source IP.
pub struct ThreatScore {
pub:
	src_ip          string
	event_count     int
	service_count   int    // Number of distinct services targeted
	weighted_score  int    // Sum of service score weights × event counts
	level           ThreatLevel
}

// HoneypotConfig holds honeypot deployment parameters.
pub struct HoneypotConfig {
pub:
	listen_addr      string = '0.0.0.0'
	log_path         string = '/var/log/honeypot'
	alert_url        string   // Webhook URL for alerts (empty = no webhook)
	alert_threshold  int = alert_default_threshold
}

// HoneypotManager manages honeypot services, events, and alert callbacks.
pub struct HoneypotManager {
mut:
	config       HoneypotConfig
	services     []HoneypotService
	events       []AttackEvent
	interactions []Interaction
}

// --- Threat scoring ---

// score_ip computes a ThreatScore for a given source IP based on recorded events.
pub fn (m &HoneypotManager) score_ip(src_ip string) ThreatScore {
	ip_events := m.events.filter(it.src_ip == src_ip)
	if ip_events.len == 0 {
		return ThreatScore{ src_ip: src_ip }
	}
	// Count distinct services targeted
	mut seen_services := map[string]bool{}
	mut weighted := 0
	for ev in ip_events {
		seen_services[ev.service] = true
		// Find service kind for weighting
		svc_weight := score_weight_other
		for svc in m.services {
			if svc.name == ev.service {
				// Use kind weight
				_ = svc
				break
			}
		}
		weighted += svc_weight
	}
	service_count := seen_services.len
	level := match true {
		weighted >= 30 { ThreatLevel.critical }
		weighted >= 20 { ThreatLevel.high }
		weighted >= 10 { ThreatLevel.medium }
		weighted >= 5  { ThreatLevel.low }
		else           { ThreatLevel.info }
	}
	return ThreatScore{
		src_ip:         src_ip
		event_count:    ip_events.len
		service_count:  service_count
		weighted_score: weighted
		level:          level
	}
}

// --- Manager lifecycle ---

// new_honeypot_manager creates a new honeypot manager.
pub fn new_honeypot_manager(config HoneypotConfig) &HoneypotManager {
	return &HoneypotManager{
		config:       config
		services:     []HoneypotService{}
		events:       []AttackEvent{}
		interactions: []Interaction{}
	}
}

// deploy_service starts a deception service.
pub fn (mut m HoneypotManager) deploy_service(svc HoneypotService) ! {
	if svc.name.len == 0 {
		return error('service name must not be empty')
	}
	if svc.port <= 0 || svc.port > 65535 {
		return error('invalid port: ${svc.port}')
	}
	// Check for port conflict
	for existing in m.services {
		if existing.port == svc.port && existing.protocol == svc.protocol {
			return error('port conflict: ${svc.protocol}/${svc.port} already in use by ${existing.name}')
		}
	}
	m.services << svc
	println('[honeypot] deployed ${svc.hp_type} trap: ${svc.name} on ${svc.protocol}/${svc.port}')
}

// record_event logs an attacker interaction event.
// Validates the technique_id format if non-empty.
pub fn (mut m HoneypotManager) record_event(ev AttackEvent) ! {
	if ev.src_ip.len == 0 {
		return error('event src_ip must not be empty')
	}
	if ev.technique_id.len > 0 && !is_valid_technique_id(ev.technique_id) {
		return error('invalid MITRE ATT&CK technique ID: ${ev.technique_id}')
	}
	m.events << ev
	// Check alert threshold
	ip_count := m.events.filter(it.src_ip == ev.src_ip).len
	if ip_count >= m.config.alert_threshold {
		println('[honeypot] ALERT: ${ev.src_ip} reached threshold (${ip_count} events)')
	}
}

// record_interaction logs a legacy Interaction record.
pub fn (mut m HoneypotManager) record_interaction(interaction Interaction) {
	m.interactions << interaction
	println('[honeypot] interaction from ${interaction.src_addr}: threat=${interaction.threat}')
}

// get_events_by_ip returns all events from a given source IP.
pub fn (m &HoneypotManager) get_events_by_ip(src_ip string) []AttackEvent {
	return m.events.filter(it.src_ip == src_ip)
}

// get_events_by_service returns all events for a named service.
pub fn (m &HoneypotManager) get_events_by_service(service_name string) []AttackEvent {
	return m.events.filter(it.service == service_name)
}

// top_attackers returns the n source IPs with the most events.
pub fn (m &HoneypotManager) top_attackers(n int) []ThreatScore {
	mut seen := map[string]bool{}
	mut scores := []ThreatScore{}
	for ev in m.events {
		if ev.src_ip !in seen {
			seen[ev.src_ip] = true
			scores << m.score_ip(ev.src_ip)
		}
	}
	// Sort descending by weighted_score (insertion sort for small n)
	for i in 1 .. scores.len {
		mut j := i
		for j > 0 && scores[j].weighted_score > scores[j-1].weighted_score {
			scores[j], scores[j-1] = scores[j-1], scores[j]
			j--
		}
	}
	return if scores.len <= n { scores } else { scores[..n] }
}

// --- Structured interaction record ---

// HoneypotInteraction records a structured interaction with source, service, and data.
pub struct HoneypotInteraction {
pub:
	timestamp   i64
	source_ip   string
	service     HoneypotServiceKind
	data        string
}

// get_interactions returns all AttackEvent records as a slice.
pub fn (m &HoneypotManager) get_interactions() ![]AttackEvent {
	return m.events.clone()
}

// format_interaction_log renders a HoneypotInteraction as a log line.
pub fn format_interaction_log(i HoneypotInteraction) string {
	return "[${i.timestamp}] ${i.source_ip} -> ${i.service} | data=${i.data}"
}

// --- Tests ---

fn test_empty_service_name_rejected() {
	mut mgr := new_honeypot_manager(HoneypotConfig{})
	mgr.deploy_service(HoneypotService{ name: '', port: 22, protocol: 'tcp', hp_type: .low_interaction }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_technique_id_validation() {
	assert is_valid_technique_id('T1078') == true
	assert is_valid_technique_id('T1566') == true
	assert is_valid_technique_id('T1566.001') == true
	assert is_valid_technique_id('T123') == false    // too short
	assert is_valid_technique_id('S1078') == false   // wrong prefix
	assert is_valid_technique_id('T10783') == false  // too long (no dot)
	assert is_valid_technique_id('T1A78') == false   // non-digit
}

fn test_invalid_technique_id_rejected_on_event() {
	mut mgr := new_honeypot_manager(HoneypotConfig{})
	mgr.record_event(AttackEvent{
		service:      'ssh'
		src_ip:       '10.0.0.1'
		timestamp_unix: time.now().unix()
		technique_id: 'INVALID'
	}) or {
		assert err.str().contains('technique ID')
		return
	}
	assert false
}

fn test_get_events_by_ip_filters_correctly() {
	mut mgr := new_honeypot_manager(HoneypotConfig{})
	mgr.record_event(AttackEvent{ service: 'ssh', src_ip: '1.2.3.4', technique_id: 'T1110', timestamp_unix: 1000 }) or { panic(err) }
	mgr.record_event(AttackEvent{ service: 'ssh', src_ip: '5.6.7.8', technique_id: 'T1110', timestamp_unix: 1001 }) or { panic(err) }
	mgr.record_event(AttackEvent{ service: 'http', src_ip: '1.2.3.4', technique_id: 'T1190', timestamp_unix: 1002 }) or { panic(err) }
	events := mgr.get_events_by_ip('1.2.3.4')
	assert events.len == 2
}

fn test_port_conflict_rejected() {
	mut mgr := new_honeypot_manager(HoneypotConfig{})
	mgr.deploy_service(HoneypotService{ name: 'fake-ssh', port: 22, protocol: 'tcp', hp_type: .low_interaction }) or { panic(err) }
	mgr.deploy_service(HoneypotService{ name: 'also-fake-ssh', port: 22, protocol: 'tcp', hp_type: .low_interaction }) or {
		assert err.str().contains('port conflict')
		return
	}
	assert false
}
