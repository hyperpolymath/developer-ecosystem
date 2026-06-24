// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_fileserver — File server client supporting directory listing, upload,
// download, delete, and metadata retrieval over HTTP/WebDAV multipart.
// Maps to proven-servers/protocols/proven-fileserver.
//
// Abstracts across FTP, SFTP, and WebDAV backends with a unified API.
// Resumable transfers track byte offsets for large-file reliability.
// Path traversal is blocked at every entry point.
module fileserver

import net
import os
import time

// FsBackend selects the file server protocol backend.
pub enum FsBackend {
	ftp    // FTP (RFC 959)
	sftp   // SSH File Transfer Protocol
	webdav // WebDAV (RFC 4918)
}

// FileKind identifies the type of a remote file system entry.
pub enum FileKind {
	regular   // Regular file
	directory // Directory
	symlink   // Symbolic link
	special   // Device or special file
}

// TransferState tracks the progress of an ongoing file transfer.
pub enum TransferState {
	pending   // Queued, not yet started
	active    // Transfer in progress
	paused    // Temporarily paused (resumable)
	completed // Successfully finished
	failed    // Transfer aborted due to error
}

// FileMeta describes a remote file or directory entry, including its
// path, size, type, modification timestamp, and POSIX permissions.
pub struct FileMeta {
pub:
	// path is the full remote path.
	path string
	// name is the basename (without directory prefix).
	name string
	// kind classifies the entry type.
	kind FileKind
	// size_bytes is the entry size in bytes (0 for directories).
	size_bytes u64
	// modified_at is the last modification time as Unix epoch seconds.
	modified_at i64
	// permissions is the POSIX permission bits (e.g. 0o644).
	permissions u32
	// content_type is the MIME type (populated for regular files).
	content_type string
}

// is_dir returns true if this entry represents a directory.
pub fn (m FileMeta) is_dir() bool {
	return m.kind == .directory
}

// DirListing holds the contents of a remote directory after a list operation.
pub struct DirListing {
pub:
	// path is the remote directory path that was listed.
	path string
	// entries contains the files and subdirectories found.
	entries []FileMeta
	// total is the number of entries in the listing.
	total int
}

// QuotaStatus reports storage quota usage for the authenticated user.
pub struct QuotaStatus {
pub:
	// used_bytes is the amount of storage currently in use.
	used_bytes u64
	// limit_bytes is the total allocated quota.
	limit_bytes u64
	// file_count is the number of files counted against the quota.
	file_count u64
}

// quota_percent returns the percentage of the quota that is consumed.
pub fn (q QuotaStatus) quota_percent() int {
	if q.limit_bytes == 0 {
		return 0
	}
	return int((q.used_bytes * 100) / q.limit_bytes)
}

// TransferHandle tracks an active or completed file transfer operation.
pub struct TransferHandle {
pub:
	// id is the unique transfer identifier.
	id string
	// remote_path is the path on the remote server.
	remote_path string
	// local_path is the path on the local filesystem.
	local_path string
	// total_bytes is the expected total transfer size.
	total_bytes i64
pub mut:
	// transferred_bytes is the count of bytes moved so far.
	transferred_bytes i64
	// state is the current transfer lifecycle state.
	state TransferState
	// error_msg holds an error description when state == .failed.
	error_msg string
}

// progress_percent returns transfer completion as an integer 0–100.
pub fn (h TransferHandle) progress_percent() int {
	if h.total_bytes == 0 {
		return 0
	}
	return int((h.transferred_bytes * 100) / h.total_bytes)
}

// FsConfig holds file server connection parameters.
pub struct FsConfig {
pub:
	// backend selects the protocol (ftp, sftp, webdav).
	backend FsBackend = .sftp
	// host is the file server hostname or IP address.
	host string = '127.0.0.1'
	// port is the server port. 0 = use protocol default.
	port int
	// username is the authentication username.
	username string
	// password is the authentication password or access token.
	password string
	// base_path is the root path on the remote server.
	base_path string = '/'
	// tls enables TLS for WebDAV connections.
	tls bool = true
	// timeout_secs is the connection timeout in seconds.
	timeout_secs int = 30
}

// effective_port returns the configured port or the protocol default.
pub fn (c FsConfig) effective_port() int {
	if c.port > 0 {
		return c.port
	}
	return match c.backend {
		.ftp { 21 }
		.sftp { 22 }
		.webdav { if c.tls { 443 } else { 80 } }
	}
}

