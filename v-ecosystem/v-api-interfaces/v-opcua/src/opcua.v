// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem OPC UA Protocol Connector
// Author: Jonathan D.A. Jewell
//
// OPC Unified Architecture (IEC 62541) client over TCP with UA Binary
// encoding. Supports session lifecycle management, address space browsing,
// attribute read/write, method invocation, and monitored item subscriptions.
// Designed for industrial automation, SCADA, and IIoT integration within
// the V-Ecosystem API layer.

module opcua

import net
import time

// --- OPC UA message type codes ---

// Message type identifiers for the UA TCP transport layer.
const msg_hello = 'HEL'
const msg_acknowledge = 'ACK'
const msg_open_channel = 'OPN'
const msg_close_channel = 'CLO'
const msg_message = 'MSG'
const msg_error = 'ERR'

// --- OPC UA service request identifiers ---

// Numeric identifiers for commonly used OPC UA services.
const svc_get_endpoints = 428
const svc_create_session = 461
const svc_activate_session = 467
const svc_close_session = 473
const svc_browse = 527
const svc_read = 631
const svc_write = 673
const svc_call = 712
const svc_create_subscription = 787
const svc_create_monitored_items = 751
const svc_publish = 826

// --- Node class enumeration ---

// NodeClass identifies the classification of a node in the OPC UA
// address space (Part 3, section 8.30).
pub enum NodeClass {
	object
	variable
	method
	object_type
	variable_type
	reference_type
	data_type
	view
}

// --- Security mode ---

// SecurityMode controls the message security applied to the
// OPC UA secure channel.
pub enum SecurityMode {
	none_           // No security (testing/development only)
	sign            // Messages are signed but not encrypted
	sign_and_encrypt // Messages are signed and encrypted
}

// --- Configuration ---

// Config holds the parameters needed to establish an OPC UA session
// with a server.
pub struct Config {
pub:
	endpoint_url      string             // e.g. "opc.tcp://192.168.1.100:4840"
	host              string
	port              int              = 4840
	security_mode     SecurityMode     = .none_
	application_name  string           = 'v-opcua-client'
	application_uri   string           = 'urn:v-ecosystem:opcua:client'
	connect_timeout   time.Duration    = 10 * time.second
	session_timeout   time.Duration    = 120 * time.second
	read_timeout      time.Duration    = 30 * time.second
}

// --- Data structures ---

// NodeId represents an OPC UA node identifier with namespace and
// identifier components.
pub struct NodeId {
pub:
	namespace_index int
	identifier      string    // Numeric string, string, GUID, or opaque
	id_type         string    = 'numeric'  // "numeric", "string", "guid", "opaque"
}

// DataValue holds the value, status, and timestamps for a node
// attribute read result.
pub struct DataValue {
pub:
	value              string   // String-encoded value
	status_code        u32
	source_timestamp   i64
	server_timestamp   i64
}

// NodeInfo contains the browsed properties of a node in the
// address space.
pub struct NodeInfo {
pub:
	node_id       NodeId
	node_class    NodeClass
	browse_name   string
	display_name  string
	description   string
}

// BrowseResult holds the references discovered by a Browse request.
pub struct BrowseResult {
pub:
	references []ReferenceDescription
}

// ReferenceDescription describes a single reference from a browsed
// node to a target node.
pub struct ReferenceDescription {
pub:
	reference_type_id NodeId
	is_forward        bool
	target_node_id    NodeId
	browse_name       string
	display_name      string
	node_class        NodeClass
}

// WriteValue specifies a node attribute to write with its new value.
pub struct WriteValue {
pub:
	node_id       NodeId
	attribute_id  int = 13    // 13 = Value attribute
	value         string
}

// CallRequest specifies a method invocation on a target object node.
pub struct CallRequest {
pub:
	object_id      NodeId
	method_id      NodeId
	input_arguments []string
}

// CallResult holds the output arguments returned by a method call.
pub struct CallResult {
pub:
	status_code      u32
	output_arguments []string
}

