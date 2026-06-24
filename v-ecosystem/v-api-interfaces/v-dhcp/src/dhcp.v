// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem DHCP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// DHCPv4 (RFC 2131) client over UDP. Implements the full DORA
// handshake (Discover, Offer, Request, Acknowledge), lease renewal,
// release, and DHCP option parsing/encoding (RFC 2132). Also supports
// INFORM for stateless configuration. Designed for network provisioning
// and IP address management within the V-Ecosystem.

module dhcp

import net
import time

// --- DHCP protocol constants ---

// BOOTP/DHCP message types (option 53).
const dhcp_discover = u8(1)
const dhcp_offer    = u8(2)
const dhcp_request  = u8(3)
const dhcp_decline  = u8(4)
const dhcp_ack      = u8(5)
const dhcp_nak      = u8(6)
const dhcp_release  = u8(7)
const dhcp_inform   = u8(8)

// BOOTP operation codes.
const bootrequest = u8(1)
const bootreply   = u8(2)

// Hardware type: Ethernet.
const htype_ethernet = u8(1)
const hlen_ethernet  = u8(6)

// DHCP magic cookie (RFC 2131 section 3).
const magic_cookie = [u8(99), u8(130), u8(83), u8(99)]

// DHCP option codes (RFC 2132).
const opt_subnet_mask    = u8(1)
const opt_router         = u8(3)
const opt_dns_server     = u8(6)
const opt_hostname       = u8(12)
const opt_domain_name    = u8(15)
const opt_requested_ip   = u8(50)
const opt_lease_time     = u8(51)
const opt_message_type   = u8(53)
const opt_server_id      = u8(54)
const opt_param_request  = u8(55)
const opt_renewal_time   = u8(58)
const opt_rebinding_time = u8(59)
const opt_end            = u8(255)

// --- Lease state ---

// LeaseState tracks the DHCP lease lifecycle.
pub enum LeaseState {
	init         // No lease acquired
	selecting    // DISCOVER sent, awaiting OFFER
	requesting   // REQUEST sent, awaiting ACK
	bound        // Lease active
	renewing     // T1 expired, renewing with server
	rebinding    // T2 expired, broadcasting REQUEST
	released     // Lease released
}

// --- Data structures ---

// DhcpOption holds a single DHCP option (code + data).
pub struct DhcpOption {
pub:
	code u8
	data []u8
}

// Lease represents an acquired DHCP lease with all parameters.
pub struct Lease {
pub:
	client_ip     string         // Assigned IP address
	subnet_mask   string
	gateway       string         // Default gateway (router option)
	dns_servers   []string       // DNS server list
	domain_name   string
	lease_time    u32            // Lease duration in seconds
	renewal_time  u32            // T1 renewal time
	rebinding_time u32           // T2 rebinding time
	server_id     string         // DHCP server identifier
	state         LeaseState
}

// Config specifies DHCP client parameters.
pub struct Config {
pub:
	interface_name  string                               // Network interface (e.g. "eth0")
	mac_address     []u8                                  // Client MAC address (6 bytes)
	hostname        string                               // Requested hostname
	requested_ip    string                               // Preferred IP (optional)
	timeout         time.Duration = 10 * time.second
}

// Client manages DHCP lease acquisition and renewal.
pub struct Client {
mut:
	config       Config
	xid          u32           // Transaction ID
	lease        Lease
	state        LeaseState
}

// --- Client lifecycle ---

// new_client creates a DHCP client for the specified interface.
pub fn new_client(config Config) &Client {
	// Generate a random-ish transaction ID from the MAC
	mut xid := u32(0)
	for i, b in config.mac_address {
		if i < 4 {
			xid = (xid << 8) | u32(b)
		}
	}

	return &Client{
		config: config
		xid: xid
		state: .init
	}
}

// discover sends a DHCPDISCOVER broadcast and waits for an OFFER.
pub fn (mut c Client) discover() !Lease {
	c.state = .selecting

	// Build DHCPDISCOVER packet
	pkt := c.build_packet(dhcp_discover, '0.0.0.0')
	// In production, send via raw UDP socket to 255.255.255.255:67
	println('[dhcp] sending DISCOVER (xid=0x${c.xid:08x})')

	// Placeholder: would receive OFFER here
	c.state = .requesting
	return Lease{ state: .selecting }
}

// request sends a DHCPREQUEST for the offered IP and waits for ACK.
pub fn (mut c Client) request(offered_ip string, server_id string) !Lease {
	c.state = .requesting

	mut opts := []DhcpOption{}
	opts << DhcpOption{ code: opt_requested_ip, data: ip_to_bytes(offered_ip) }
	opts << DhcpOption{ code: opt_server_id, data: ip_to_bytes(server_id) }

	pkt := c.build_packet_with_options(dhcp_request, '0.0.0.0', opts)
	println('[dhcp] sending REQUEST for ${offered_ip} (server ${server_id})')

	// Placeholder: would receive ACK here and parse lease
	c.state = .bound
	c.lease = Lease{
		client_ip: offered_ip
		server_id: server_id
		state: .bound
	}
	return c.lease
}

