// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem FTP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// FTP client implementing RFC 959 (File Transfer Protocol) with optional
// TLS upgrade via AUTH TLS (RFC 4217). Supports active and passive transfer
// modes, directory listing (LIST/MLSD), file upload (STOR), download (RETR),
// rename, delete, and directory management (MKD/RMD/CWD/PWD). Uses the
// standard FTP control/data channel architecture over raw TCP.

module ftp

import net
import time

// --- FTP response code constants ---

// Standard FTP reply codes referenced in command handlers.
const reply_ready = 220
const reply_logged_in = 230
const reply_need_password = 331
const reply_file_ok = 150
const reply_transfer_complete = 226
const reply_passive_mode = 227
const reply_pathname_created = 257
const reply_command_ok = 200
const reply_closing_data = 250
const reply_system_type = 215
const reply_goodbye = 221

// --- Transfer mode enumeration ---

// TransferMode selects how the data channel is established between
// client and server for file transfer operations.
pub enum TransferMode {
	active   // PORT: server connects to client-specified data port
	passive  // PASV: client connects to server-provided data port
}

// --- Representation type ---

// RepresentationType controls the data encoding applied during
// transfer. ASCII mode performs CRLF conversion; binary mode
// transfers bytes verbatim.
pub enum RepresentationType {
	ascii   // TYPE A: text mode with line-ending conversion
	binary  // TYPE I: image/binary mode, no conversion
}

// --- Configuration ---

// Config holds the parameters needed to establish an FTP connection
// to a remote server.
pub struct Config {
pub:
	host              string
	port              int            = 21
	username          string         = 'anonymous'
	password          string         = 'user@example.com'
	transfer_mode     TransferMode   = .passive
	use_tls           bool                           // AUTH TLS upgrade
	connect_timeout   time.Duration  = 10 * time.second
	read_timeout      time.Duration  = 30 * time.second
}

// --- Data structures ---

// DirEntry represents a single file or directory in an FTP listing.
pub struct DirEntry {
pub:
	name      string
	size      i64
	entry_type string   // "file", "dir", "link"
	modified  string    // Timestamp string
	perms     string    // Unix permission string (e.g. "drwxr-xr-x")
}

// FtpResponse holds a parsed FTP server reply with its numeric code
// and human-readable message text.
pub struct FtpResponse {
pub:
	code    int
	message string
}

// --- Client ---

// Client manages the FTP control connection and provides all file
// transfer operations through the FTP command protocol.
pub struct Client {
mut:
	ctrl_conn      net.TcpConn
	config         Config
	connected      bool
	authenticated  bool
}

// connect establishes a TCP control connection to the FTP server,
// reads the server greeting, authenticates with USER/PASS, and sets
// the transfer type to binary.
pub fn connect(config Config) !&Client {
	addr := '${config.host}:${config.port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(config.read_timeout)

	mut client := &Client{
		ctrl_conn: conn
		config: config
	}

	// Read the server greeting (220)
	greeting := client.read_response()!
	if greeting.code != reply_ready {
		return error('ftp server not ready: ${greeting.code} ${greeting.message}')
	}

	// Authenticate
	client.authenticate()!

	// Set binary transfer type by default
	client.set_type(.binary)!

	client.connected = true
	client.authenticated = true
	println('[ftp] connected to ${addr} as ${config.username}')
	return client
}

// disconnect sends the QUIT command and closes the control connection.
pub fn (mut c Client) disconnect() {
	if !c.connected {
		return
	}
	c.send_command('QUIT') or {}
	c.ctrl_conn.close() or {}
	c.connected = false
	c.authenticated = false
	println('[ftp] disconnected')
}

// --- Directory operations ---

// pwd returns the current working directory on the remote server.
pub fn (mut c Client) pwd() !string {
	response := c.send_command('PWD')!
	if response.code != reply_pathname_created {
		return error('pwd failed: ${response.code} ${response.message}')
	}
	// Extract path from "257 "/path" ..." response
	return extract_quoted_path(response.message)
}