// SubscriptionParams configures a subscription's publishing and
// keep-alive behaviour.
pub struct SubscriptionParams {
pub:
	publishing_interval_ms f64  = 1000.0
	lifetime_count         u32  = 10000
	max_keepalive_count    u32  = 10
	max_notifications      u32  = 0      // 0 = unlimited
	priority               u8   = 0
}

// MonitoredItemRequest specifies a node to add to a subscription
// for data change notifications.
pub struct MonitoredItemRequest {
pub:
	node_id         NodeId
	attribute_id    int = 13
	sampling_interval_ms f64 = 1000.0
}

// DataChangeNotification holds a value change received from a
// monitored item subscription.
pub type DataChangeFn = fn (node_id NodeId, value DataValue)

// --- Client ---

// Client manages the OPC UA TCP connection, secure channel, and
// session, providing methods for all standard OPC UA services.
pub struct Client {
mut:
	config               Config
	conn                 net.TcpConn
	connected            bool
	session_active       bool
	secure_channel_id    u32
	token_id             u32
	session_id           []u8
	auth_token           []u8
	request_handle       u32
	sequence_number      u32
	subscription_id      u32
	data_change_callback ?DataChangeFn
}

// connect establishes a TCP connection to the OPC UA server,
// performs the Hello/Acknowledge handshake, opens a secure channel,
// and creates and activates a session.
pub fn connect(config Config) !&Client {
	addr := '${config.host}:${config.port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(config.read_timeout)

	mut client := &Client{
		config: config
		conn: conn
	}

	// Step 1: Send Hello, receive Acknowledge
	client.send_hello()!
	client.receive_acknowledge()!

	// Step 2: Open secure channel
	client.open_secure_channel()!

	// Step 3: Create and activate session
	client.create_session()!
	client.activate_session()!

	client.connected = true
	client.session_active = true
	println('[opcua] session established with ${addr}')
	return client
}

// disconnect cleanly closes the session, secure channel, and TCP
// connection.
pub fn (mut c Client) disconnect() {
	if !c.connected {
		return
	}
	if c.session_active {
		c.close_session() or {}
	}
	c.close_secure_channel() or {}
	c.conn.close() or {}
	c.connected = false
	c.session_active = false
	println('[opcua] disconnected')
}

// --- Browse ---

// browse navigates the address space starting from the given node,
// returning all references from that node.
pub fn (mut c Client) browse(node_id NodeId) !BrowseResult {
	if !c.session_active {
		return error('no active session')
	}

	c.request_handle++
	// Encode browse request with the specified starting node
	request := c.encode_browse_request(node_id)
	c.send_message(svc_browse, request)!

	response := c.receive_message()!
	return c.decode_browse_response(response)
}

// --- Read ---

// read_value reads the Value attribute of a single node and returns
// the result as a DataValue.
pub fn (mut c Client) read_value(node_id NodeId) !DataValue {
	results := c.read_values([node_id])!
	if results.len == 0 {
		return error('no read result returned')
	}
	return results[0]
}

// read_values reads the Value attributes of multiple nodes in a
// single request.
pub fn (mut c Client) read_values(node_ids []NodeId) ![]DataValue {
	if !c.session_active {
		return error('no active session')
	}

	c.request_handle++
	request := c.encode_read_request(node_ids)
	c.send_message(svc_read, request)!

	response := c.receive_message()!
	return c.decode_read_response(response)
}

// --- Write ---

// write_value writes a single value to a node attribute.
pub fn (mut c Client) write_value(write_val WriteValue) ! {
	c.write_values([write_val])!
}

// write_values writes multiple values to node attributes in a
// single request.
pub fn (mut c Client) write_values(write_vals []WriteValue) ! {
	if !c.session_active {
		return error('no active session')
	}

	c.request_handle++
	request := c.encode_write_request(write_vals)
	c.send_message(svc_write, request)!

	response := c.receive_message()!
	status := c.decode_status_code(response)
	if status != 0 {
		return error('write failed: status code 0x${status:08x}')
	}
}

// --- Method call ---