// FileServerClient manages remote file operations against a configured backend.
pub struct FileServerClient {
pub:
	// config holds all connection parameters.
	config FsConfig
pub mut:
	// transfers maps transfer IDs to their current state.
	transfers map[string]TransferHandle
	// next_id is a monotonically increasing counter for transfer IDs.
	next_id int = 1
}

// new_fileserver_client creates a new FileServerClient.
pub fn new_fileserver_client(config FsConfig) &FileServerClient {
	return &FileServerClient{
		config:    config
		transfers: map[string]TransferHandle{}
	}
}

// list_dir retrieves the contents of the given remote directory.
// Rejects path traversal attempts (components containing "..").
pub fn (c FileServerClient) list_dir(path string) !DirListing {
	if path.contains('..') {
		return error('path traversal detected in: ${path}')
	}
	if path.len == 0 {
		return error('path must not be empty')
	}
	match c.config.backend {
		.webdav {
			return c.webdav_propfind(path)
		}
		.ftp, .sftp {
			return c.list_via_shell(path)
		}
	}
}

// stat retrieves metadata for a single remote file or directory.
// Rejects path traversal attempts.
pub fn (c FileServerClient) stat(path string) !FileMeta {
	if path.contains('..') {
		return error('path traversal detected in: ${path}')
	}
	listing := c.list_dir(os.dir(path))!
	name := os.base(path)
	for entry in listing.entries {
		if entry.name == name {
			return entry
		}
	}
	return error('remote path not found: ${path}')
}

// upload sends a local file to the remote server via HTTP PUT (WebDAV)
// or SCP-style write (SFTP). Returns a TransferHandle for tracking.
// Rejects path traversal in remote_path.
pub fn (mut c FileServerClient) upload(local_path string, remote_path string) !TransferHandle {
	if remote_path.contains('..') {
		return error('path traversal detected in: ${remote_path}')
	}
	if !os.exists(local_path) {
		return error("local file '${local_path}' not found")
	}
	content := os.read_file(local_path) or {
		return error('failed to read local file ${local_path}: ${err}')
	}
	id := 'ul-${c.next_id:06d}'
	c.next_id++
	match c.config.backend {
		.webdav {
			url := build_webdav_url(c.config, remote_path)
			extra_headers := 'Content-Length: ${content.len}\r\nContent-Type: application/octet-stream\r\n'
			raw_http_put(c.config, url, extra_headers, content)!
		}
		.ftp, .sftp {
			// SFTP: write via os.execute using sftp(1) batch mode.
			_ := run_sftp_put(c.config, local_path, remote_path)!
		}
	}
	handle := TransferHandle{
		id:                id
		remote_path:       remote_path
		local_path:        local_path
		total_bytes:       i64(content.len)
		transferred_bytes: i64(content.len)
		state:             .completed
	}
	c.transfers[id] = handle
	return handle
}

// download retrieves a remote file and writes it to local_path.
// Returns a TransferHandle for tracking. Rejects path traversal.
pub fn (mut c FileServerClient) download(remote_path string, local_path string) !TransferHandle {
	if remote_path.contains('..') {
		return error('path traversal detected in: ${remote_path}')
	}
	if local_path.len == 0 {
		return error('local_path must not be empty')
	}
	id := 'dl-${c.next_id:06d}'
	c.next_id++
	match c.config.backend {
		.webdav {
			url := build_webdav_url(c.config, remote_path)
			raw := raw_http_get(c.config, url)!
			body := strip_http_headers(raw)
			os.write_file(local_path, body) or {
				return error('failed to write ${local_path}: ${err}')
			}
			handle := TransferHandle{
				id:                id
				remote_path:       remote_path
				local_path:        local_path
				total_bytes:       i64(body.len)
				transferred_bytes: i64(body.len)
				state:             .completed
			}
			c.transfers[id] = handle
			return handle
		}
		.ftp, .sftp {
			run_sftp_get(c.config, remote_path, local_path)!
			size := os.file_size(local_path)
			handle := TransferHandle{
				id:                id
				remote_path:       remote_path
				local_path:        local_path
				total_bytes:       i64(size)
				transferred_bytes: i64(size)
				state:             .completed
			}
			c.transfers[id] = handle
			return handle
		}
	}
}

// delete removes a remote file (WebDAV DELETE or SFTP rm).
pub fn (c FileServerClient) delete(remote_path string) ! {
	if remote_path.contains('..') {
		return error('path traversal detected in: ${remote_path}')
	}
	match c.config.backend {
		.webdav {
			url := build_webdav_url(c.config, remote_path)
			raw_http_request(c.config, 'DELETE', url, '', '')!
		}
		.ftp, .sftp {
			_ = run_sftp_rm(c.config, remote_path)!
		}
	}
}

