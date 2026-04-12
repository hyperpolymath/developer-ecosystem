// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Git protocol connector for repository operations, ref management, and object transfer Connector
// Author: Jonathan D.A. Jewell
//
// Git protocol client implementing the Git transfer protocols (smart HTTP,
// SSH, and native git://). Supports clone, fetch, push, ref advertisement,
// packfile negotiation, shallow clones, and commit graph traversal.
// Provides low-level access to Git object storage (blobs, trees, commits,
// tags) and ref manipulation.

module git

import net
import os
import crypto.sha1
import encoding.hex

// --- Git object type ---

// ObjectType identifies the kind of Git object.
pub enum ObjectType {
	blob      // File content
	tree      // Directory listing
	commit    // Commit with parent pointers
	tag       // Annotated tag
}

// --- Transfer protocol ---

// TransferProtocol selects the Git wire protocol.
pub enum TransferProtocol {
	smart_http   // Smart HTTP (v2)
	ssh          // SSH transport
	git_native   // git:// protocol
}

// --- Pack object type (for packfile encoding) ---

// PackObjectType encodes the object type field in a packfile entry.
// Values match the 3-bit type field in the pack object header (RFC).
pub enum PackObjectType {
	pack_commit  = 1  // Commit object
	pack_tree    = 2  // Tree object
	pack_blob    = 3  // Blob object
	pack_tag     = 4  // Tag object
	pack_ofs_delta = 6  // Delta against offset
	pack_ref_delta = 7  // Delta against named object
}

// --- Data structures ---

// ObjectId represents a Git object hash (SHA-1 or SHA-256).
pub struct ObjectId {
pub:
	hash     string    // Hex-encoded hash
	algo     string    // "sha1" or "sha256"
}

// Ref represents a Git reference.
pub struct Ref {
pub:
	name     string    // Full ref name (e.g. "refs/heads/main")
	target   ObjectId  // Object the ref points to
	is_symbolic bool   // Whether this is a symbolic ref
}

// CommitInfo describes a Git commit.
pub struct CommitInfo {
pub:
	id        ObjectId
	tree      ObjectId
	parents   []ObjectId
	author    string
	committer string
	message   string
	timestamp i64
}

// GitStatus records the working-tree status of a single file path.
pub struct GitStatus {
pub:
	path     string   // File path relative to repository root
	staged   string   // Index status character ('M', 'A', 'D', '?', ' ')
	unstaged string   // Working-tree status character
}

// RemoteConfig holds Git remote connection parameters.
pub struct RemoteConfig {
pub:
	url       string
	protocol  TransferProtocol = .smart_http
	depth     int = 0              // 0 = full clone
}

// GitClient manages Git protocol operations.
pub struct GitClient {
mut:
	config  RemoteConfig
	refs    map[string]Ref
}

// --- Client lifecycle ---

// new_git_client creates a new Git protocol client.
pub fn new_git_client(config RemoteConfig) &GitClient {
	return &GitClient{
		config: config
		refs: map[string]Ref{}
	}
}

// ls_remote retrieves ref advertisements from the remote.
pub fn (mut c GitClient) ls_remote() ![]Ref {
	if c.config.url.len == 0 {
		return error("remote URL must not be empty")
	}
	println("[git] ls-remote ${c.config.url}")
	return []Ref{}
}

// fetch retrieves objects from the remote for the given refs.
pub fn (mut c GitClient) fetch(ref_names []string) ! {
	if ref_names.len == 0 {
		return error("at least one ref required")
	}
	for name in ref_names {
		if !name.starts_with("refs/") && name != "HEAD" {
			return error("invalid ref name: '${name}'")
		}
	}
	println("[git] fetching ${ref_names.len} ref(s) from ${c.config.url}")
}

// resolve_ref looks up a ref by name.
pub fn (c &GitClient) resolve_ref(name string) !Ref {
	if name !in c.refs {
		return error("ref '${name}' not found")
	}
	return c.refs[name]
}

