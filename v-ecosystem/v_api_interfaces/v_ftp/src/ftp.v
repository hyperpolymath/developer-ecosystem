// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_ftp -- FTP protocol types and server for the V-Ecosystem.
// Implements file transfer, directory listing, and session management
// per RFC 959. Network I/O is stubbed with TODO markers; all type
// definitions and logic are real.
module v_ftp

import time

// TransferMode represents the FTP data connection mode.
pub enum TransferMode {
	active
	passive
}

// TransferType represents the FTP transfer representation type.
pub enum TransferType {
	ascii
	binary
}

// Command enumerates the FTP commands supported by this connector.
pub enum Command {
	user
	pass
	cwd
	pwd
	list
	retr
	stor
	dele
	mkd
	rmd
	type_
	pasv
	port
	quit
	size
	mdtm
}

// command_to_string returns the FTP wire keyword for a Command.
pub fn command_to_string(cmd Command) string {
	return match cmd {
		.user { 'USER' }
		.pass { 'PASS' }
		.cwd { 'CWD' }
		.pwd { 'PWD' }
		.list { 'LIST' }
		.retr { 'RETR' }
		.stor { 'STOR' }
		.dele { 'DELE' }
		.mkd { 'MKD' }
		.rmd { 'RMD' }
		.type_ { 'TYPE' }
		.pasv { 'PASV' }
		.port { 'PORT' }
		.quit { 'QUIT' }
		.size { 'SIZE' }
		.mdtm { 'MDTM' }
	}
}

// FtpResponse represents an FTP server reply with a three-digit code
// and a human-readable message.
pub struct FtpResponse {
pub:
	// code is the three-digit FTP reply code.
	code int
	// message is the human-readable text.
	message string
}

// FtpFile represents a file or directory entry in the virtual filesystem.
pub struct FtpFile {
pub:
	// name is the file or directory name.
	name string
	// size is the file size in bytes (0 for directories).
	size int
	// is_dir indicates whether this entry is a directory.
	is_dir bool
	// modified is the last modification time.
	modified time.Time
	// content holds the file data (empty for directories).
	content string
}

// FtpSession represents the state of an active FTP client session.
pub struct FtpSession {
pub mut:
	// user is the authenticated username.
	user string
	// cwd is the current working directory path.
	cwd string
	// transfer_mode is the active or passive transfer mode.
	transfer_mode TransferMode
	// transfer_type is the ASCII or binary transfer type.
	transfer_type TransferType
	// authenticated indicates whether the session is logged in.
	authenticated bool
}

// FtpServer holds the state for an FTP server instance with an
// in-memory virtual filesystem.
pub struct FtpServer {
pub:
	// port is the TCP port the server listens on (default 21).
	port int
pub mut:
	// session is the current client session state.
	session FtpSession
	// files holds the virtual filesystem entries keyed by full path.
	files map[string]FtpFile
}

// new_server creates a new FtpServer with an empty virtual filesystem
// and a root directory.
pub fn new_server(port int) &FtpServer {
	mut s := &FtpServer{
		port: port
		session: FtpSession{
			cwd: '/'
			transfer_mode: .passive
			transfer_type: .binary
		}
	}
	s.files['/'] = FtpFile{
		name: '/'
		is_dir: true
	}
	return s
}

// authenticate verifies credentials and marks the session as authenticated.
// TODO: Replace with pluggable auth backend; currently accepts any non-empty password.
pub fn (mut s FtpServer) authenticate(user string, password string) !FtpResponse {
	if user.len == 0 || password.len == 0 {
		return FtpResponse{
			code: 530
			message: 'Login incorrect'
		}
	}
	s.session.user = user
	s.session.authenticated = true
	return FtpResponse{
		code: 230
		message: 'User ${user} logged in'
	}
}

// resolve_path resolves a path relative to the current working directory.
// Handles both absolute and relative paths.
fn (s FtpServer) resolve_path(path string) string {
	if path.starts_with('/') {
		return path
	}
	cwd := s.session.cwd
	if cwd == '/' {
		return '/${path}'
	}
	return '${cwd}/${path}'
}

