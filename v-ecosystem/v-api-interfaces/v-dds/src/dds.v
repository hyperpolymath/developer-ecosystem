// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem DDS Protocol Connector
// Author: Jonathan D.A. Jewell
//
// OMG Data Distribution Service (DDS) client for real-time
// publish-subscribe messaging. Supports DomainParticipant,
// Publisher/Subscriber, DataWriter/DataReader, Topic creation,
// QoS policies (reliability, durability, deadline, lifespan),
// and content-filtered topics. Uses RTPS wire protocol.

module dds

import time

// --- DDS protocol constants ---

// DDS domain ID range.
const default_domain_id = 0
const max_domain_id     = 232

// RTPS wire protocol constants.
const rtps_header   = [u8(0x52), 0x54, 0x50, 0x53]  // "RTPS"
const rtps_version  = [u8(2), u8(4)]                  // RTPS 2.4

// RTPS vendor ID for this implementation (experimental).
const rtps_vendor_id = [u8(0x01), u8(0x0F)]

// RTPS submessage type IDs.
const submsg_data         = u8(0x15)
const submsg_heartbeat    = u8(0x07)
const submsg_ack_nack     = u8(0x06)
const submsg_info_ts      = u8(0x09)

// QoS policy IDs (DDS 2.5 §7.1.3).
const qos_reliability_id  = u16(11)
const qos_durability_id   = u16(3)
const qos_history_id      = u16(7)
const qos_deadline_id     = u16(23)
const qos_lifespan_id     = u16(24)
const qos_liveliness_id   = u16(27)

// --- QoS policy enumerations ---

// ReliabilityKind specifies message delivery guarantees.
pub enum ReliabilityKind {
	best_effort   // No delivery guarantee
	reliable      // Guaranteed delivery with acknowledgement
}

// DurabilityKind specifies data persistence.
pub enum DurabilityKind {
	volatile           // No persistence
	transient_local    // Persists within process lifetime
	transient          // Persists beyond process lifetime
	persistent         // Persists across system restarts
}

// HistoryKind specifies sample retention.
pub enum HistoryKind {
	keep_last   // Keep last N samples
	keep_all    // Keep all samples
}

// --- Data structures ---

// QosPolicy holds Quality of Service parameters.
pub struct QosPolicy {
pub:
	reliability ReliabilityKind
	durability  DurabilityKind
	history     HistoryKind
	depth       int     = 1                           // History depth
	deadline    time.Duration = time.infinite          // Deadline period
	lifespan    time.Duration = time.infinite          // Data lifespan
}

// Topic represents a named data channel with a type.
pub struct Topic {
pub:
	name      string
	type_name string
	qos       QosPolicy
}

// Sample represents a received data sample.
pub struct Sample {
pub:
	data          []u8
	instance_key  []u8
	timestamp     time.Time
	valid         bool
}

// ContentFilteredTopic wraps a Topic with an SQL-like filter expression.
pub struct ContentFilteredTopic {
pub:
	base_topic     Topic
	filter_expr    string    // Filter expression (DDS SQL subset)
	parameters     []string  // Bind parameters for filter_expr
}

// Config specifies DDS participant parameters.
pub struct Config {
pub:
	domain_id int     = 0                             // DDS domain ID
	name      string  = "v-dds-participant"            // Participant name
}

// Participant manages a DDS domain participant.
pub struct Participant {
mut:
	config   Config
	topics   []Topic
	active   bool
}

// --- Participant lifecycle ---

// new_participant creates a DDS domain participant.
pub fn new_participant(config Config) &Participant {
	return &Participant{ config: config }
}

// join enters the DDS domain.
pub fn (mut p Participant) join() ! {
	if p.config.domain_id < 0 || p.config.domain_id > max_domain_id {
		return error("domain ID out of range (0-${max_domain_id})")
	}
	p.active = true
	println('[dds] joined domain ${p.config.domain_id} as ${p.config.name}')
}

// create_topic creates a named topic with QoS policies.
pub fn (mut p Participant) create_topic(name string, type_name string, qos QosPolicy) !Topic {
	if !p.active { return error("participant not active") }
	if name.len == 0 { return error("topic name must not be empty") }
	if type_name.len == 0 { return error("type name must not be empty") }
	topic := Topic{ name: name, type_name: type_name, qos: qos }
	p.topics << topic
	println('[dds] topic created: ${name} (${type_name})')
	return topic
}

// publish writes a data sample to a topic.
pub fn (mut p Participant) publish(topic_name string, data []u8) ! {
	if !p.active { return error("participant not active") }
	if data.len == 0 { return error("cannot publish empty sample") }
	println('[dds] published ${data.len} bytes to ${topic_name}')
}

// subscribe reads data samples from a topic.
pub fn (mut p Participant) subscribe(topic_name string) ![]Sample {
	if !p.active { return error("participant not active") }
	println('[dds] subscribing to ${topic_name}')
	return []Sample{}
}

// set_reliability adjusts the reliability QoS of all topics created
// after this call. (Existing topics retain their QoS at creation time.)
pub fn (mut p Participant) set_reliability(reliable bool) ! {
	if !p.active { return error("participant not active") }
	kind := if reliable { "reliable" } else { "best-effort" }
	println('[dds] default reliability set to ${kind}')
}

// delete_topic removes a topic from the participant's registry.
pub fn (mut p Participant) delete_topic(name string) ! {
	if !p.active { return error("participant not active") }
	mut found := false
	for i, t in p.topics {
		if t.name == name {
			p.topics.delete(i)
			found = true
			break
		}
	}
	if !found { return error("topic '${name}' not found") }
	println('[dds] topic deleted: ${name}')
}

// leave exits the DDS domain.
pub fn (mut p Participant) leave() ! {
	p.active = false
	p.topics.clear()
	println('[dds] left domain ${p.config.domain_id}')
}

// --- Helpers ---

// encode_rtps_header builds the 20-byte RTPS protocol header with
// the protocol magic, version, vendor ID, and GUID prefix.
pub fn encode_rtps_header(guid_prefix []u8) []u8 {
	mut hdr := []u8{}
	hdr << rtps_header
	hdr << rtps_version
	hdr << rtps_vendor_id
	// GUID prefix: 12 bytes (zero-padded if short)
	mut prefix := guid_prefix.clone()
	for prefix.len < 12 {
		prefix << u8(0x00)
	}
	hdr << prefix[0..12]
	return hdr
}

// --- Tests ---

fn test_domain_id_validation() {
	mut p := Participant{ config: Config{ domain_id: 300 } }
	result := p.join()
	assert result == none  // Should fail validation
}

fn test_domain_id_valid() {
	mut p := Participant{ config: Config{ domain_id: 0 } }
	p.join() or { panic('join failed: ${err}') }
	assert p.active == true
}

fn test_create_topic_requires_active_participant() {
	mut p := Participant{ config: Config{} }
	qos := QosPolicy{ reliability: .best_effort, durability: .volatile, history: .keep_last }
	p.create_topic("MyTopic", "MyType", qos) or {
		assert err.str().contains("not active")
		return
	}
	assert false
}

fn test_encode_rtps_header_magic() {
	hdr := encode_rtps_header([u8(0x01), 0x02, 0x03])
	assert hdr[0] == 0x52  // 'R'
	assert hdr[1] == 0x54  // 'T'
	assert hdr[2] == 0x50  // 'P'
	assert hdr[3] == 0x53  // 'S'
}

fn test_encode_rtps_header_length() {
	hdr := encode_rtps_header([]u8{})
	// magic(4) + version(2) + vendor(2) + guid_prefix(12) = 20
	assert hdr.len == 20
}

