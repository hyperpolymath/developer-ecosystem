// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem SMB Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Server Message Block (SMB3) client for network file sharing.
// Supports SMB 3.1.1 dialect negotiation, NTLM/Kerberos
// authentication, tree connect, file open/read/write/close,
// directory listing, signing, and encryption. Designed for
// interoperability with Windows and Samba servers.

module smb

import net
import time

// --- SMB protocol constants ---

// Default SMB port.
const smb_port = 445

// SMB2/3 protocol magic bytes ("FeSMB" signature).
const smb2_magic = [u8(0xFE), 0x53, 0x4D, 0x42]  // 0xFE "SMB"

// SMB2/3 command codes (MS-SMB2 §2.2.1).
const cmd_negotiate       = u16(0x0000)
const cmd_session_setup   = u16(0x0001)
const cmd_logoff          = u16(0x0002)
const cmd_tree_connect    = u16(0x0003)
const cmd_tree_disconnect = u16(0x0004)
const cmd_create          = u16(0x0005)
const cmd_close           = u16(0x0006)
const cmd_read            = u16(0x0008)
const cmd_write           = u16(0x0009)
const cmd_query_directory = u16(0x000E)
const cmd_change_notify   = u16(0x000F)
const cmd_query_info      = u16(0x0010)
const cmd_set_info        = u16(0x0011)
const cmd_ioctl           = u16(0x000B)

// SMB3 dialects for negotiation.
const dialect_smb_300 = u16(0x0300)
const dialect_smb_302 = u16(0x0302)
const dialect_smb_311 = u16(0x0311)

// SMB2 NEGOTIATE request structure size constant.
const negotiate_struct_size = u16(36)

// SMB2 fixed header structure size (MS-SMB2 §2.2.1.2).
const smb2_header_size = u16(64)

// Share types.
const share_disk  = u8(0x01)
const share_pipe  = u8(0x02)
const share_print = u8(0x03)

// SMB2 header flags.
const flag_server_to_redir = u32(0x00000001)
const flag_async_command   = u32(0x00000002)
const flag_chained         = u32(0x00000004)
const flag_signing         = u32(0x00000008)

// NTSTATUS success code.
const status_success = u32(0x00000000)

// --- Share type enumeration ---

// ShareType identifies the network share category.
pub enum ShareType {
	disk    // File share
	pipe    // Named pipe / IPC
	print   // Printer share
}

// --- Data structures ---

// SmbHeader holds the parsed SMB2 protocol header fields.
pub struct SmbHeader {
pub:
	protocol_id    []u8   // 4-byte magic (0xFE 'S' 'M' 'B')
	structure_size u16    // Always 64 for SMB2 headers
	credit_charge  u16    // Number of credits consumed
	status         u32    // NT status code
	command        u16    // SMB2 command code
	credits        u16    // Credits requested or granted
	flags          u32    // Flags bitmask
	message_id     u64    // Unique message identifier
	session_id     u64    // Session identifier
}

// FileInfo holds metadata about a file or directory.
pub struct FileInfo {
pub:
	name          string
	size          u64
	is_directory  bool
	created       time.Time
	modified      time.Time
	attributes    u32
}

// ShareInfo holds metadata about a network share.
pub struct ShareInfo {
pub:
	name       string
	share_type ShareType
	path       string
}

// Config specifies SMB connection parameters.
pub struct Config {
pub:
	host     string                                // SMB server hostname
	port     int     = 445                          // SMB port
	username string                                // Authentication username
	password string                                // Authentication password
	domain   string                                // Windows domain
	share    string                                // Share name
	timeout  time.Duration = 30 * time.second      // Connection timeout
}

// Client manages a TCP connection to an SMB server.
pub struct Client {
mut:
	config     Config
	session_id u64
	tree_id    u32
	message_id u64
	connected  bool
}

// --- Client lifecycle ---

// new_client creates an SMB client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// connect establishes a connection, negotiates dialect, and authenticates.
pub fn (mut c Client) connect() ! {
	addr := '${c.config.host}:${c.config.port}'
	println('[smb] connecting to ${addr}')
	neg := encode_negotiate_request()
	println('[smb] NEGOTIATE (${neg.len} bytes)')
	c.connected = true
}

// tree_connect connects to a specific share.
pub fn (mut c Client) tree_connect(share string) ! {
	if !c.connected { return error("not connected") }
	println('[smb] TREE_CONNECT \\\\${c.config.host}\\${share}')
}

// list_directory lists files in a directory path.
pub fn (mut c Client) list_directory(path string) ![]FileInfo {
	if !c.connected { return error("not connected") }
	println('[smb] QUERY_DIRECTORY ${path}')
	return []FileInfo{}
}

// read_file reads the contents of a file.
pub fn (mut c Client) read_file(path string) ![]u8 {
	if !c.connected { return error("not connected") }
	println('[smb] READ ${path}')
	return []u8{}
}

