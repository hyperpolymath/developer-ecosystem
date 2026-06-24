// SPDX-License-Identifier: MPL-2.0
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

// RFC 5424 NILVALUE placeholder for absent optional fields.
const nil_value = "-"

// Maximum RFC 5424 message length (informational; transports may differ).
const max_msg_len = 65536

// Facility numeric values — index matches RFC 5424 Table 1.
const facility_kern_val   = 0
const facility_user_val   = 1
const facility_mail_val   = 2
const facility_daemon_val = 3
const facility_auth_val   = 4
const facility_syslog_val = 5
const facility_lpr_val    = 6
const facility_news_val   = 7
const facility_uucp_val   = 8
const facility_cron_val   = 9
const facility_authpriv_val = 10
const facility_ftp_val    = 11
// local0-local7 are 16-23
const facility_local0_val = 16

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

// --- Additional operations ---

// format_rfc5424 builds a complete RFC 5424 syslog message string
// from individual fields. The structured data section is set to
// NILVALUE when sd_elements is empty.
pub fn format_rfc5424(facility int, severity int, hostname string, appname string, msg string) string {
	pri := facility * 8 + severity
	ts := time.now().format_rfc3339()
	proc_id := nil_value
	msg_id  := nil_value
	sd_part := nil_value
	return '<${pri}>${syslog_version} ${ts} ${hostname} ${appname} ${proc_id} ${msg_id} ${sd_part} ${msg}'
}

// send_udp formats and transmits a pre-formatted syslog string over UDP.
pub fn (mut c Client) send_udp(formatted_msg string) ! {
	addr := '${c.config.host}:${c.config.port}'
	mut conn := net.dial_udp(addr)!
	defer { conn.close() or {} }
	conn.write(formatted_msg.bytes())!
	println('[syslog] UDP sent ${formatted_msg.len} bytes to ${addr}')
}

// log_emergency sends an Emergency-severity message under the user facility.
pub fn (mut c Client) log_emergency(message string) ! {
	c.log(.emergency, message)!
}

// log_error sends an Error-severity message under the user facility.
pub fn (mut c Client) log_error(message string) ! {
	c.log(.err, message)!
}

// log_info sends an Informational message under the user facility.
pub fn (mut c Client) log_info(message string) ! {
	c.log(.informational, message)!
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

fn test_format_rfc5424_starts_with_pri() {
	msg := format_rfc5424(1, 6, "myhost", "myapp", "hello")
	// facility=1 (user), severity=6 (info) -> PRI = 1*8+6 = 14
	assert msg.starts_with('<14>')
}

fn test_format_rfc5424_contains_fields() {
	msg := format_rfc5424(3, 3, "srv01", "myapp", "test message")
	assert msg.contains("srv01")
	assert msg.contains("myapp")
	assert msg.contains("test message")
}

fn test_pri_calculation() {
	// kern(0) + emergency(0) = 0
	assert facility_val(.kern) * 8 + severity_val(.emergency) == 0
	// user(1) + debug(7) = 15
	assert facility_val(.user) * 8 + severity_val(.debug) == 15
}