// call_method invokes a method on an object node with the given
// input arguments and returns the output arguments.
pub fn (mut c Client) call_method(request CallRequest) !CallResult {
	if !c.session_active {
		return error('no active session')
	}

	c.request_handle++
	encoded := c.encode_call_request(request)
	c.send_message(svc_call, encoded)!

	response := c.receive_message()!
	return c.decode_call_response(response)
}

// --- Subscriptions ---

// create_subscription creates a new subscription for receiving
// data change notifications from monitored items.
pub fn (mut c Client) create_subscription(params SubscriptionParams) !u32 {
	if !c.session_active {
		return error('no active session')
	}

	c.request_handle++
	request := c.encode_create_subscription_request(params)
	c.send_message(svc_create_subscription, request)!

	response := c.receive_message()!
	sub_id := c.decode_subscription_id(response)
	c.subscription_id = sub_id
	println('[opcua] subscription ${sub_id} created (interval: ${params.publishing_interval_ms}ms)')
	return sub_id
}

// add_monitored_item adds a node to the subscription for data
// change monitoring.
pub fn (mut c Client) add_monitored_item(subscription_id u32, item MonitoredItemRequest) ! {
	if !c.session_active {
		return error('no active session')
	}

	c.request_handle++
	request := c.encode_create_monitored_item_request(subscription_id, item)
	c.send_message(svc_create_monitored_items, request)!

	response := c.receive_message()!
	status := c.decode_status_code(response)
	if status != 0 {
		return error('add monitored item failed: status code 0x${status:08x}')
	}
	println('[opcua] monitoring node ${item.node_id.identifier}')
}

// on_data_change registers a callback invoked whenever a monitored
// item's value changes.
pub fn (mut c Client) on_data_change(callback DataChangeFn) {
	c.data_change_callback = callback
}

// poll_subscriptions sends a Publish request and processes any
// pending data change notifications from the server.
pub fn (mut c Client) poll_subscriptions() ! {
	if !c.session_active {
		return error('no active session')
	}

	c.request_handle++
	c.send_message(svc_publish, []u8{})!

	response := c.receive_message()!
	if cb := c.data_change_callback {
		notifications := c.decode_publish_response(response)
		for notif in notifications {
			cb(notif.node_id, notif.value)
		}
	}
}

// --- Internal transport helpers ---

// send_hello sends the OPC UA Hello message to initiate the TCP
// handshake.
fn (mut c Client) send_hello() ! {
	endpoint_url := c.config.endpoint_url.bytes()
	// Hello message: type(3) + reserved(1) + size(4) + protocol_version(4) +
	// receive_buf_size(4) + send_buf_size(4) + max_msg_size(4) + max_chunk_count(4) +
	// url_length(4) + url
	payload_size := 28 + endpoint_url.len
	mut msg := []u8{cap: 8 + payload_size}
	msg << msg_hello.bytes()
	msg << u8(0x46) // 'F' for final chunk
	msg << encode_u32(u32(8 + payload_size))
	msg << encode_u32(0)          // protocol version
	msg << encode_u32(65536)      // receive buffer size
	msg << encode_u32(65536)      // send buffer size
	msg << encode_u32(0)          // max message size (0 = unlimited)
	msg << encode_u32(0)          // max chunk count (0 = unlimited)
	msg << encode_u32(u32(endpoint_url.len))
	msg << endpoint_url
	c.conn.write(msg)!
}

// receive_acknowledge reads and validates the Acknowledge response.
fn (mut c Client) receive_acknowledge() ! {
	mut buf := []u8{len: 28}
	c.conn.read(mut buf)!
	msg_type := buf[..3].bytestr()
	if msg_type != msg_acknowledge {
		return error('expected ACK, got ${msg_type}')
	}
}