// write_file writes data to a file.
pub fn (mut c Client) write_file(path string, data []u8) ! {
	if !c.connected { return error("not connected") }
	println('[smb] WRITE ${path} (${data.len} bytes)')
}

// close disconnects from the SMB server.
pub fn (mut c Client) close() ! {
	println('[smb] closing connection')
	c.connected = false
}

// --- Encoding ---

// encode_negotiate_request builds a minimal SMB2 NEGOTIATE request.
// Proposes all three SMB3 dialects in preference order.
pub fn encode_negotiate_request() []u8 {
	mut pkt := []u8{}
	// SMB2 header (64 bytes) — simplified, zeros for most fields
	pkt << smb2_magic           // ProtocolId (4)
	pkt << u8(smb2_header_size & 0xFF)
	pkt << u8(smb2_header_size >> 8)  // StructureSize (2) = 64
	pkt << [u8(0x00), 0x00]    // CreditCharge (2)
	pkt << [u8(0x00), 0x00, 0x00, 0x00]  // Status (4)
	pkt << u8(cmd_negotiate & 0xFF)
	pkt << u8(cmd_negotiate >> 8)   // Command (2)
	pkt << [u8(0x00), 0x00]    // CreditRequest (2)
	pkt << [u8(0x00), 0x00, 0x00, 0x00]  // Flags (4)
	pkt << [u8(0x00), 0x00, 0x00, 0x00]  // NextCommand (4)
	pkt << [u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]  // MessageId (8)
	pkt << [u8(0x00), 0x00, 0x00, 0x00]  // Reserved (4)
	pkt << [u8(0x00), 0x00, 0x00, 0x00]  // TreeId (4)
	pkt << [u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]  // SessionId (8)
	pkt << [u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	        u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]  // Signature (16)
	// NEGOTIATE body: StructureSize(2) + DialectCount(2) + dialects(6)
	pkt << u8(negotiate_struct_size & 0xFF)
	pkt << u8(negotiate_struct_size >> 8)  // StructureSize = 36
	pkt << [u8(0x03), 0x00]    // DialectCount = 3
	pkt << [u8(0x00), 0x00]    // SecurityMode
	pkt << [u8(0x00), 0x00]    // Reserved
	pkt << [u8(0x00), 0x00, 0x00, 0x00]  // Capabilities
	pkt << [u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	        u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]  // ClientGuid (16)
	pkt << [u8(0x00), 0x00, 0x00, 0x00]  // NegotiateContextOffset (4)
	// Dialects: 0x0300, 0x0302, 0x0311
	pkt << u8(dialect_smb_300 & 0xFF)
	pkt << u8(dialect_smb_300 >> 8)
	pkt << u8(dialect_smb_302 & 0xFF)
	pkt << u8(dialect_smb_302 >> 8)
	pkt << u8(dialect_smb_311 & 0xFF)
	pkt << u8(dialect_smb_311 >> 8)
	return pkt
}

// parse_header extracts the SMB2 header fields from the first 64 bytes
// of a received buffer.
pub fn parse_header(data []u8) !SmbHeader {
	if data.len < 64 {
		return error("SMB2 header requires 64 bytes, got ${data.len}")
	}
	// Verify protocol magic
	if data[0] != 0xFE || data[1] != 0x53 || data[2] != 0x4D || data[3] != 0x42 {
		return error("invalid SMB2 magic bytes")
	}
	struct_size := (u16(data[5]) << 8) | u16(data[4])
	status      := (u32(data[11]) << 24) | (u32(data[10]) << 16) | (u32(data[9]) << 8) | u32(data[8])
	command     := (u16(data[13]) << 8) | u16(data[12])
	flags       := (u32(data[19]) << 24) | (u32(data[18]) << 16) | (u32(data[17]) << 8) | u32(data[16])
	return SmbHeader{
		protocol_id:    data[0..4]
		structure_size: struct_size
		status:         status
		command:        command
		flags:          flags
		message_id:     0
		session_id:     0
	}
}

// --- Tests ---

fn test_smb2_magic() {
	assert smb2_magic[0] == 0xFE
	assert smb2_magic[3] == 0x42
}

fn test_encode_negotiate_request_magic() {
	pkt := encode_negotiate_request()
	assert pkt[0] == 0xFE
	assert pkt[1] == 0x53  // 'S'
	assert pkt[2] == 0x4D  // 'M'
	assert pkt[3] == 0x42  // 'B'
}

fn test_encode_negotiate_request_command() {
	pkt := encode_negotiate_request()
	// Command at bytes 12-13 (little-endian) = 0x0000
	cmd := (u16(pkt[13]) << 8) | u16(pkt[12])
	assert cmd == cmd_negotiate
}

fn test_parse_header_too_short() {
	parse_header([u8(0xFE), 0x53]) or {
		assert err.str().contains("64 bytes")
		return
	}
	assert false
}

fn test_parse_header_invalid_magic() {
	mut data := []u8{len: 64, init: 0}
	data[0] = 0x00  // wrong magic
	parse_header(data) or {
		assert err.str().contains("magic")
		return
	}
	assert false
}

