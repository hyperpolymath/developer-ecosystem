// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem VPN Protocol Connector
// Author: Jonathan D.A. Jewell
//
// VPN management client supporting WireGuard and OpenVPN control
// interfaces. Provides peer lifecycle management, key generation
// and exchange, tunnel configuration, and real-time status monitoring.
// WireGuard operations use the userspace API (via /var/run/wireguard/);
// OpenVPN uses the management socket protocol.

module vpn

import net
import os
import time

// --- VPN backend enumeration ---

// VpnBackend selects which VPN protocol implementation is used
// for tunnel operations.
pub enum VpnBackend {
	wireguard   // WireGuard kernel/userspace interface
	openvpn     // OpenVPN management interface
}

// --- Peer and tunnel status ---

// PeerState represents the current connectivity status of a VPN peer.
pub enum PeerState {
	disconnected    // No handshake established
	connecting      // Handshake in progress
	connected       // Active tunnel with recent handshake
	stale           // Connected but handshake is stale (> 5 minutes)
}

// --- Configuration ---

// Config holds the parameters needed to connect to a VPN management
// interface.
pub struct Config {
pub:
	backend           VpnBackend
	interface_name    string = 'wg0'
	// WireGuard-specific
	wg_socket_path    string = '/var/run/wireguard'
	// OpenVPN-specific
	openvpn_mgmt_host string = '127.0.0.1'
	openvpn_mgmt_port int    = 7505
	openvpn_password  string
	connect_timeout   time.Duration = 5 * time.second
}

// --- Data structures ---

// KeyPair holds a WireGuard private/public key pair encoded as
// base64 strings.
pub struct KeyPair {
pub:
	private_key string
	public_key  string
}

// Peer represents a VPN peer with its cryptographic identity,
// networking configuration, and traffic statistics.
pub struct Peer {
pub mut:
	public_key             string
	preshared_key          string
	endpoint               string   // host:port
	allowed_ips            []string // CIDR ranges
	latest_handshake       i64      // Unix timestamp
	transfer_rx            i64      // Bytes received
	transfer_tx            i64      // Bytes transmitted
	persistent_keepalive   int      // Seconds (0 = disabled)
	state                  PeerState
}

// TunnelConfig describes the local side of a VPN tunnel interface.
pub struct TunnelConfig {
pub mut:
	interface_name   string
	private_key      string
	listen_port      int
	address          string   // Local tunnel IP (CIDR)
	dns_servers      []string
	mtu              int = 1420
	table            string = 'auto'
	pre_up           string
	post_up          string
	pre_down         string
	post_down        string
}

// TunnelStatus holds runtime statistics for a tunnel interface.
pub struct TunnelStatus {
pub:
	interface_name   string
	public_key       string
	listen_port      int
	peer_count       int
	total_rx         i64
	total_tx         i64
	up_since         i64   // Unix timestamp
	is_active        bool
}

// OpenVpnStatus holds the parsed output of an OpenVPN management
// status query.
pub struct OpenVpnStatus {
pub mut:
	connected_clients int
	bytes_received    i64
	bytes_sent        i64
	uptime            string
	clients           []OpenVpnClient
}

// OpenVpnClient represents a single connected OpenVPN client.
pub struct OpenVpnClient {
pub:
	common_name    string
	real_address   string
	virtual_address string
	bytes_received i64
	bytes_sent     i64
	connected_since string
}

// --- Client ---

// Client manages the connection to a VPN management interface and
// provides operations for peer and tunnel lifecycle management.
pub struct Client {
mut:
	config      Config
	mgmt_conn   ?net.TcpConn  // OpenVPN management connection
	connected   bool
}

// connect establishes a connection to the VPN management interface.
// For WireGuard, this validates the socket path exists. For OpenVPN,
// this connects to the management TCP socket and authenticates.
pub fn connect(config Config) !&Client {
	mut client := &Client{
		config: config
	}

	match config.backend {
		.wireguard {
			// Verify the WireGuard socket/interface exists
			socket_path := '${config.wg_socket_path}/${config.interface_name}.sock'
			if !os.exists(socket_path) {
				// Fall back to checking the interface via /sys
				iface_path := '/sys/class/net/${config.interface_name}'
				if !os.exists(iface_path) {
					return error('wireguard interface ${config.interface_name} not found')
				}
			}
			println('[vpn] wireguard interface ${config.interface_name} available')
		}
		.openvpn {
			addr := '${config.openvpn_mgmt_host}:${config.openvpn_mgmt_port}'
			mut conn := net.dial_tcp(addr)!
			conn.set_read_timeout(config.connect_timeout)

			// Read greeting banner
			mut banner := []u8{len: 1024}
			conn.read(mut banner) or {}

			// Authenticate if password is set
			if config.openvpn_password.len > 0 {
				conn.write('${config.openvpn_password}\n'.bytes())!
				mut auth_resp := []u8{len: 256}
				conn.read(mut auth_resp) or {}
			}

			client.mgmt_conn = conn
			println('[vpn] connected to openvpn management at ${addr}')
		}
	}

	client.connected = true
	return client
}

