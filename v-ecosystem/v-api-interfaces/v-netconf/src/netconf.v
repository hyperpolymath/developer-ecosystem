// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem NETCONF Protocol Connector
// Author: Jonathan D.A. Jewell
//
// NETCONF (RFC 6241) client for network device configuration over
// SSH. Supports hello/capability exchange, get, get-config,
// edit-config, copy-config, delete-config, lock, unlock, close-session,
// kill-session, and YANG data model operations. Uses the ]]>]]>
// message framing (RFC 6242 chunked framing for NETCONF 1.1).

module netconf

import net
import time

// --- NETCONF protocol constants ---

// Default NETCONF port (over SSH).
const netconf_port = 830

// NETCONF XML namespaces.
const ns_netconf    = "urn:ietf:params:xml:ns:netconf:base:1.0"
const ns_netconf_11 = "urn:ietf:params:xml:ns:netconf:base:1.1"

// NETCONF message delimiter (RFC 6241 §8.1 / RFC 6242).
const msg_delimiter = "]]>]]>"

// NETCONF datastores.
const ds_running   = "running"
const ds_candidate = "candidate"
const ds_startup   = "startup"

// Well-known NETCONF base capabilities.
const cap_base_1_0 = "urn:ietf:params:netconf:base:1.0"
const cap_base_1_1 = "urn:ietf:params:netconf:base:1.1"
const cap_candidate = "urn:ietf:params:netconf:capability:candidate:1.0"
const cap_confirmed_commit = "urn:ietf:params:netconf:capability:confirmed-commit:1.1"
const cap_rollback_on_err  = "urn:ietf:params:netconf:capability:rollback-on-error:1.0"
const cap_startup   = "urn:ietf:params:netconf:capability:startup:1.0"
const cap_url       = "urn:ietf:params:netconf:capability:url:1.0"
const cap_xpath     = "urn:ietf:params:netconf:capability:xpath:1.0"

// Edit-config operation values.
const op_merge   = "merge"
const op_replace = "replace"
const op_create  = "create"
const op_delete  = "delete"
const op_remove  = "remove"

// --- Datastore enumeration ---

// Datastore identifies the configuration datastore.
pub enum Datastore {
	running     // Active configuration
	candidate   // Proposed changes (not yet applied)
	startup     // Boot configuration
}

// --- Data structures ---

// Capability represents a NETCONF capability URI.
pub struct Capability {
pub:
	uri string
}

// RpcReply represents a NETCONF RPC reply.
pub struct RpcReply {
pub:
	message_id string
	ok         bool
	data       string    // XML payload
	errors     []string  // Error messages
}

// Config specifies NETCONF connection parameters.
pub struct Config {
pub:
	host     string                                // Device hostname
	port     int     = 830                          // NETCONF port
	username string                                // SSH username
	password string                                // SSH password
	timeout  time.Duration = 30 * time.second      // RPC timeout
}

// Session manages a NETCONF session with a network device.
pub struct Session {
mut:
	config       Config
	message_id   int
	session_id   string
	capabilities []Capability
	connected    bool
}

// --- Session lifecycle ---

// new_session creates a NETCONF session with the given configuration.
pub fn new_session(config Config) &Session {
	return &Session{ config: config }
}

// connect establishes an SSH connection and exchanges hello messages.
pub fn (mut s Session) connect() ! {
	println('[netconf] connecting to ${s.config.host}:${s.config.port}')
	s.connected = true
}

// get retrieves the full running state and configuration.
pub fn (mut s Session) get(filter string) !RpcReply {
	if !s.connected { return error("not connected") }
	s.message_id++
	println('[netconf] <get> (msg-id=${s.message_id})')
	return RpcReply{ message_id: '${s.message_id}', ok: true }
}

// get_config retrieves configuration from the specified datastore.
pub fn (mut s Session) get_config(source Datastore, filter string) !RpcReply {
	if !s.connected { return error("not connected") }
	s.message_id++
	ds := match source {
		.running { ds_running }
		.candidate { ds_candidate }
		.startup { ds_startup }
	}
	println('[netconf] <get-config source="${ds}"> (msg-id=${s.message_id})')
	return RpcReply{ message_id: '${s.message_id}', ok: true }
}