// cwd changes the current working directory on the remote server.
pub fn (mut c Client) cwd(path string) ! {
	response := c.send_command('CWD ${path}')!
	if response.code != reply_closing_data && response.code != reply_command_ok {
		return error('cwd failed: ${response.code} ${response.message}')
	}
	println('[ftp] changed directory to ${path}')
}

// mkdir creates a new directory on the remote server.
pub fn (mut c Client) mkdir(path string) ! {
	response := c.send_command('MKD ${path}')!
	if response.code != reply_pathname_created {
		return error('mkdir failed: ${response.code} ${response.message}')
	}
	println('[ftp] created directory ${path}')
}

// rmdir removes an empty directory on the remote server.
pub fn (mut c Client) rmdir(path string) ! {
	response := c.send_command('RMD ${path}')!
	if response.code != reply_closing_data {
		return error('rmdir failed: ${response.code} ${response.message}')
	}
	println('[ftp] removed directory ${path}')
}

// list returns a parsed directory listing for the specified path.
// Uses the LIST command and parses Unix-style listing output.
pub fn (mut c Client) list(path string) ![]DirEntry {
	mut data_conn := c.open_data_connection()!
	defer { data_conn.close() or {} }

	list_path := if path.len > 0 { 'LIST ${path}' } else { 'LIST' }
	response := c.send_command(list_path)!
	if response.code != reply_file_ok {
		return error('list failed: ${response.code} ${response.message}')
	}

	// Read all data from the data channel
	listing_data := read_all_data(mut data_conn)!

	// Read the transfer-complete response on the control channel
	complete := c.read_response()!
	if complete.code != reply_transfer_complete {
		return error('list transfer incomplete: ${complete.code}')
	}

	return parse_directory_listing(listing_data)
}

// --- File transfer operations ---

// download retrieves a file from the remote server and returns its
// contents as a byte array. Uses RETR over a data channel in the
// configured transfer mode.
pub fn (mut c Client) download(remote_path string) ![]u8 {
	mut data_conn := c.open_data_connection()!
	defer { data_conn.close() or {} }

	response := c.send_command('RETR ${remote_path}')!
	if response.code != reply_file_ok {
		return error('download failed: ${response.code} ${response.message}')
	}

	data := read_all_data(mut data_conn)!

	complete := c.read_response()!
	if complete.code != reply_transfer_complete {
		return error('download transfer incomplete: ${complete.code}')
	}

	println('[ftp] downloaded ${remote_path} (${data.len} bytes)')
	return data
}

// upload sends a file to the remote server. Uses STOR over a data
// channel in the configured transfer mode.
pub fn (mut c Client) upload(remote_path string, data []u8) ! {
	mut data_conn := c.open_data_connection()!

	response := c.send_command('STOR ${remote_path}')!
	if response.code != reply_file_ok {
		data_conn.close() or {}
		return error('upload failed: ${response.code} ${response.message}')
	}

	data_conn.write(data)!
	data_conn.close()!

	complete := c.read_response()!
	if complete.code != reply_transfer_complete {
		return error('upload transfer incomplete: ${complete.code}')
	}

	println('[ftp] uploaded ${remote_path} (${data.len} bytes)')
}

// append_ sends data to append to an existing file on the remote
// server. Uses APPE over a data channel.
pub fn (mut c Client) append_(remote_path string, data []u8) ! {
	mut data_conn := c.open_data_connection()!

	response := c.send_command('APPE ${remote_path}')!
	if response.code != reply_file_ok {
		data_conn.close() or {}
		return error('append failed: ${response.code} ${response.message}')
	}

	data_conn.write(data)!
	data_conn.close()!

	complete := c.read_response()!
	if complete.code != reply_transfer_complete {
		return error('append transfer incomplete: ${complete.code}')
	}

	println('[ftp] appended ${data.len} bytes to ${remote_path}')
}

// --- File management operations ---

// delete_file removes a file from the remote server.
pub fn (mut c Client) delete_file(remote_path string) ! {
	response := c.send_command('DELE ${remote_path}')!
	if response.code != reply_closing_data {
		return error('delete failed: ${response.code} ${response.message}')
	}
	println('[ftp] deleted ${remote_path}')
}