// disconnect cleanly shuts down the management connection.
pub fn (mut c Client) disconnect() {
	if !c.connected {
		return
	}
	if mut conn := c.mgmt_conn {
		conn.write('quit\n'.bytes()) or {}
		conn.close() or {}
	}
	c.connected = false
	println('[vpn] disconnected')
}

// --- Peer management ---

// add_peer registers a new peer with the VPN interface. For
// WireGuard, this invokes the wg tool; for OpenVPN, client
// certificates are managed externally.
pub fn (mut c Client) add_peer(peer Peer) ! {
	if !c.connected {
		return error('not connected')
	}

	match c.config.backend {
		.wireguard {
			c.wg_set_peer(peer)!
			println('[vpn] added wireguard peer ${peer.public_key[..8]}...')
		}
		.openvpn {
			// OpenVPN peer management is handled via certificate revocation
			// and configuration files, not the management interface.
			return error('openvpn peer add requires certificate management (not supported via management interface)')
		}
	}
}

// remove_peer deregisters a peer from the VPN interface.
pub fn (mut c Client) remove_peer(public_key string) ! {
	if !c.connected {
		return error('not connected')
	}

	match c.config.backend {
		.wireguard {
			result := os.execute('wg set ${c.config.interface_name} peer ${public_key} remove')
			if result.exit_code != 0 {
				return error('failed to remove peer: ${result.output}')
			}
			println('[vpn] removed wireguard peer ${public_key[..8]}...')
		}
		.openvpn {
			// Kill a connected OpenVPN client by common name
			c.openvpn_command('kill ${public_key}')!
			println('[vpn] disconnected openvpn client ${public_key}')
		}
	}
}

// list_peers returns all currently configured peers and their
// status information.
pub fn (mut c Client) list_peers() ![]Peer {
	if !c.connected {
		return error('not connected')
	}

	return match c.config.backend {
		.wireguard {
			c.wg_list_peers()!
		}
		.openvpn {
			c.openvpn_list_peers()!
		}
	}
}

// get_peer retrieves a single peer's status by its public key
// (WireGuard) or common name (OpenVPN).
pub fn (mut c Client) get_peer(identifier string) !Peer {
	peers := c.list_peers()!
	for peer in peers {
		if peer.public_key == identifier {
			return peer
		}
	}
	return error('peer ${identifier} not found')
}

// --- Key generation ---

// generate_keypair creates a new WireGuard private/public key pair
// using the wg command-line tool. Returns an error if the tool is
// not available.
pub fn generate_keypair() !KeyPair {
	priv_result := os.execute('wg genkey')
	if priv_result.exit_code != 0 {
		return error('wg genkey failed: ${priv_result.output}')
	}
	private_key := priv_result.output.trim_space()

	// Pipe private key through wg pubkey to derive public key
	pub_result := os.execute('echo "${private_key}" | wg pubkey')
	if pub_result.exit_code != 0 {
		return error('wg pubkey failed: ${pub_result.output}')
	}
	public_key := pub_result.output.trim_space()

	return KeyPair{
		private_key: private_key
		public_key: public_key
	}
}

// generate_preshared_key creates a new WireGuard preshared key for
// an additional layer of symmetric-key cryptographic protection.
pub fn generate_preshared_key() !string {
	result := os.execute('wg genpsk')
	if result.exit_code != 0 {
		return error('wg genpsk failed: ${result.output}')
	}
	return result.output.trim_space()
}

// --- Tunnel configuration ---