// list_dir returns the entries in the specified directory path.
pub fn (s FtpServer) list_dir(path string) ![]FtpFile {
	if !s.session.authenticated {
		return error('not authenticated')
	}
	resolved := s.resolve_path(path)
	// Verify the directory exists
	dir := s.files[resolved] or { return error('directory not found: ${resolved}') }
	if !dir.is_dir {
		return error('not a directory: ${resolved}')
	}
	// Collect entries whose parent is the resolved path
	prefix := if resolved == '/' { '/' } else { '${resolved}/' }
	mut entries := []FtpFile{}
	for file_path, file in s.files {
		if file_path == resolved {
			continue
		}
		if file_path.starts_with(prefix) {
			// Only include direct children (no nested subdirectory contents)
			remainder := file_path[prefix.len..]
			if !remainder.contains('/') {
				entries << file
			}
		}
	}
	return entries
}

// retrieve_file returns the content of the file at the given path.
pub fn (s FtpServer) retrieve_file(path string) !string {
	if !s.session.authenticated {
		return error('not authenticated')
	}
	resolved := s.resolve_path(path)
	file := s.files[resolved] or { return error('file not found: ${resolved}') }
	if file.is_dir {
		return error('cannot retrieve directory: ${resolved}')
	}
	return file.content
}

// store_file stores content at the given path, creating the file if it
// does not exist or overwriting if it does.
pub fn (mut s FtpServer) store_file(path string, content string) !FtpResponse {
	if !s.session.authenticated {
		return error('not authenticated')
	}
	resolved := s.resolve_path(path)
	// Extract the file name from the path
	parts := resolved.split('/')
	name := parts.last()
	s.files[resolved] = FtpFile{
		name: name
		size: content.len
		is_dir: false
		modified: time.now()
		content: content
	}
	return FtpResponse{
		code: 226
		message: 'Transfer complete'
	}
}

// delete_file removes the file at the given path.
pub fn (mut s FtpServer) delete_file(path string) !FtpResponse {
	if !s.session.authenticated {
		return error('not authenticated')
	}
	resolved := s.resolve_path(path)
	file := s.files[resolved] or { return error('file not found: ${resolved}') }
	if file.is_dir {
		return error('cannot delete directory with DELE; use RMD')
	}
	s.files.delete(resolved)
	return FtpResponse{
		code: 250
		message: 'File deleted'
	}
}

// make_dir creates a new directory at the given path.
pub fn (mut s FtpServer) make_dir(path string) !FtpResponse {
	if !s.session.authenticated {
		return error('not authenticated')
	}
	resolved := s.resolve_path(path)
	if resolved in s.files {
		return error('path already exists: ${resolved}')
	}
	parts := resolved.split('/')
	name := parts.last()
	s.files[resolved] = FtpFile{
		name: name
		is_dir: true
	}
	return FtpResponse{
		code: 257
		message: '"${resolved}" directory created'
	}
}

// change_dir changes the current working directory to the given path.
pub fn (mut s FtpServer) change_dir(path string) !FtpResponse {
	if !s.session.authenticated {
		return error('not authenticated')
	}
	resolved := s.resolve_path(path)
	dir := s.files[resolved] or { return error('directory not found: ${resolved}') }
	if !dir.is_dir {
		return error('not a directory: ${resolved}')
	}
	s.session.cwd = resolved
	return FtpResponse{
		code: 250
		message: 'Directory changed to ${resolved}'
	}
}

// get_size returns the size of the file at the given path in bytes.
pub fn (s FtpServer) get_size(path string) !int {
	if !s.session.authenticated {
		return error('not authenticated')
	}
	resolved := s.resolve_path(path)
	file := s.files[resolved] or { return error('file not found: ${resolved}') }
	if file.is_dir {
		return error('SIZE not applicable to directories')
	}
	return file.size
}
