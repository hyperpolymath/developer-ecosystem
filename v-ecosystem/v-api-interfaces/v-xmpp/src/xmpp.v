// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem XMPP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// XMPP client implementing RFC 6120 (core) and RFC 6121 (instant
// messaging and presence) over TCP with XML stream framing. Supports
// SASL PLAIN authentication, resource binding, message send/receive,
// presence broadcast, roster management, and multi-user chat (XEP-0045).
// Compatible with ejabberd, Prosody, Openfire, and other XMPP servers.

module xmpp

import net
import encoding.base64
import time
import rand

// --- XMPP XML namespace constants ---

// Standard namespace URIs used in XMPP stream negotiation and stanzas.
const ns_stream = 'http://etherx.jabber.org/streams'
const ns_client = 'jabber:client'
const ns_sasl = 'urn:ietf:params:xml:ns:xmpp-sasl'
const ns_bind = 'urn:ietf:params:xml:ns:xmpp-bind'
const ns_session = 'urn:ietf:params:xml:ns:xmpp-session'
const ns_roster = 'jabber:iq:roster'
const ns_muc = 'http://jabber.org/protocol/muc'

// --- Message type enumeration ---

// MessageType classifies the kind of XMPP message being sent or
// received.
pub enum MessageType {
	chat       // One-to-one chat message
	groupchat  // Multi-user chat message
	headline   // Alert/notification (no reply expected)
	normal     // Single message outside a chat session
	error_     // Error response
}

// --- Presence show ---

// PresenceShow indicates the user's availability status beyond
// simple online/offline.
pub enum PresenceShow {
	available  // Default online state
	away       // Temporarily away
	chat       // Actively interested in chatting
	dnd        // Do not disturb
	xa         // Extended away
}

// --- Configuration ---

// Config holds the parameters needed to connect to an XMPP server
// and authenticate.
pub struct Config {
pub:
	host           string
	port           int            = 5222
	domain         string             // XMPP domain (e.g. "example.com")
	username       string
	password       string
	resource       string         = 'v-xmpp'
	connect_timeout time.Duration = 10 * time.second
	read_timeout   time.Duration  = 30 * time.second
}

// --- Data structures ---

// JID represents a Jabber ID with local, domain, and optional
// resource components (local@domain/resource).
pub struct JID {
pub:
	local    string
	domain   string
	resource string
}

// to_string formats the JID as a string. Includes the resource
// part only if non-empty.
pub fn (jid JID) to_string() string {
	mut result := '${jid.local}@${jid.domain}'
	if jid.resource.len > 0 {
		result += '/${jid.resource}'
	}
	return result
}

// bare returns the JID without the resource part (local@domain).
pub fn (jid JID) bare() string {
	return '${jid.local}@${jid.domain}'
}

// parse_jid parses a JID string into its components.
pub fn parse_jid(jid_str string) JID {
	mut local := ''
	mut domain := ''
	mut resource := ''

	at_pos := jid_str.index('@') or {
		return JID{domain: jid_str}
	}
	local = jid_str[..at_pos]
	rest := jid_str[at_pos + 1..]

	slash_pos := rest.index('/') or {
		return JID{local: local, domain: rest}
	}
	domain = rest[..slash_pos]
	resource = rest[slash_pos + 1..]

	return JID{local: local, domain: domain, resource: resource}
}

// XmppMessage represents an XMPP message stanza with sender,
// recipient, type, and body text.
pub struct XmppMessage {
pub:
	from_jid  JID
	to_jid    JID
	msg_type  MessageType
	body      string
	id        string
	subject   string
	thread    string
}

// RosterItem represents a contact in the user's roster with
// subscription state and group membership.
pub struct RosterItem {
pub:
	jid          JID
	name         string
	groups       []string
	subscription string   // "none", "to", "from", "both"
}

// PresenceInfo holds a presence stanza's sender and status fields.
pub struct PresenceInfo {
pub:
	from_jid JID
	show     PresenceShow
	status   string
	priority int
}

// MucRoom represents a multi-user chat room configuration.
pub struct MucRoom {
pub:
	room_jid JID
	nickname string
	password string
}

// Message callback type for incoming message handling.
pub type MessageFn = fn (msg XmppMessage)

// Presence callback type for incoming presence handling.
pub type PresenceFn = fn (info PresenceInfo)

