// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// ftp_test -- Protocol conformance tests for v_ftp.
// Covers authentication, directory operations, file storage/retrieval,
// deletion, and path resolution.
module v_ftp

// test_command_to_string verifies wire keywords for all FTP commands.
fn test_command_to_string() {
	assert command_to_string(.user) == 'USER'
	assert command_to_string(.pass) == 'PASS'
	assert command_to_string(.cwd) == 'CWD'
	assert command_to_string(.pwd) == 'PWD'
	assert command_to_string(.list) == 'LIST'
	assert command_to_string(.retr) == 'RETR'
	assert command_to_string(.stor) == 'STOR'
	assert command_to_string(.dele) == 'DELE'
	assert command_to_string(.mkd) == 'MKD'
	assert command_to_string(.rmd) == 'RMD'
	assert command_to_string(.type_) == 'TYPE'
	assert command_to_string(.pasv) == 'PASV'
	assert command_to_string(.port) == 'PORT'
	assert command_to_string(.quit) == 'QUIT'
	assert command_to_string(.size) == 'SIZE'
	assert command_to_string(.mdtm) == 'MDTM'
}

// test_authenticate_success verifies successful FTP login.
fn test_authenticate_success() {
	mut server := new_server(21)
	resp := server.authenticate('alice', 'secret')!
	assert resp.code == 230
	assert server.session.authenticated == true
	assert server.session.user == 'alice'
}

// test_authenticate_empty verifies rejection of empty credentials.
fn test_authenticate_empty() {
	mut server := new_server(21)
	resp := server.authenticate('', 'pass')!
	assert resp.code == 530
}

// test_make_dir verifies directory creation.
fn test_make_dir() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	resp := server.make_dir('docs')!
	assert resp.code == 257
	assert '/docs' in server.files
	assert server.files['/docs'].is_dir == true
}

// test_change_dir verifies changing the working directory.
fn test_change_dir() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	_ := server.make_dir('docs')!
	resp := server.change_dir('docs')!
	assert resp.code == 250
	assert server.session.cwd == '/docs'
}

// test_change_dir_not_found verifies error for missing directory.
fn test_change_dir_not_found() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	server.change_dir('nonexistent') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing directory'
}

// test_store_and_retrieve verifies file store and retrieval roundtrip.
fn test_store_and_retrieve() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	resp := server.store_file('test.txt', 'Hello, FTP!')!
	assert resp.code == 226
	content := server.retrieve_file('test.txt')!
	assert content == 'Hello, FTP!'
}

// test_retrieve_not_found verifies error for missing file.
fn test_retrieve_not_found() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	server.retrieve_file('missing.txt') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing file'
}

// test_delete_file verifies file deletion.
fn test_delete_file() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	_ := server.store_file('test.txt', 'data')!
	resp := server.delete_file('test.txt')!
	assert resp.code == 250
	server.retrieve_file('test.txt') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error after deletion'
}

// test_list_dir verifies directory listing.
fn test_list_dir() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	_ := server.store_file('a.txt', 'aaa')!
	_ := server.store_file('b.txt', 'bbb')!
	entries := server.list_dir('/')!
	assert entries.len == 2
}

// test_get_size verifies file size reporting.
fn test_get_size() {
	mut server := new_server(21)
	_ := server.authenticate('alice', 'secret')!
	_ := server.store_file('data.bin', 'abcdef')!
	sz := server.get_size('data.bin')!
	assert sz == 6
}

// test_not_authenticated verifies operations fail without login.
fn test_not_authenticated() {
	server := new_server(21)
	server.list_dir('/') or {
		assert err.msg().contains('not authenticated')
		return
	}
	assert false, 'expected error for unauthenticated access'
}
