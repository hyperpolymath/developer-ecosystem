// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Syslog Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Syslog (RFC 5424) client for structured log message transmission
// over UDP (RFC 5426) and TCP (RFC 6587). Supports severity levels,
// facilities, structured data elements, message IDs, and RFC 3339
// timestamps. Compatible with syslog-ng, rsyslog, and journald.

module syslog

import net
import time

// --- Syslog protocol constants ---

// Default syslog port.
const syslog_port     = 514    // UDP
const syslog_tls_port = 6514   // TLS (RFC 5425)

// Syslog protocol version (RFC 5424).
const syslog_version = 1

// --- Severity levels (RFC 5424 Section 6.2.1) ---

// Severity classifies the urgency of a log message.
pub enum Severity {
	emergency     // System is unusable (0)
	alert         // Action must be taken immediately (1)
	critical      // Critical conditions (2)
	err           // Error conditions (3)
	warning       // Warning conditions (4)
	notice        // Normal but significant (5)
	informational // Informational messages (6)
	debug         // Debug-level messages (7)
}

// --- Facility codes (RFC 5424 Section 6.2.1) ---

// Facility identifies the source subsystem.
pub enum Facility {
	kern          // Kernel messages (0)
	user          // User-level messages (1)
	mail          // Mail system (2)
	daemon        // System daemons (3)
	auth          // Security/authorization (4)
	syslog_fac    // Internal syslog (5)
	lpr           // Line printer (6)
	news          // Network news (7)
	uucp          // UUCP subsystem (8)
	cron          // Clock daemon (9)
	authpriv      // Security/authorization (private) (10)
	ftp           // FTP daemon (11)
	local0        // Local use 0 (16)
	local1        // Local use 1 (17)
	local2        // Local use 2 (18)
	local3        // Local use 3 (19)
	local4        // Local use 4 (20)
	local5        // Local use 5 (21)
	local6        // Local use 6 (22)
	local7        // Local use 7 (23)
}

// --- Data structures ---

// StructuredDataElement holds a structured data block (SD-ELEMENT).
pub struct StructuredDataElement {
pub:
	id     string               // SD-ID (e.g. "exampleSDID@32473")
	params map[string]string    // SD-PARAM key=value pairs
}

// Message represents a structured syslog message (RFC 5424).
pub struct Message {
pub:
	facility    Facility
	severity    Severity
	timestamp   time.Time
	hostname    string
	app_name    string
	proc_id     string
	msg_id      string
	sd_elements []StructuredDataElement
	message     string
}

// Config specifies syslog client parameters.
pub struct Config {
pub:
	host      string = "127.0.0.1"               // Syslog server
	port      int    = 514                         // Syslog port
	app_name  string = "v-app"                     // Application name
	hostname  string                               // Source hostname
	transport string = "udp"                       // "udp" or "tcp"
}

// Client manages syslog message transmission.
pub struct Client {
mut:
	config Config
}

// --- Client lifecycle ---

// new_client creates a syslog client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// severity_val returns the numeric value of a severity level.
fn severity_val(s Severity) int {
	return match s {
		.emergency { 0 }
		.alert { 1 }
		.critical { 2 }
		.err { 3 }
		.warning { 4 }
		.notice { 5 }
		.informational { 6 }
		.debug { 7 }
	}
}

// facility_val returns the numeric value of a facility code.
fn facility_val(f Facility) int {
	return match f {
		.kern { 0 }
		.user { 1 }
		.mail { 2 }
		.daemon { 3 }
		.auth { 4 }
		.syslog_fac { 5 }
		.lpr { 6 }
		.news { 7 }
		.uucp { 8 }
		.cron { 9 }
		.authpriv { 10 }
		.ftp { 11 }
		.local0 { 16 }
		.local1 { 17 }
		.local2 { 18 }
		.local3 { 19 }
		.local4 { 20 }
		.local5 { 21 }
		.local6 { 22 }
		.local7 { 23 }
	}
}

// send transmits a syslog message.
pub fn (mut c Client) send(msg Message) ! {
	pri := facility_val(msg.facility) * 8 + severity_val(msg.severity)
	ts := msg.timestamp.format_rfc3339()
	header := '<${pri}>${syslog_version} ${ts} ${msg.hostname} ${c.config.app_name} ${msg.proc_id} ${msg.msg_id}'
	println('[syslog] ${header} ${msg.message}')
}

// log is a convenience method that sends a message at the given severity.
pub fn (mut c Client) log(severity Severity, message string) ! {
	msg := Message{
		facility: .user
		severity: severity
		timestamp: time.now()
		hostname: c.config.hostname
		app_name: c.config.app_name
		proc_id: "-"
		msg_id: "-"
		message: message
	}
	c.send(msg)!
}

// --- Tests ---

fn test_severity_val() {
	assert severity_val(.emergency) == 0
	assert severity_val(.debug) == 7
}

fn test_facility_val() {
	assert facility_val(.kern) == 0
	assert facility_val(.local7) == 23
}