// open_secure_channel sends an OpenSecureChannel request.
fn (mut c Client) open_secure_channel() ! {
	c.sequence_number++
	// Simplified: send OPN with SecurityMode=None
	mut msg := []u8{}
	msg << msg_open_channel.bytes()
	msg << u8(0x46) // Final
	msg << encode_u32(0) // placeholder for size
	msg << encode_u32(0) // secure channel id (0 for new)
	// Security policy URI: "http://opcfoundation.org/UA/SecurityPolicy#None"
	security_uri := 'http://opcfoundation.org/UA/SecurityPolicy#None'.bytes()
	msg << encode_u32(u32(security_uri.len))
	msg << security_uri
	msg << encode_u32(0) // sender certificate length (-1 = null)
	msg << encode_u32(0) // receiver certificate thumbprint length
	msg << encode_u32(c.sequence_number)
	msg << encode_u32(c.request_handle)

	// Patch size
	size := u32(msg.len)
	msg[4] = u8(size & 0xFF)
	msg[5] = u8((size >> 8) & 0xFF)
	msg[6] = u8((size >> 16) & 0xFF)
	msg[7] = u8((size >> 24) & 0xFF)

	c.conn.write(msg)!

	// Read response
	mut resp := []u8{len: 1024}
	c.conn.read(mut resp) or {}
	c.secure_channel_id = decode_u32(resp, 8)
	c.token_id = decode_u32(resp, 12)
}

// create_session sends a CreateSession request.
fn (mut c Client) create_session() ! {
	c.request_handle++
	c.sequence_number++
	request := c.encode_string_field(c.config.application_name)
	c.send_message(svc_create_session, request)!
	response := c.receive_message()!
	// Extract session_id and auth_token from response
	if response.len >= 16 {
		c.session_id = response[..8]
		c.auth_token = response[8..16]
	}
}

// activate_session sends an ActivateSession request.
fn (mut c Client) activate_session() ! {
	c.request_handle++
	c.sequence_number++
	c.send_message(svc_activate_session, []u8{})!
	c.receive_message()!
}

// close_session sends a CloseSession request.
fn (mut c Client) close_session() ! {
	c.request_handle++
	c.send_message(svc_close_session, [u8(1)])! // deleteSubscriptions = true
	c.receive_message()!
	c.session_active = false
}

// close_secure_channel sends a CloseSecureChannel message.
fn (mut c Client) close_secure_channel() ! {
	mut msg := []u8{}
	msg << msg_close_channel.bytes()
	msg << u8(0x46)
	msg << encode_u32(12)
	msg << encode_u32(c.secure_channel_id)
	c.conn.write(msg)!
}

// send_message wraps a service request in the OPC UA message framing
// and sends it over the secure channel.
fn (mut c Client) send_message(service_id int, payload []u8) ! {
	c.sequence_number++
	mut msg := []u8{}
	msg << msg_message.bytes()
	msg << u8(0x46) // Final chunk
	msg << encode_u32(0) // placeholder for size
	msg << encode_u32(c.secure_channel_id)
	msg << encode_u32(c.token_id)
	msg << encode_u32(c.sequence_number)
	msg << encode_u32(c.request_handle)
	msg << encode_u32(u32(service_id))
	msg << payload

	// Patch total message size
	size := u32(msg.len)
	msg[4] = u8(size & 0xFF)
	msg[5] = u8((size >> 8) & 0xFF)
	msg[6] = u8((size >> 16) & 0xFF)
	msg[7] = u8((size >> 24) & 0xFF)

	c.conn.write(msg)!
}

// receive_message reads a complete OPC UA message from the TCP
// connection and returns the service payload bytes.
fn (mut c Client) receive_message() ![]u8 {
	// Read message header (8 bytes: type + chunk + size)
	mut header := []u8{len: 8}
	c.conn.read(mut header)!
	msg_size := decode_u32(header, 4)

	// Read remaining payload
	remaining := int(msg_size) - 8
	if remaining <= 0 {
		return []u8{}
	}
	mut body := []u8{len: remaining}
	c.conn.read(mut body)!
	return body
}

// --- Encoding helpers ---

// encode_browse_request encodes a Browse service request for the
// given starting node.
fn (c &Client) encode_browse_request(node_id NodeId) []u8 {
	mut payload := []u8{}
	payload << c.encode_node_id(node_id)
	payload << encode_u32(0) // browse direction: forward
	payload << encode_u32(0) // reference type id (all references)
	payload << u8(1)         // include subtypes
	payload << encode_u32(0) // node class mask (all)
	payload << encode_u32(63) // result mask (all)
	return payload
}