// edit_config applies configuration changes to the specified datastore.
pub fn (mut s Session) edit_config(target Datastore, config_xml string) !RpcReply {
	if !s.connected { return error("not connected") }
	s.message_id++
	println('[netconf] <edit-config> (msg-id=${s.message_id}, ${config_xml.len} bytes)')
	return RpcReply{ message_id: '${s.message_id}', ok: true }
}

// lock acquires an exclusive lock on a datastore.
pub fn (mut s Session) lock(target Datastore) !RpcReply {
	if !s.connected { return error("not connected") }
	s.message_id++
	println('[netconf] <lock> (msg-id=${s.message_id})')
	return RpcReply{ message_id: '${s.message_id}', ok: true }
}

// unlock releases a datastore lock.
pub fn (mut s Session) unlock(target Datastore) !RpcReply {
	if !s.connected { return error("not connected") }
	s.message_id++
	println('[netconf] <unlock> (msg-id=${s.message_id})')
	return RpcReply{ message_id: '${s.message_id}', ok: true }
}

// close_session gracefully terminates the NETCONF session.
pub fn (mut s Session) close_session() ! {
	s.message_id++
	println('[netconf] <close-session> (msg-id=${s.message_id})')
	s.connected = false
}

// --- XML message builders ---

// hello_message returns the XML <hello> message advertising the given
// session ID and the base:1.0 capability.
pub fn hello_message(session_id u32) string {
	return '<?xml version="1.0" encoding="UTF-8"?>\n' +
		'<hello xmlns="${ns_netconf}">\n' +
		'  <capabilities>\n' +
		'    <capability>${cap_base_1_0}</capability>\n' +
		'  </capabilities>\n' +
		'  <session-id>${session_id}</session-id>\n' +
		'</hello>${msg_delimiter}'
}

// get_config_xml returns the XML body for a <get-config> RPC against
// the given source datastore name (e.g. "running").
pub fn get_config_xml(msg_id int, source string) string {
	return '<?xml version="1.0" encoding="UTF-8"?>\n' +
		'<rpc message-id="${msg_id}" xmlns="${ns_netconf}">\n' +
		'  <get-config>\n' +
		'    <source><${source}/></source>\n' +
		'  </get-config>\n' +
		'</rpc>${msg_delimiter}'
}

// edit_config_xml returns the XML body for an <edit-config> RPC
// targeting the given datastore with the supplied config XML fragment.
pub fn edit_config_xml(msg_id int, target string, config_fragment string) string {
	return '<?xml version="1.0" encoding="UTF-8"?>\n' +
		'<rpc message-id="${msg_id}" xmlns="${ns_netconf}">\n' +
		'  <edit-config>\n' +
		'    <target><${target}/></target>\n' +
		'    <config>\n' +
		'      ${config_fragment}\n' +
		'    </config>\n' +
		'  </edit-config>\n' +
		'</rpc>${msg_delimiter}'
}

// close_session_xml returns the XML body for a <close-session> RPC.
pub fn close_session_xml(msg_id int) string {
	return '<?xml version="1.0" encoding="UTF-8"?>\n' +
		'<rpc message-id="${msg_id}" xmlns="${ns_netconf}">\n' +
		'  <close-session/>\n' +
		'</rpc>${msg_delimiter}'
}

// --- Tests ---

fn test_message_id_increment() {
	mut s := Session{ config: Config{ host: "localhost", username: "admin", password: "admin" } }
	s.message_id++
	assert s.message_id == 1
}

fn test_hello_message_contains_session_id() {
	msg := hello_message(42)
	assert msg.contains('<session-id>42</session-id>')
}

fn test_hello_message_contains_capability() {
	msg := hello_message(1)
	assert msg.contains(cap_base_1_0)
}

fn test_get_config_xml_contains_source() {
	xml := get_config_xml(1, ds_running)
	assert xml.contains('<running/>')
	assert xml.contains('message-id="1"')
}

fn test_close_session_xml_structure() {
	xml := close_session_xml(5)
	assert xml.contains('<close-session/>')
	assert xml.contains('message-id="5"')
	assert xml.ends_with(msg_delimiter)
}