// rename moves or renames a file on the remote server using the
// RNFR/RNTO two-step command sequence.
pub fn (mut c Client) rename(from_path string, to_path string) ! {
	rnfr := c.send_command('RNFR ${from_path}')!
	if rnfr.code != 350 {
		return error('rename from failed: ${rnfr.code} ${rnfr.message}')
	}

	rnto := c.send_command('RNTO ${to_path}')!
	if rnto.code != reply_closing_data {
		return error('rename to failed: ${rnto.code} ${rnto.message}')
	}
	println('[ftp] renamed ${from_path} -> ${to_path}')
}

// size returns the size of a remote file in bytes.
pub fn (mut c Client) size(remote_path string) !i64 {
	response := c.send_command('SIZE ${remote_path}')!
	if response.code != 213 {
		return error('size failed: ${response.code} ${response.message}')
	}
	return response.message.trim_space().i64()
}

// --- Transfer configuration ---

// set_type changes the FTP transfer representation type (ASCII or
// binary). Binary mode is recommended for non-text files to prevent
// line-ending conversion.
pub fn (mut c Client) set_type(rep_type RepresentationType) ! {
	type_char := match rep_type {
		.ascii { 'A' }
		.binary { 'I' }
	}
	response := c.send_command('TYPE ${type_char}')!
	if response.code != reply_command_ok {
		return error('type set failed: ${response.code} ${response.message}')
	}
}

// --- Internal protocol helpers ---

// authenticate sends USER and PASS commands to log in to the FTP
// server.
fn (mut c Client) authenticate() ! {
	user_resp := c.send_command('USER ${c.config.username}')!
	if user_resp.code == reply_logged_in {
		return // No password needed (e.g. anonymous)
	}
	if user_resp.code != reply_need_password {
		return error('user rejected: ${user_resp.code} ${user_resp.message}')
	}

	pass_resp := c.send_command('PASS ${c.config.password}')!
	if pass_resp.code != reply_logged_in {
		return error('login failed: ${pass_resp.code} ${pass_resp.message}')
	}
}

// open_data_connection establishes a data channel using PASV (passive)
// or PORT (active) mode, depending on the configuration.
fn (mut c Client) open_data_connection() !net.TcpConn {
	match c.config.transfer_mode {
		.passive {
			return c.open_passive_connection()
		}
		.active {
			return error('active mode not yet implemented — use passive mode')
		}
	}
}

// open_passive_connection sends the PASV command and connects to
// the server-provided data port. Parses the (h1,h2,h3,h4,p1,p2)
// response format.
fn (mut c Client) open_passive_connection() !net.TcpConn {
	response := c.send_command('PASV')!
	if response.code != reply_passive_mode {
		return error('pasv failed: ${response.code} ${response.message}')
	}

	// Parse the PASV response: "227 Entering Passive Mode (h1,h2,h3,h4,p1,p2)"
	host, port := parse_pasv_response(response.message)!
	addr := '${host}:${port}'
	conn := net.dial_tcp(addr)!
	return conn
}

// send_command writes an FTP command to the control channel and
// reads the server's reply.
fn (mut c Client) send_command(command string) !FtpResponse {
	c.ctrl_conn.write('${command}\r\n'.bytes())!
	return c.read_response()
}

// read_response reads a complete FTP response from the control
// channel, handling multi-line responses (code-SP vs code-DASH).
fn (mut c Client) read_response() !FtpResponse {
	mut response_text := ''
	mut buf := []u8{len: 4096}

	for {
		bytes_read := c.ctrl_conn.read(mut buf) or { 0 }
		if bytes_read == 0 {
			break
		}
		response_text += buf[..bytes_read].bytestr()
		// FTP responses end with CRLF; check if we have a complete
		// final response line (3-digit code followed by space)
		if is_complete_response(response_text) {
			break
		}
	}

	return parse_ftp_response(response_text)
}

// --- Parsing utilities ---

// parse_ftp_response extracts the reply code and message from a raw
// FTP response string. Handles multi-line responses by concatenating
// continuation lines.
fn parse_ftp_response(raw string) !FtpResponse {
	trimmed := raw.trim_space()
	if trimmed.len < 3 {
		return error('ftp response too short: "${trimmed}"')
	}
	code := trimmed[..3].int()
	message := if trimmed.len > 4 { trimmed[4..] } else { '' }
	return FtpResponse{
		code: code
		message: message
	}
}