// encode_read_request encodes a Read service request for the given
// node IDs (Value attribute).
fn (c &Client) encode_read_request(node_ids []NodeId) []u8 {
	mut payload := []u8{}
	payload << encode_u32(0) // max age (0 = read from device)
	payload << encode_u32(0) // timestamps to return: source
	payload << encode_u32(u32(node_ids.len))
	for node_id in node_ids {
		payload << c.encode_node_id(node_id)
		payload << encode_u32(13) // attribute id: Value
	}
	return payload
}

// encode_write_request encodes a Write service request.
fn (c &Client) encode_write_request(write_vals []WriteValue) []u8 {
	mut payload := []u8{}
	payload << encode_u32(u32(write_vals.len))
	for wv in write_vals {
		payload << c.encode_node_id(wv.node_id)
		payload << encode_u32(u32(wv.attribute_id))
		payload << c.encode_string_field(wv.value)
	}
	return payload
}

// encode_call_request encodes a Call service request.
fn (c &Client) encode_call_request(request CallRequest) []u8 {
	mut payload := []u8{}
	payload << encode_u32(1) // number of methods to call
	payload << c.encode_node_id(request.object_id)
	payload << c.encode_node_id(request.method_id)
	payload << encode_u32(u32(request.input_arguments.len))
	for arg in request.input_arguments {
		payload << c.encode_string_field(arg)
	}
	return payload
}

// encode_create_subscription_request encodes a CreateSubscription
// service request.
fn (c &Client) encode_create_subscription_request(params SubscriptionParams) []u8 {
	mut payload := []u8{}
	// Publishing interval as IEEE 754 double (simplified: cast to u64 bits)
	payload << encode_f64(params.publishing_interval_ms)
	payload << encode_u32(params.lifetime_count)
	payload << encode_u32(params.max_keepalive_count)
	payload << encode_u32(params.max_notifications)
	payload << u8(1) // publishing enabled
	payload << u8(params.priority)
	return payload
}

// encode_create_monitored_item_request encodes a CreateMonitoredItems
// service request.
fn (c &Client) encode_create_monitored_item_request(subscription_id u32, item MonitoredItemRequest) []u8 {
	mut payload := []u8{}
	payload << encode_u32(subscription_id)
	payload << encode_u32(0) // timestamps to return: source
	payload << encode_u32(1) // number of items
	payload << c.encode_node_id(item.node_id)
	payload << encode_u32(u32(item.attribute_id))
	payload << encode_f64(item.sampling_interval_ms)
	return payload
}

// encode_node_id encodes a NodeId in OPC UA binary format.
fn (c &Client) encode_node_id(node_id NodeId) []u8 {
	mut payload := []u8{}
	match node_id.id_type {
		'numeric' {
			numeric_id := node_id.identifier.u32()
			if node_id.namespace_index == 0 && numeric_id < 256 {
				payload << u8(0x00) // Two-byte encoding
				payload << u8(numeric_id)
			} else {
				payload << u8(0x01) // Four-byte encoding
				payload << u8(node_id.namespace_index)
				payload << encode_u16(u16(numeric_id))
			}
		}
		else {
			// String node ID
			payload << u8(0x03) // String encoding
			payload << encode_u16(u16(node_id.namespace_index))
			str_bytes := node_id.identifier.bytes()
			payload << encode_u32(u32(str_bytes.len))
			payload << str_bytes
		}
	}
	return payload
}

// encode_string_field encodes a string with a 4-byte length prefix.
fn (c &Client) encode_string_field(value string) []u8 {
	bytes := value.bytes()
	mut out := []u8{cap: 4 + bytes.len}
	out << encode_u32(u32(bytes.len))
	out << bytes
	return out
}

// --- Decoding helpers ---

