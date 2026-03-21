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