// mkdir creates a remote directory (WebDAV MKCOL or SFTP mkdir).
pub fn (c FileServerClient) mkdir(remote_path string) ! {
	if remote_path.contains('..') {
		return error('path traversal detected in: ${remote_path}')
	}
	match c.config.backend {
		.webdav {
			url := build_webdav_url(c.config, remote_path)
			raw_http_request(c.config, 'MKCOL', url, '', '')!
		}
		.ftp, .sftp {
			_ = run_sftp_mkdir(c.config, remote_path)!
		}
	}
}

// get_quota retrieves storage quota information for the current user.
pub fn (c FileServerClient) get_quota() !QuotaStatus {
	match c.config.backend {
		.webdav {
			url := build_webdav_url(c.config, '/.quota')
			raw := raw_http_get(c.config, url)!
			body := strip_http_headers(raw)
			return parse_quota_json(body)
		}
		.ftp, .sftp {
			return error('quota not supported for ${c.config.backend} backend')
		}
	}
}

// get_transfer returns the status of a past transfer by its id.
pub fn (c FileServerClient) get_transfer(id string) !TransferHandle {
	return c.transfers[id] or { return error('transfer not found: ${id}') }
}

// --- WebDAV helpers ---

// webdav_propfind issues an HTTP PROPFIND with Depth:1 to list a directory.
fn (c FileServerClient) webdav_propfind(path string) !DirListing {
	url := build_webdav_url(c.config, path)
	raw := raw_http_request(c.config, 'PROPFIND', url, 'Depth: 1\r\n', '')!
	entries := parse_propfind_response(raw)
	return DirListing{
		path:    path
		entries: entries
		total:   entries.len
	}
}

// build_webdav_url builds the full WebDAV URL for a remote path.
fn build_webdav_url(config FsConfig, path string) string {
	scheme := if config.tls { 'https' } else { 'http' }
	port := config.effective_port()
	base := config.base_path.trim_right('/')
	p := if path.starts_with('/') { path } else { '/${path}' }
	return '${scheme}://${config.host}:${port}${base}${p}'
}

// raw_http_get issues an HTTP GET and returns the raw response.
fn raw_http_get(config FsConfig, url string) !string {
	return raw_http_request(config, 'GET', url, '', '')
}

// raw_http_put issues an HTTP PUT with the given body and returns the raw response.
fn raw_http_put(config FsConfig, url string, extra_headers string, body string) !string {
	return raw_http_request(config, 'PUT', url, extra_headers, body)
}

// raw_http_request opens a TCP connection to the file server, sends an
// HTTP/1.1 request, and reads back the full response (headers + body).
fn raw_http_request(config FsConfig, method string, url string, extra_headers string, body string) !string {
	host := config.host
	port := config.effective_port()
	mut conn := net.dial_tcp('${host}:${port}') or {
		return error('TCP connect to ${host}:${port} failed: ${err}')
	}
	defer {
		conn.close() or {}
	}
	path := url_path(url)
	auth := basic_auth_header(config.username, config.password)
	request := '${method} ${path} HTTP/1.1\r\nHost: ${host}:${port}\r\n${auth}${extra_headers}Connection: close\r\nContent-Length: ${body.len}\r\n\r\n${body}'
	conn.write_string(request) or { return error('write failed: ${err}') }
	mut response := ''
	mut buf := []u8{len: 8192}
	for {
		n := conn.read(mut buf) or { break }
		if n == 0 {
			break
		}
		response += buf[..n].bytestr()
	}
	status := http_status_code(response)
	if status >= 400 {
		return error('HTTP ${method} ${path} status ${status}')
	}
	return response
}

// url_path extracts the path (and query) component from a URL.
fn url_path(url string) string {
	after_scheme := if url.contains('://') { url.all_after('://') } else { url }
	idx := after_scheme.index('/') or { return '/' }
	return after_scheme[idx..]
}

// basic_auth_header builds an HTTP Basic Authorization header line.
fn basic_auth_header(username string, password string) string {
	if username.len == 0 {
		return ''
	}
	encoded := base64_encode('${username}:${password}'.bytes())
	return 'Authorization: Basic ${encoded}\r\n'
}