// configure_tunnel applies a tunnel configuration to the local
// WireGuard interface. This sets the private key, listen port,
// and interface address.
pub fn (mut c Client) configure_tunnel(tunnel TunnelConfig) ! {
	if !c.connected {
		return error('not connected')
	}

	match c.config.backend {
		.wireguard {
			// Set the private key and listen port
			mut wg_cmd := 'wg set ${tunnel.interface_name} private-key /dev/stdin listen-port ${tunnel.listen_port}'
			result := os.execute('echo "${tunnel.private_key}" | ${wg_cmd}')
			if result.exit_code != 0 {
				return error('failed to configure tunnel: ${result.output}')
			}

			// Assign the IP address
			if tunnel.address.len > 0 {
				ip_result := os.execute('ip address add ${tunnel.address} dev ${tunnel.interface_name}')
				if ip_result.exit_code != 0 {
					return error('failed to assign address: ${ip_result.output}')
				}
			}

			// Set MTU
			mtu_result := os.execute('ip link set mtu ${tunnel.mtu} dev ${tunnel.interface_name}')
			if mtu_result.exit_code != 0 {
				return error('failed to set mtu: ${mtu_result.output}')
			}

			// Bring interface up
			up_result := os.execute('ip link set up dev ${tunnel.interface_name}')
			if up_result.exit_code != 0 {
				return error('failed to bring interface up: ${up_result.output}')
			}

			println('[vpn] tunnel ${tunnel.interface_name} configured (port ${tunnel.listen_port})')
		}
		.openvpn {
			return error('openvpn tunnel configuration requires config file — not supported via management interface')
		}
	}
}

// --- Status monitoring ---

// get_tunnel_status returns current runtime statistics for the
// VPN tunnel interface.
pub fn (mut c Client) get_tunnel_status() !TunnelStatus {
	if !c.connected {
		return error('not connected')
	}

	match c.config.backend {
		.wireguard {
			return c.wg_tunnel_status()!
		}
		.openvpn {
			status := c.openvpn_status()!
			return TunnelStatus{
				interface_name: c.config.interface_name
				peer_count: status.connected_clients
				total_rx: status.bytes_received
				total_tx: status.bytes_sent
				is_active: status.connected_clients > 0
			}
		}
	}
}

// get_openvpn_status returns detailed OpenVPN status including
// per-client statistics. Only available when using the OpenVPN
// backend.
pub fn (mut c Client) get_openvpn_status() !OpenVpnStatus {
	if c.config.backend != .openvpn {
		return error('openvpn status only available with openvpn backend')
	}
	return c.openvpn_status()
}

// --- Internal WireGuard helpers ---

// wg_set_peer configures a peer on the WireGuard interface using
// the wg command-line tool.
fn (mut c Client) wg_set_peer(peer Peer) ! {
	mut cmd := 'wg set ${c.config.interface_name} peer ${peer.public_key}'

	if peer.preshared_key.len > 0 {
		cmd += ' preshared-key /dev/stdin'
	}
	if peer.endpoint.len > 0 {
		cmd += ' endpoint ${peer.endpoint}'
	}
	if peer.allowed_ips.len > 0 {
		cmd += ' allowed-ips ${peer.allowed_ips.join(",")}'
	}
	if peer.persistent_keepalive > 0 {
		cmd += ' persistent-keepalive ${peer.persistent_keepalive}'
	}

	mut execute_cmd := cmd
	if peer.preshared_key.len > 0 {
		execute_cmd = 'echo "${peer.preshared_key}" | ${cmd}'
	}

	result := os.execute(execute_cmd)
	if result.exit_code != 0 {
		return error('wg set peer failed: ${result.output}')
	}
}

// wg_list_peers parses the output of `wg show` to enumerate all
// configured peers and their current status.
fn (mut c Client) wg_list_peers() ![]Peer {
	result := os.execute('wg show ${c.config.interface_name} dump')
	if result.exit_code != 0 {
		return error('wg show failed: ${result.output}')
	}

	mut peers := []Peer{}
	lines := result.output.split('\n')
	// First line is the interface; remaining lines are peers
	for line in lines[1..] {
		fields := line.split('\t')
		if fields.len < 8 {
			continue
		}
		latest_handshake := fields[4].i64()
		peer_state := classify_peer_state(latest_handshake)

		peers << Peer{
			public_key: fields[0]
			preshared_key: if fields[1] != '(none)' { fields[1] } else { '' }
			endpoint: if fields[2] != '(none)' { fields[2] } else { '' }
			allowed_ips: fields[3].split(',')
			latest_handshake: latest_handshake
			transfer_rx: fields[5].i64()
			transfer_tx: fields[6].i64()
			persistent_keepalive: if fields[7] != 'off' { fields[7].int() } else { 0 }
			state: peer_state
		}
	}
	return peers
}