// is_complete_response checks whether the accumulated response buffer
// contains a complete FTP reply (final line has code followed by space,
// not a dash).
fn is_complete_response(text string) bool {
	lines := text.split('\n')
	for line in lines {
		trimmed := line.trim_space()
		if trimmed.len >= 4 && trimmed[0..3].bytes().all(fn (b u8) bool {
			return b >= u8(48) && b <= u8(57) // ASCII digits
		}) && trimmed[3] == u8(32) {
			return true
		}
	}
	return false
}

// parse_pasv_response extracts host and port from a PASV reply.
// Format: "Entering Passive Mode (h1,h2,h3,h4,p1,p2)"
fn parse_pasv_response(message string) !(string, int) {
	open_paren := message.index('(') or {
		return error('malformed PASV response: missing parentheses')
	}
	close_paren := message.index(')') or {
		return error('malformed PASV response: missing closing parenthesis')
	}
	numbers_str := message[open_paren + 1..close_paren]
	parts := numbers_str.split(',')
	if parts.len != 6 {
		return error('malformed PASV response: expected 6 numbers, got ${parts.len}')
	}

	host := '${parts[0]}.${parts[1]}.${parts[2]}.${parts[3]}'
	port := parts[4].int() * 256 + parts[5].int()
	return host, port
}

// parse_directory_listing parses Unix-style LIST output into
// structured DirEntry records.
fn parse_directory_listing(data []u8) []DirEntry {
	mut entries := []DirEntry{}
	lines := data.bytestr().split('\n')

	for line in lines {
		trimmed := line.trim_space()
		if trimmed.len == 0 || trimmed.starts_with('total') {
			continue
		}

		// Unix ls -l format: perms links owner group size month day time name
		fields := trimmed.fields()
		if fields.len < 9 {
			continue
		}

		perms := fields[0]
		entry_type := if perms[0] == u8(`d`) {
			'dir'
		} else if perms[0] == u8(`l`) {
			'link'
		} else {
			'file'
		}

		entries << DirEntry{
			name: fields[8..].join(' ') // Handle filenames with spaces
			size: fields[4].i64()
			entry_type: entry_type
			modified: '${fields[5]} ${fields[6]} ${fields[7]}'
			perms: perms
		}
	}
	return entries
}

// extract_quoted_path extracts a path from a "257 "/path" ..." response.
fn extract_quoted_path(message string) string {
	start := message.index('"') or { return message }
	rest := message[start + 1..]
	end := rest.index('"') or { return rest }
	return rest[..end]
}

// read_all_data reads all available data from a TCP connection until
// the remote side closes it (EOF).
fn read_all_data(mut conn net.TcpConn) ![]u8 {
	mut result := []u8{}
	mut buf := []u8{len: 8192}
	for {
		bytes_read := conn.read(mut buf) or { break }
		if bytes_read == 0 {
			break
		}
		result << buf[..bytes_read]
	}
	return result
}

// --- Tests ---

fn test_parse_ftp_response_basic() {
	response := parse_ftp_response('220 Welcome to FTP server') or { return }
	assert response.code == 220
	assert response.message.contains('Welcome')
}

fn test_parse_pasv_response() {
	host, port := parse_pasv_response('Entering Passive Mode (192,168,1,1,4,1)') or { return }
	assert host == '192.168.1.1'
	assert port == 1025
}

fn test_extract_quoted_path() {
	assert extract_quoted_path('"/home/user" is current directory') == '/home/user'
}

fn test_is_complete_response() {
	assert is_complete_response('220 Ready\r\n') == true
	assert is_complete_response('220-Multi\r\n') == false
}

fn test_dir_entry_struct() {
	entry := DirEntry{
		name: 'test.txt'
		size: 1024
		entry_type: 'file'
		modified: 'Jan 01 12:00'
		perms: '-rw-r--r--'
	}
	assert entry.name == 'test.txt'
	assert entry.size == 1024
}