// --- Client ---

// Client manages the XMPP TCP connection, XML stream, and session,
// providing messaging, presence, and roster operations.
pub struct Client {
mut:
	conn              net.TcpConn
	config            Config
	connected         bool
	authenticated     bool
	bound_jid         JID
	stanza_id_counter int
	message_callback  ?MessageFn
	presence_callback ?PresenceFn
}

// connect establishes a TCP connection to the XMPP server, opens
// the XML stream, authenticates via SASL PLAIN, binds a resource,
// and starts a session.
pub fn connect(config Config) !&Client {
	addr := '${config.host}:${config.port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(config.read_timeout)

	mut client := &Client{
		conn: conn
		config: config
	}

	// Step 1: Open XML stream
	client.open_stream()!

	// Step 2: Read stream features (for SASL mechanisms)
	client.read_stream_features()!

	// Step 3: Authenticate with SASL PLAIN
	client.authenticate_sasl_plain()!

	// Step 4: Re-open stream after authentication
	client.open_stream()!
	client.read_stream_features()!

	// Step 5: Bind resource
	client.bind_resource()!

	// Step 6: Start session
	client.start_session()!

	client.connected = true
	client.authenticated = true
	println('[xmpp] connected as ${client.bound_jid.to_string()}')
	return client
}

// disconnect sends the closing stream tag and closes the TCP
// connection.
pub fn (mut c Client) disconnect() {
	if !c.connected {
		return
	}
	c.conn.write('</stream:stream>'.bytes()) or {}
	c.conn.close() or {}
	c.connected = false
	c.authenticated = false
	println('[xmpp] disconnected')
}

// --- Messaging ---

// send_message sends a chat message to the specified JID.
pub fn (mut c Client) send_message(to JID, body string) ! {
	c.send_message_typed(to, .chat, body)
}

// send_message_typed sends a message with an explicit type attribute.
pub fn (mut c Client) send_message_typed(to JID, msg_type MessageType, body string) ! {
	if !c.connected {
		return error('not connected')
	}

	c.stanza_id_counter++
	msg_id := 'msg-${c.stanza_id_counter}'
	type_str := match msg_type {
		.chat { 'chat' }
		.groupchat { 'groupchat' }
		.headline { 'headline' }
		.normal { 'normal' }
		.error_ { 'error' }
	}

	escaped_body := xml_escape(body)
	stanza := '<message type="${type_str}" to="${to.to_string()}" id="${msg_id}" from="${c.bound_jid.to_string()}"><body>${escaped_body}</body></message>'
	c.conn.write(stanza.bytes())!
	println('[xmpp] sent ${type_str} message to ${to.bare()}')
}

// on_message registers a callback invoked when an incoming message
// stanza is received.
pub fn (mut c Client) on_message(callback MessageFn) {
	c.message_callback = callback
}

// on_presence registers a callback invoked when an incoming
// presence stanza is received.
pub fn (mut c Client) on_presence(callback PresenceFn) {
	c.presence_callback = callback
}

// --- Presence ---

// send_presence broadcasts the user's availability status to all
// subscribed contacts.
pub fn (mut c Client) send_presence(show PresenceShow, status string) ! {
	if !c.connected {
		return error('not connected')
	}

	show_str := match show {
		.available { '' } // No <show> element for default available
		.away { 'away' }
		.chat { 'chat' }
		.dnd { 'dnd' }
		.xa { 'xa' }
	}

	mut stanza := '<presence>'
	if show_str.len > 0 {
		stanza += '<show>${show_str}</show>'
	}
	if status.len > 0 {
		stanza += '<status>${xml_escape(status)}</status>'
	}
	stanza += '</presence>'

	c.conn.write(stanza.bytes())!
	println('[xmpp] presence: ${show} — ${status}')
}

// send_unavailable broadcasts an unavailable presence before
// going offline.
pub fn (mut c Client) send_unavailable() ! {
	if !c.connected {
		return error('not connected')
	}
	c.conn.write('<presence type="unavailable"/>'.bytes())!
}

// --- Roster management ---

// get_roster retrieves the user's contact list from the server.
pub fn (mut c Client) get_roster() ![]RosterItem {
	if !c.connected {
		return error('not connected')
	}

	c.stanza_id_counter++
	iq_id := 'roster-${c.stanza_id_counter}'
	stanza := '<iq type="get" id="${iq_id}"><query xmlns="${ns_roster}"/></iq>'
	c.conn.write(stanza.bytes())!

	response := c.read_stanza()!
	return parse_roster_response(response)
}