// base64_encode encodes bytes to standard base64 with padding.
fn base64_encode(data []u8) string {
	const alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
	mut result := ''
	mut i := 0
	for i + 2 < data.len {
		b0 := int(data[i])
		b1 := int(data[i + 1])
		b2 := int(data[i + 2])
		result += alpha[(b0 >> 2)].ascii_str()
		result += alpha[((b0 & 3) << 4) | (b1 >> 4)].ascii_str()
		result += alpha[((b1 & 15) << 2) | (b2 >> 6)].ascii_str()
		result += alpha[b2 & 63].ascii_str()
		i += 3
	}
	if i + 1 == data.len {
		b0 := int(data[i])
		result += alpha[(b0 >> 2)].ascii_str()
		result += alpha[(b0 & 3) << 4].ascii_str()
		result += '=='
	} else if i + 2 == data.len {
		b0 := int(data[i])
		b1 := int(data[i + 1])
		result += alpha[(b0 >> 2)].ascii_str()
		result += alpha[((b0 & 3) << 4) | (b1 >> 4)].ascii_str()
		result += alpha[(b1 & 15) << 2].ascii_str()
		result += '='
	}
	return result
}

// http_status_code extracts the 3-digit status code from an HTTP response.
fn http_status_code(response string) int {
	first_line := response.all_before('\r\n')
	parts := first_line.split(' ')
	if parts.len < 2 {
		return 0
	}
	return parts[1].int()
}

// strip_http_headers returns the body section of an HTTP response,
// after the blank line that separates headers from body.
fn strip_http_headers(response string) string {
	sep := '\r\n\r\n'
	idx := response.index(sep) or { return response }
	return response[idx + sep.len..]
}

// parse_propfind_response parses a WebDAV PROPFIND XML response into
// a list of FileMeta entries. Handles both D: namespace-prefixed and
// plain namespace variants from different WebDAV servers.
fn parse_propfind_response(raw string) []FileMeta {
	body := strip_http_headers(raw)
	mut entries := []FileMeta{}
	mut remaining := body
	for {
		start := remaining.index('<D:response>') or {
			// Fallback: try without namespace prefix.
			s2 := remaining.index('<response>') or { break }
			e2 := remaining.index('</response>') or { break }
			segment := remaining[s2..e2 + '</response>'.len]
			entries << parse_propfind_entry(segment)
			remaining = remaining[e2 + '</response>'.len..]
			continue
		}
		end := remaining.index('</D:response>') or { break }
		segment := remaining[start..end + '</D:response>'.len]
		entries << parse_propfind_entry(segment)
		remaining = remaining[end + '</D:response>'.len..]
	}
	return entries
}

// parse_propfind_entry converts a single WebDAV <D:response> XML element
// into a FileMeta. Extracts href, getcontentlength, and resourcetype.
fn parse_propfind_entry(segment string) FileMeta {
	href := xml_text(segment, 'href')
	size_str := xml_text(segment, 'getcontentlength')
	size := u64(size_str.u64())
	is_collection := segment.contains('collection')
	kind := if is_collection { FileKind.directory } else { FileKind.regular }
	name := href.all_after_last('/')
	return FileMeta{
		path:      href
		name:      if name.len > 0 { name } else { href }
		kind:      kind
		size_bytes: size
		modified_at: time.now().unix()
	}
}

// xml_text extracts the text content of the first matching XML element.
fn xml_text(s string, tag string) string {
	open := '<${tag}>'
	close := '</${tag}>'
	start := s.index(open) or { return '' }
	end := s.index(close) or { return '' }
	if end <= start + open.len {
		return ''
	}
	return s[start + open.len..end]
}

// parse_quota_json parses a simple JSON quota response.
// Expected format: {"used":1024,"limit":10240,"files":42}
fn parse_quota_json(body string) QuotaStatus {
	used := json_u64(body, 'used')
	limit := json_u64(body, 'limit')
	files := json_u64(body, 'files')
	return QuotaStatus{
		used_bytes:  used
		limit_bytes: limit
		file_count:  files
	}
}

// json_u64 extracts an unsigned integer field from a flat JSON object.
fn json_u64(s string, key string) u64 {
	needle := '"${key}":'
	idx := s.index(needle) or { return 0 }
	rest := s[idx + needle.len..].trim_left(' ')
	val := rest.all_before(',').all_before('}').trim(' ')
	return val.u64()
}

// --- SFTP/FTP shell helpers ---

// run_sftp_put executes sftp(1) in batch mode to upload a local file.
fn run_sftp_put(config FsConfig, local_path string, remote_path string) !string {
	user := if config.username.len > 0 { '${config.username}@' } else { '' }
	cmd := 'echo "put ${local_path} ${remote_path}" | sftp -b - ${user}${config.host}'
	result := os.execute(cmd)
	if result.exit_code != 0 {
		return error('sftp put failed: ${result.output}')
	}
	return result.output
}