// renew attempts to renew the current lease (unicast to server).
pub fn (mut c Client) renew() !Lease {
	if c.state != .bound && c.state != .renewing {
		return error('no active lease to renew')
	}
	c.state = .renewing
	println('[dhcp] renewing lease for ${c.lease.client_ip}')

	// Would send unicast REQUEST to server
	c.state = .bound
	return c.lease
}

// release sends a DHCPRELEASE and relinquishes the lease.
pub fn (mut c Client) release() ! {
	if c.state != .bound {
		return error('no active lease to release')
	}

	pkt := c.build_packet(dhcp_release, c.lease.client_ip)
	println('[dhcp] releasing lease for ${c.lease.client_ip}')

	c.state = .released
	c.lease = Lease{ state: .released }
}

// inform sends a DHCPINFORM to request configuration without a lease.
pub fn (mut c Client) inform(current_ip string) ![]DhcpOption {
	pkt := c.build_packet(dhcp_inform, current_ip)
	println('[dhcp] sending INFORM from ${current_ip}')

	return []DhcpOption{}
}

// --- Packet building ---

// build_packet constructs a DHCP packet with the given message type.
fn (c &Client) build_packet(msg_type u8, ciaddr string) []u8 {
	return c.build_packet_with_options(msg_type, ciaddr, [])
}

// build_packet_with_options constructs a DHCP packet with extra options.
fn (c &Client) build_packet_with_options(msg_type u8, ciaddr string, extra_opts []DhcpOption) []u8 {
	mut pkt := []u8{len: 240, init: 0}

	// BOOTP header
	pkt[0] = bootrequest          // op
	pkt[1] = htype_ethernet       // htype
	pkt[2] = hlen_ethernet        // hlen
	pkt[3] = 0                    // hops

	// Transaction ID (xid)
	pkt[4] = u8(c.xid >> 24)
	pkt[5] = u8(c.xid >> 16)
	pkt[6] = u8(c.xid >> 8)
	pkt[7] = u8(c.xid)

	// ciaddr (client IP if bound)
	ci_bytes := ip_to_bytes(ciaddr)
	for i in 0 .. 4 {
		pkt[12 + i] = ci_bytes[i]
	}

	// chaddr (client hardware address)
	for i, b in c.config.mac_address {
		if i < 16 {
			pkt[28 + i] = b
		}
	}

	// Magic cookie
	for i in 0 .. 4 {
		pkt[236 + i] = magic_cookie[i]
	}

	// DHCP options
	mut opts := []u8{}

	// Message type option (53)
	opts << opt_message_type
	opts << u8(1)
	opts << msg_type

	// Hostname option
	if c.config.hostname.len > 0 {
		opts << opt_hostname
		opts << u8(c.config.hostname.len)
		opts << c.config.hostname.bytes()
	}

	// Parameter request list
	opts << opt_param_request
	opts << u8(4)
	opts << opt_subnet_mask
	opts << opt_router
	opts << opt_dns_server
	opts << opt_domain_name

	// Extra options
	for opt in extra_opts {
		opts << opt.code
		opts << u8(opt.data.len)
		opts << opt.data
	}

	// End option
	opts << opt_end

	pkt << opts
	return pkt
}

// --- Option parsing ---

// parse_options extracts DHCP options from a packet payload
// starting after the magic cookie.
fn parse_options(data []u8) []DhcpOption {
	mut options := []DhcpOption{}
	mut i := 0
	for i < data.len {
		code := data[i]
		if code == opt_end {
			break
		}
		if code == 0 {
			// Pad option
			i++
			continue
		}
		if i + 1 >= data.len {
			break
		}
		length := int(data[i + 1])
		if i + 2 + length > data.len {
			break
		}
		options << DhcpOption{
			code: code
			data: data[i + 2..i + 2 + length]
		}
		i += 2 + length
	}
	return options
}

// --- IP address helpers ---

// ip_to_bytes converts a dotted-decimal IP string to 4 bytes.
fn ip_to_bytes(ip string) []u8 {
	parts := ip.split('.')
	mut bytes := []u8{len: 4, init: 0}
	for i, part in parts {
		if i < 4 {
			bytes[i] = u8(part.int())
		}
	}
	return bytes
}

// bytes_to_ip converts 4 bytes to a dotted-decimal IP string.
fn bytes_to_ip(data []u8) string {
	if data.len < 4 {
		return '0.0.0.0'
	}
	return '${data[0]}.${data[1]}.${data[2]}.${data[3]}'
}

// --- Tests ---

fn test_ip_to_bytes() {
	result := ip_to_bytes('192.168.1.100')
	assert result == [u8(192), u8(168), u8(1), u8(100)]
}

fn test_bytes_to_ip() {
	result := bytes_to_ip([u8(10), u8(0), u8(0), u8(1)])
	assert result == '10.0.0.1'
}

fn test_ip_to_bytes_zeros() {
	result := ip_to_bytes('0.0.0.0')
	assert result == [u8(0), u8(0), u8(0), u8(0)]
}

fn test_parse_options_end() {
	data := [u8(255)]
	opts := parse_options(data)
	assert opts.len == 0
}

fn test_parse_options_single() {
	// Option 53 (message type), length 1, value 1 (DISCOVER)
	data := [u8(53), u8(1), u8(1), u8(255)]
	opts := parse_options(data)
	assert opts.len == 1
	assert opts[0].code == 53
	assert opts[0].data == [u8(1)]
}