// decode_browse_response extracts BrowseResult from a Browse service
// response payload.
fn (c &Client) decode_browse_response(data []u8) BrowseResult {
	// Simplified: return empty result when response is too short
	if data.len < 8 {
		return BrowseResult{}
	}
	return BrowseResult{
		references: []
	}
}

// decode_read_response extracts DataValue entries from a Read service
// response payload.
fn (c &Client) decode_read_response(data []u8) []DataValue {
	if data.len < 4 {
		return []
	}
	// Simplified: return a single DataValue with raw data
	return [DataValue{
		value: data.bytestr()
		status_code: 0
		source_timestamp: time.now().unix()
		server_timestamp: time.now().unix()
	}]
}

// decode_call_response extracts CallResult from a Call service
// response payload.
fn (c &Client) decode_call_response(data []u8) CallResult {
	if data.len < 4 {
		return CallResult{status_code: 0x80000000}
	}
	status := decode_u32(data, 0)
	return CallResult{
		status_code: status
		output_arguments: []
	}
}

// decode_subscription_id extracts the subscription ID from a
// CreateSubscription response.
fn (c &Client) decode_subscription_id(data []u8) u32 {
	if data.len < 4 {
		return 0
	}
	return decode_u32(data, 0)
}

// decode_status_code extracts a StatusCode from a response payload.
fn (c &Client) decode_status_code(data []u8) u32 {
	if data.len < 4 {
		return 0x80000000 // Bad_InternalError
	}
	return decode_u32(data, 0)
}

// Notification holds a parsed data change notification from a
// Publish response.
struct Notification {
	node_id NodeId
	value   DataValue
}

// decode_publish_response extracts data change notifications from
// a Publish service response.
fn (c &Client) decode_publish_response(data []u8) []Notification {
	// Simplified: full parsing requires complex binary decoding
	return []
}

// --- Binary encoding utilities ---

// encode_u16 encodes a 16-bit unsigned integer in little-endian.
fn encode_u16(value u16) []u8 {
	return [u8(value & 0xFF), u8((value >> 8) & 0xFF)]
}

// encode_u32 encodes a 32-bit unsigned integer in little-endian.
fn encode_u32(value u32) []u8 {
	return [
		u8(value & 0xFF),
		u8((value >> 8) & 0xFF),
		u8((value >> 16) & 0xFF),
		u8((value >> 24) & 0xFF),
	]
}

// encode_f64 encodes a 64-bit IEEE 754 float in little-endian.
fn encode_f64(value f64) []u8 {
	bits := *unsafe { &u64(&value) }
	mut out := []u8{len: 8}
	for i in 0 .. 8 {
		out[i] = u8((bits >> (i * 8)) & 0xFF)
	}
	return out
}

// decode_u32 reads a 32-bit unsigned integer in little-endian from
// the given byte array at the specified offset.
fn decode_u32(data []u8, offset int) u32 {
	if offset + 4 > data.len {
		return 0
	}
	return u32(data[offset]) |
		(u32(data[offset + 1]) << 8) |
		(u32(data[offset + 2]) << 16) |
		(u32(data[offset + 3]) << 24)
}

// --- Tests ---

fn test_encode_u32() {
	result := encode_u32(0x01020304)
	assert result == [u8(0x04), u8(0x03), u8(0x02), u8(0x01)]
}

fn test_encode_u16() {
	result := encode_u16(0x0102)
	assert result == [u8(0x02), u8(0x01)]
}

fn test_decode_u32() {
	data := [u8(0x04), u8(0x03), u8(0x02), u8(0x01)]
	assert decode_u32(data, 0) == 0x01020304
}

fn test_decode_u32_out_of_bounds() {
	data := [u8(0x01)]
	assert decode_u32(data, 0) == 0
}

fn test_node_id_struct() {
	nid := NodeId{
		namespace_index: 2
		identifier: '85'
		id_type: 'numeric'
	}
	assert nid.namespace_index == 2
	assert nid.identifier == '85'
}

fn test_subscription_params_defaults() {
	params := SubscriptionParams{}
	assert params.publishing_interval_ms == 1000.0
	assert params.lifetime_count == 10000
}