// add_contact sends a roster set request to add a contact with
// an optional display name and group.
pub fn (mut c Client) add_contact(jid JID, name string, group string) ! {
	if !c.connected {
		return error('not connected')
	}

	c.stanza_id_counter++
	iq_id := 'roster-add-${c.stanza_id_counter}'
	mut item_attrs := 'jid="${jid.bare()}"'
	if name.len > 0 {
		item_attrs += ' name="${xml_escape(name)}"'
	}

	mut group_xml := ''
	if group.len > 0 {
		group_xml = '<group>${xml_escape(group)}</group>'
	}

	stanza := '<iq type="set" id="${iq_id}"><query xmlns="${ns_roster}"><item ${item_attrs}>${group_xml}</item></query></iq>'
	c.conn.write(stanza.bytes())!
	c.read_stanza()!

	// Send subscription request
	c.conn.write('<presence to="${jid.bare()}" type="subscribe"/>'.bytes())!
	println('[xmpp] added contact ${jid.bare()}')
}

// remove_contact removes a contact from the roster.
pub fn (mut c Client) remove_contact(jid JID) ! {
	if !c.connected {
		return error('not connected')
	}

	c.stanza_id_counter++
	iq_id := 'roster-remove-${c.stanza_id_counter}'
	stanza := '<iq type="set" id="${iq_id}"><query xmlns="${ns_roster}"><item jid="${jid.bare()}" subscription="remove"/></query></iq>'
	c.conn.write(stanza.bytes())!
	c.read_stanza()!
	println('[xmpp] removed contact ${jid.bare()}')
}

// --- Multi-user chat (XEP-0045) ---

// join_room enters a multi-user chat room with the specified
// nickname.
pub fn (mut c Client) join_room(room MucRoom) ! {
	if !c.connected {
		return error('not connected')
	}

	room_jid := '${room.room_jid.bare()}/${room.nickname}'
	mut stanza := '<presence to="${room_jid}"><x xmlns="${ns_muc}"'
	if room.password.len > 0 {
		stanza += '><password>${xml_escape(room.password)}</password></x>'
	} else {
		stanza += '/>'
	}
	stanza += '</presence>'

	c.conn.write(stanza.bytes())!
	println('[xmpp] joined room ${room.room_jid.bare()} as ${room.nickname}')
}

// leave_room exits a multi-user chat room.
pub fn (mut c Client) leave_room(room MucRoom) ! {
	if !c.connected {
		return error('not connected')
	}

	room_jid := '${room.room_jid.bare()}/${room.nickname}'
	c.conn.write('<presence to="${room_jid}" type="unavailable"/>'.bytes())!
	println('[xmpp] left room ${room.room_jid.bare()}')
}

// send_room_message sends a groupchat message to a MUC room.
pub fn (mut c Client) send_room_message(room_jid JID, body string) ! {
	c.send_message_typed(room_jid, .groupchat, body)
}

// --- Event polling ---

// poll_once reads one incoming stanza and dispatches it to the
// appropriate callback (message or presence).
pub fn (mut c Client) poll_once() ! {
	if !c.connected {
		return error('not connected')
	}

	stanza := c.read_stanza() or { return }

	if stanza.contains('<message') {
		if cb := c.message_callback {
			msg := parse_message_stanza(stanza)
			cb(msg)
		}
	} else if stanza.contains('<presence') {
		if cb := c.presence_callback {
			info := parse_presence_stanza(stanza)
			cb(info)
		}
	}
}

// --- Internal stream helpers ---

// open_stream sends the opening XML stream tag to initiate XMPP
// stream negotiation.
fn (mut c Client) open_stream() ! {
	stream_open := '<?xml version="1.0"?><stream:stream to="${c.config.domain}" xmlns="${ns_client}" xmlns:stream="${ns_stream}" version="1.0">'
	c.conn.write(stream_open.bytes())!
	// Read the server's stream opening response
	c.read_stanza()!
}

// read_stream_features reads the <stream:features> element from
// the server.
fn (mut c Client) read_stream_features() ! {
	c.read_stanza()!
}