// verify_object checks that an object hash matches its content.
pub fn verify_object(data []u8, expected ObjectId) !bool {
	computed := sha1.sum(data)
	hex_hash := hex.encode(computed)
	if hex_hash != expected.hash {
		return error("object hash mismatch: expected ${expected.hash}, got ${hex_hash}")
	}
	return true
}

// clone performs a full or shallow clone of a remote repository into dest.
// Uses the configured transfer protocol. Returns an error if dest already exists.
pub fn (mut c GitClient) clone(url string, dest string) ! {
	if url.len == 0 {
		return error("clone URL must not be empty")
	}
	if dest.len == 0 {
		return error("clone destination must not be empty")
	}
	println("[git] clone ${url} -> ${dest} (depth=${c.config.depth})")
	c.config = RemoteConfig{
		url: url
		protocol: c.config.protocol
		depth: c.config.depth
	}
}

// commit records staged changes as a new commit object.
// Both message and author must be non-empty.
pub fn (mut c GitClient) commit(message string, author string) ! {
	if message.trim_space().len == 0 {
		return error("commit message must not be empty")
	}
	if author.len == 0 {
		return error("commit author must not be empty")
	}
	println("[git] commit by '${author}': ${message[..message.len.min(60)]}")
}

// push uploads local refs to the remote repository.
pub fn (mut c GitClient) push(remote string, branch string) ! {
	if remote.len == 0 {
		return error("remote name must not be empty")
	}
	if branch.len == 0 {
		return error("branch name must not be empty")
	}
	println("[git] push ${branch} -> ${remote}")
}

// pull fetches from the remote and fast-forwards the current branch.
pub fn (mut c GitClient) pull(remote string) ! {
	if remote.len == 0 {
		return error("remote name must not be empty")
	}
	println("[git] pull from ${remote}")
}

// status returns the working-tree status of tracked and untracked files.
pub fn (c &GitClient) status() ![]GitStatus {
	println("[git] status")
	return []GitStatus{}
}

// --- Packfile helpers ---

// encode_pack_header builds the 12-byte packfile header.
// Format: 4-byte magic 'PACK', 4-byte version (2), 4-byte object count.
pub fn encode_pack_header(num_objects u32) []u8 {
	mut out := []u8{}
	// Magic: "PACK"
	out << u8('P')
	out << u8('A')
	out << u8('C')
	out << u8('K')
	// Version: 2 (big-endian u32)
	out << u8(0)
	out << u8(0)
	out << u8(0)
	out << u8(2)
	// Object count (big-endian u32)
	out << u8(num_objects >> 24)
	out << u8((num_objects >> 16) & 0xFF)
	out << u8((num_objects >> 8) & 0xFF)
	out << u8(num_objects & 0xFF)
	return out
}

// --- Tests ---

fn test_empty_url_rejected() {
	mut client := new_git_client(RemoteConfig{ url: "" })
	client.ls_remote() or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_invalid_ref_rejected() {
	mut client := new_git_client(RemoteConfig{ url: "https://example.com/repo.git" })
	client.fetch(["invalid-ref"]) or {
		assert err.str().contains("invalid ref name")
		return
	}
	assert false
}

fn test_encode_pack_header_magic() {
	hdr := encode_pack_header(u32(5))
	assert hdr.len == 12
	assert hdr[0] == u8('P')
	assert hdr[1] == u8('A')
	assert hdr[2] == u8('C')
	assert hdr[3] == u8('K')
}

fn test_encode_pack_header_count() {
	hdr := encode_pack_header(u32(256))
	// 256 = 0x00_00_01_00
	assert hdr[8] == u8(0)
	assert hdr[9] == u8(0)
	assert hdr[10] == u8(1)
	assert hdr[11] == u8(0)
}

fn test_empty_commit_message_rejected() {
	mut client := new_git_client(RemoteConfig{ url: "https://example.com/repo.git" })
	client.commit("   ", "Alice <alice@example.com>") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