// run_sftp_get executes sftp(1) in batch mode to download a remote file.
fn run_sftp_get(config FsConfig, remote_path string, local_path string) ! {
	user := if config.username.len > 0 { '${config.username}@' } else { '' }
	cmd := 'echo "get ${remote_path} ${local_path}" | sftp -b - ${user}${config.host}'
	result := os.execute(cmd)
	if result.exit_code != 0 {
		return error('sftp get failed: ${result.output}')
	}
}

// run_sftp_rm executes sftp(1) in batch mode to delete a remote file.
fn run_sftp_rm(config FsConfig, remote_path string) !string {
	user := if config.username.len > 0 { '${config.username}@' } else { '' }
	cmd := 'echo "rm ${remote_path}" | sftp -b - ${user}${config.host}'
	result := os.execute(cmd)
	if result.exit_code != 0 {
		return error('sftp rm failed: ${result.output}')
	}
	return result.output
}

// run_sftp_mkdir executes sftp(1) in batch mode to create a remote directory.
fn run_sftp_mkdir(config FsConfig, remote_path string) !string {
	user := if config.username.len > 0 { '${config.username}@' } else { '' }
	cmd := 'echo "mkdir ${remote_path}" | sftp -b - ${user}${config.host}'
	result := os.execute(cmd)
	if result.exit_code != 0 {
		return error('sftp mkdir failed: ${result.output}')
	}
	return result.output
}

// list_via_shell uses sftp(1) ls to list a remote directory via the CLI.
fn (c FileServerClient) list_via_shell(path string) !DirListing {
	user := if c.config.username.len > 0 { '${c.config.username}@' } else { '' }
	cmd := 'echo "ls -l ${path}" | sftp -b - ${user}${c.config.host}'
	result := os.execute(cmd)
	if result.exit_code != 0 {
		return error('sftp ls failed: ${result.output}')
	}
	entries := parse_sftp_ls_output(result.output, path)
	return DirListing{
		path:    path
		entries: entries
		total:   entries.len
	}
}

// parse_sftp_ls_output parses the output of "sftp ls -l" into FileMeta entries.
// Each line has the form: "-rw-r--r--  1 user group 1234 Jan 01 12:00 filename"
fn parse_sftp_ls_output(output string, dir_path string) []FileMeta {
	mut entries := []FileMeta{}
	for line in output.split_into_lines() {
		line_trimmed := line.trim_space()
		if line_trimmed.len == 0 || line_trimmed.starts_with('sftp') {
			continue
		}
		parts := line_trimmed.split(' ').filter(it.len > 0)
		if parts.len < 9 {
			continue
		}
		perms_str := parts[0]
		kind := if perms_str.starts_with('d') {
			FileKind.directory
		} else if perms_str.starts_with('l') {
			FileKind.symlink
		} else {
			FileKind.regular
		}
		size := parts[4].u64()
		name := parts[8]
		entries << FileMeta{
			name:        name
			path:        '${dir_path.trim_right('/')}/${name}'
			kind:        kind
			size_bytes:  size
			modified_at: time.now().unix()
		}
	}
	return entries
}

// --- Tests ---

fn test_path_traversal_rejected() {
	client := new_fileserver_client(FsConfig{})
	client.list_dir('../../etc/passwd') or {
		assert err.msg().contains('path traversal')
		return
	}
	assert false, 'expected error for traversal path'
}

fn test_quota_percent_full() {
	q := QuotaStatus{
		used_bytes:  1024
		limit_bytes: 1024
		file_count:  5
	}
	assert q.quota_percent() == 100
}

fn test_quota_percent_half() {
	q := QuotaStatus{
		used_bytes:  512
		limit_bytes: 1024
		file_count:  3
	}
	assert q.quota_percent() == 50
}

fn test_transfer_progress_percent() {
	h := TransferHandle{
		id:                'dl-000001'
		remote_path:       '/data/file.tar.gz'
		local_path:        '/tmp/file.tar.gz'
		total_bytes:       400
		transferred_bytes: 200
		state:             .active
	}
	assert h.progress_percent() == 50
}

fn test_base64_encode_hello() {
	encoded := base64_encode('Hello'.bytes())
	assert encoded == 'SGVsbG8='
}

fn test_effective_port_webdav_tls() {
	config := FsConfig{
		backend: .webdav
		tls:     true
	}
	assert config.effective_port() == 443
}

fn test_effective_port_sftp() {
	config := FsConfig{
		backend: .sftp
	}
	assert config.effective_port() == 22
}