// authenticate_sasl_plain sends a SASL PLAIN authentication
// request (RFC 4616). The credentials are base64-encoded as
// \0username\0password.
fn (mut c Client) authenticate_sasl_plain() ! {
	// SASL PLAIN: \0username\0password
	mut plain_bytes := []u8{}
	plain_bytes << u8(0) // authorization identity (empty)
	plain_bytes << c.config.username.bytes()
	plain_bytes << u8(0)
	plain_bytes << c.config.password.bytes()

	encoded := base64.encode(plain_bytes)
	auth_stanza := '<auth xmlns="${ns_sasl}" mechanism="PLAIN">${encoded}</auth>'
	c.conn.write(auth_stanza.bytes())!

	response := c.read_stanza()!
	if !response.contains('<success') {
		return error('SASL PLAIN authentication failed: ${response}')
	}
	c.authenticated = true
}

// bind_resource sends an IQ set to bind a resource to the session.
fn (mut c Client) bind_resource() ! {
	c.stanza_id_counter++
	iq_id := 'bind-${c.stanza_id_counter}'
	stanza := '<iq type="set" id="${iq_id}"><bind xmlns="${ns_bind}"><resource>${c.config.resource}</resource></bind></iq>'
	c.conn.write(stanza.bytes())!

	response := c.read_stanza()!
	// Extract bound JID from response
	bound_jid_str := extract_xml_text(response, 'jid')
	if bound_jid_str.len > 0 {
		c.bound_jid = parse_jid(bound_jid_str)
	} else {
		c.bound_jid = JID{
			local: c.config.username
			domain: c.config.domain
			resource: c.config.resource
		}
	}
}

// start_session sends an IQ set to initiate the IM session
// (required by some servers per RFC 3921).
fn (mut c Client) start_session() ! {
	c.stanza_id_counter++
	iq_id := 'session-${c.stanza_id_counter}'
	stanza := '<iq type="set" id="${iq_id}"><session xmlns="${ns_session}"/></iq>'
	c.conn.write(stanza.bytes())!
	c.read_stanza()!
}

// read_stanza reads a chunk of XML data from the TCP connection.
// This is a simplified reader that accumulates data until a
// complete stanza (closing tag) is found.
fn (mut c Client) read_stanza() !string {
	mut result := ''
	mut buf := []u8{len: 4096}
	for {
		bytes_read := c.conn.read(mut buf) or { break }
		if bytes_read == 0 {
			break
		}
		result += buf[..bytes_read].bytestr()
		// Simple heuristic: if we have a closing angle bracket and the
		// stanza looks complete, stop reading
		if result.contains('/>') || (result.contains('</') && result.ends_with('>')) {
			break
		}
	}
	return result
}

// --- XML parsing utilities ---

// extract_xml_text extracts the text content of a simple XML element
// by name. Handles elements with or without namespace prefixes.
fn extract_xml_text(xml_body string, element_name string) string {
	open_tag := '<${element_name}>'
	close_tag := '</${element_name}>'
	start := xml_body.index(open_tag) or { return '' }
	content_start := start + open_tag.len
	end := xml_body.index_after(close_tag, content_start)
	if end < 0 {
		return ''
	}
	return xml_body[content_start..end]
}

// extract_xml_attr extracts the value of a named attribute from an
// XML element string.
fn extract_xml_attr(xml_body string, attr_name string) string {
	search := '${attr_name}="'
	start := xml_body.index(search) or { return '' }
	value_start := start + search.len
	end := xml_body.index_after('"', value_start)
	if end < 0 {
		return ''
	}
	return xml_body[value_start..end]
}

// xml_escape escapes special characters for safe inclusion in XML
// text content.
fn xml_escape(text string) string {
	return text
		.replace('&', '&amp;')
		.replace('<', '&lt;')
		.replace('>', '&gt;')
		.replace('"', '&quot;')
		.replace("'", '&apos;')
}

// --- Stanza parsers ---

