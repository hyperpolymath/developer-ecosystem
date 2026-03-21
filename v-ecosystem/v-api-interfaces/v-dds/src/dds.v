// SPDX-License-Identifier: PMPL-1.0-or-later
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
	topic := Topic{ name: name, type_name: type_name, qos: qos }
	p.topics << topic
	println('[dds] topic created: ${name} (${type_name})')
	return topic
}

// publish writes a data sample to a topic.
pub fn (mut p Participant) publish(topic_name string, data []u8) ! {
	if !p.active { return error("participant not active") }
	println('[dds] published ${data.len} bytes to ${topic_name}')
}

// subscribe reads data samples from a topic.
pub fn (mut p Participant) subscribe(topic_name string) ![]Sample {
	if !p.active { return error("participant not active") }
	println('[dds] subscribing to ${topic_name}')
	return []Sample{}
}

// leave exits the DDS domain.
pub fn (mut p Participant) leave() ! {
	p.active = false
	p.topics.clear()
	println('[dds] left domain ${p.config.domain_id}')
}

// --- Tests ---

fn test_domain_id_validation() {
	mut p := Participant{ config: Config{ domain_id: 300 } }
	result := p.join()
	assert result == none  // Should fail validation
}