// wg_tunnel_status gathers interface-level statistics from the
// WireGuard kernel interface.
fn (mut c Client) wg_tunnel_status() !TunnelStatus {
	result := os.execute('wg show ${c.config.interface_name} dump')
	if result.exit_code != 0 {
		return error('wg show failed: ${result.output}')
	}

	lines := result.output.split('\n')
	if lines.len == 0 {
		return error('empty wg show output')
	}

	// First line: private-key, public-key, listen-port, fwmark
	iface_fields := lines[0].split('\t')
	public_key := if iface_fields.len > 1 { iface_fields[1] } else { '' }
	listen_port := if iface_fields.len > 2 { iface_fields[2].int() } else { 0 }

	// Sum peer transfer stats
	mut total_rx := i64(0)
	mut total_tx := i64(0)
	mut peer_count := 0
	for line in lines[1..] {
		fields := line.split('\t')
		if fields.len >= 7 {
			total_rx += fields[5].i64()
			total_tx += fields[6].i64()
			peer_count++
		}
	}

	return TunnelStatus{
		interface_name: c.config.interface_name
		public_key: public_key
		listen_port: listen_port
		peer_count: peer_count
		total_rx: total_rx
		total_tx: total_tx
		is_active: peer_count > 0
	}
}

// classify_peer_state determines a peer's connectivity state based
// on the latest handshake timestamp. A handshake older than 5
// minutes is considered stale.
fn classify_peer_state(latest_handshake i64) PeerState {
	if latest_handshake == 0 {
		return .disconnected
	}
	now := time.now().unix()
	elapsed_seconds := now - latest_handshake
	stale_threshold := i64(300) // 5 minutes
	if elapsed_seconds > stale_threshold {
		return .stale
	}
	return .connected
}

// --- Internal OpenVPN helpers ---

// openvpn_command sends a command to the OpenVPN management socket
// and returns the response text.
fn (mut c Client) openvpn_command(command string) !string {
	if mut conn := c.mgmt_conn {
		conn.write('${command}\n'.bytes())!
		mut response_buf := []u8{len: 4096}
		bytes_read := conn.read(mut response_buf) or { 0 }
		if bytes_read == 0 {
			return ''
		}
		return response_buf[..bytes_read].bytestr()
	}
	return error('no management connection')
}

// openvpn_status queries the OpenVPN management interface for
// current server status and parses the response.
fn (mut c Client) openvpn_status() !OpenVpnStatus {
	response := c.openvpn_command('status 2')!

	mut status := OpenVpnStatus{}
	mut in_client_section := false
	lines := response.split('\n')

	for line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with('HEADER,CLIENT_LIST') {
			in_client_section = true
			continue
		}
		if trimmed.starts_with('HEADER,ROUTING_TABLE') {
			in_client_section = false
			continue
		}
		if in_client_section && trimmed.starts_with('CLIENT_LIST,') {
			fields := trimmed.split(',')
			if fields.len >= 8 {
				client_rx := fields[5].i64()
				client_tx := fields[6].i64()
				status.clients << OpenVpnClient{
					common_name: fields[1]
					real_address: fields[2]
					virtual_address: fields[3]
					bytes_received: client_rx
					bytes_sent: client_tx
					connected_since: fields[7]
				}
				status.bytes_received += client_rx
				status.bytes_sent += client_tx
			}
		}
	}

	status.connected_clients = status.clients.len
	return status
}

// openvpn_list_peers converts OpenVPN connected clients into the
// unified Peer structure.
fn (mut c Client) openvpn_list_peers() ![]Peer {
	status := c.openvpn_status()!
	mut peers := []Peer{}
	for client in status.clients {
		peers << Peer{
			public_key: client.common_name
			endpoint: client.real_address
			allowed_ips: [client.virtual_address]
			transfer_rx: client.bytes_received
			transfer_tx: client.bytes_sent
			state: .connected
		}
	}
	return peers
}

// --- Tests ---

fn test_classify_peer_state_disconnected() {
	assert classify_peer_state(0) == .disconnected
}

fn test_classify_peer_state_connected() {
	// Handshake 10 seconds ago should be connected
	recent := time.now().unix() - 10
	assert classify_peer_state(recent) == .connected
}

fn test_classify_peer_state_stale() {
	// Handshake 10 minutes ago should be stale
	old := time.now().unix() - 600
	assert classify_peer_state(old) == .stale
}

fn test_keypair_struct() {
	kp := KeyPair{
		private_key: 'test_priv'
		public_key: 'test_pub'
	}
	assert kp.private_key == 'test_priv'
	assert kp.public_key == 'test_pub'
}

fn test_tunnel_config_defaults() {
	tc := TunnelConfig{
		interface_name: 'wg0'
		private_key: 'key'
		listen_port: 51820
		address: '10.0.0.1/24'
	}
	assert tc.mtu == 1420
	assert tc.table == 'auto'
}