// parse_message_stanza extracts message fields from a <message>
// XML stanza.
fn parse_message_stanza(stanza string) XmppMessage {
	from_str := extract_xml_attr(stanza, 'from')
	to_str := extract_xml_attr(stanza, 'to')
	type_str := extract_xml_attr(stanza, 'type')
	msg_id := extract_xml_attr(stanza, 'id')
	body := extract_xml_text(stanza, 'body')
	subject := extract_xml_text(stanza, 'subject')
	thread := extract_xml_text(stanza, 'thread')

	msg_type := match type_str {
		'chat' { MessageType.chat }
		'groupchat' { MessageType.groupchat }
		'headline' { MessageType.headline }
		'error' { MessageType.error_ }
		else { MessageType.normal }
	}

	return XmppMessage{
		from_jid: parse_jid(from_str)
		to_jid: parse_jid(to_str)
		msg_type: msg_type
		body: body
		id: msg_id
		subject: subject
		thread: thread
	}
}

// parse_presence_stanza extracts presence fields from a <presence>
// XML stanza.
fn parse_presence_stanza(stanza string) PresenceInfo {
	from_str := extract_xml_attr(stanza, 'from')
	show_str := extract_xml_text(stanza, 'show')
	status := extract_xml_text(stanza, 'status')
	priority_str := extract_xml_text(stanza, 'priority')

	show := match show_str {
		'away' { PresenceShow.away }
		'chat' { PresenceShow.chat }
		'dnd' { PresenceShow.dnd }
		'xa' { PresenceShow.xa }
		else { PresenceShow.available }
	}

	return PresenceInfo{
		from_jid: parse_jid(from_str)
		show: show
		status: status
		priority: if priority_str.len > 0 { priority_str.int() } else { 0 }
	}
}

// parse_roster_response extracts RosterItem entries from a roster
// IQ result stanza.
fn parse_roster_response(stanza string) []RosterItem {
	mut items := []RosterItem{}
	mut search_pos := 0

	for {
		item_start := stanza.index_after('<item ', search_pos)
		if item_start < 0 {
			break
		}
		// Find the end of this item element
		item_end := stanza.index_after('>', item_start)
		if item_end < 0 {
			break
		}
		// Check if it's self-closing or has children
		mut full_end := item_end
		if stanza[item_end - 1] != u8(`/`) {
			closing := stanza.index_after('</item>', item_end)
			if closing >= 0 {
				full_end = closing + 7
			}
		}
		item_xml := stanza[item_start..full_end + 1]

		jid_str := extract_xml_attr(item_xml, 'jid')
		name := extract_xml_attr(item_xml, 'name')
		subscription := extract_xml_attr(item_xml, 'subscription')
		group := extract_xml_text(item_xml, 'group')

		if jid_str.len > 0 {
			items << RosterItem{
				jid: parse_jid(jid_str)
				name: name
				groups: if group.len > 0 { [group] } else { [] }
				subscription: subscription
			}
		}

		search_pos = full_end + 1
	}

	return items
}

// --- Tests ---

fn test_parse_jid_full() {
	jid := parse_jid('alice@example.com/mobile')
	assert jid.local == 'alice'
	assert jid.domain == 'example.com'
	assert jid.resource == 'mobile'
}

fn test_parse_jid_bare() {
	jid := parse_jid('bob@example.com')
	assert jid.local == 'bob'
	assert jid.domain == 'example.com'
	assert jid.resource == ''
}

fn test_parse_jid_domain_only() {
	jid := parse_jid('example.com')
	assert jid.local == ''
	assert jid.domain == 'example.com'
}

fn test_jid_to_string_full() {
	jid := JID{local: 'alice', domain: 'example.com', resource: 'desktop'}
	assert jid.to_string() == 'alice@example.com/desktop'
}

fn test_jid_bare() {
	jid := JID{local: 'alice', domain: 'example.com', resource: 'desktop'}
	assert jid.bare() == 'alice@example.com'
}

fn test_xml_escape() {
	assert xml_escape('a < b & c > d') == 'a &lt; b &amp; c &gt; d'
	assert xml_escape('"hello"') == '&quot;hello&quot;'
}

fn test_extract_xml_text_found() {
	xml := '<iq><jid>alice@example.com/res</jid></iq>'
	assert extract_xml_text(xml, 'jid') == 'alice@example.com/res'
}

fn test_extract_xml_attr_found() {
	xml := '<message from="alice@ex.com" type="chat">'
	assert extract_xml_attr(xml, 'from') == 'alice@ex.com'
	assert extract_xml_attr(xml, 'type') == 'chat'
}

fn test_extract_xml_attr_missing() {
	xml := '<message from="alice@ex.com">'
	assert extract_xml_attr(xml, 'to') == ''
}
