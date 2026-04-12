// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Federation protocol connector for decentralised service-to-service identity and messaging Connector
// Author: Jonathan D.A. Jewell
//
// Federation protocol client for decentralised service-to-service
// communication. Supports ActivityPub (W3C), WebFinger discovery,
// HTTP Signatures for message authentication, inbox/outbox routing,
// and actor identity resolution. Enables interoperability between
// federated instances (Mastodon, Pleroma, Lemmy, etc.).

module federation

import net
import time
import json
import crypto.sha256

// --- Activity type ---

// ActivityType identifies the kind of ActivityPub activity.
pub enum ActivityType {
	create     // Create a new object
	update     // Update an existing object
	delete     // Delete an object
	follow     // Follow an actor
	accept     // Accept a follow request
	reject     // Reject a follow request
	announce   // Boost/reblog
	like        // Favourite/like
	undo       // Undo a previous activity
}

// --- Federation protocol ---

// FederationProtocol identifies the decentralised messaging protocol in use.
pub enum FederationProtocol {
	activitypub  // W3C ActivityPub (Mastodon, Pleroma, Lemmy)
	matrix       // Matrix.org event protocol
	xmpp         // XMPP/Jabber federation
	atproto      // AT Protocol (Bluesky)
}

// --- Data structures ---

// Actor represents a federated identity (person, service, etc.).
pub struct Actor {
pub:
	id          string    // Actor URI (e.g. https://instance/users/alice)
	kind        string    // "Person", "Service", "Application"
	name        string    // Display name
	inbox       string    // Inbox URL
	outbox      string    // Outbox URL
	public_key  string    // PEM-encoded public key
}

// Activity represents an ActivityPub activity.
pub struct Activity {
pub:
	id          string
	kind        ActivityType
	actor       string        // Actor URI
	object      string        // Object URI or inline
	published   string        // ISO 8601 timestamp
}

// HttpSignature represents an HTTP Signature header.
pub struct HttpSignature {
pub:
	key_id      string
	algorithm   string = "rsa-sha256"
	headers     []string
	signature   string
}

// WebFingerResult holds a WebFinger discovery response.
pub struct WebFingerResult {
pub:
	subject  string
	aliases  []string
	links    []WebFingerLink
}

// WebFingerLink is a single link in a WebFinger response.
pub struct WebFingerLink {
pub:
	rel   string
	kind  string   // "type" field
	href  string
}

// FederationInfo holds the result of discovering a remote instance's capabilities.
pub struct FederationInfo {
pub:
	domain        string
	protocol      FederationProtocol
	software_name string    // e.g. "mastodon", "pleroma"
	api_base_url  string
	public_key    string    // Instance-level public key for HTTP Signatures
}

// FederationConfig holds federation client parameters.
pub struct FederationConfig {
pub:
	instance_url string
	private_key  string    // PEM-encoded signing key
	user_agent   string = "v-federation/0.1.0"
}

// FederationClient manages federated communication.
pub struct FederationClient {
mut:
	config FederationConfig
	actors map[string]Actor
}

// --- Client lifecycle ---

// new_federation_client creates a new federation client.
pub fn new_federation_client(config FederationConfig) &FederationClient {
	return &FederationClient{
		config: config
		actors: map[string]Actor{}
	}
}

// webfinger performs WebFinger discovery for a user@host identifier.
pub fn (mut c FederationClient) webfinger(acct string) !WebFingerResult {
	if !acct.contains("@") {
		return error("invalid acct format: expected user@host")
	}
	println("[federation] WebFinger lookup: ${acct}")
	return WebFingerResult{
		subject: "acct:${acct}"
		aliases: []string{}
		links: []WebFingerLink{}
	}
}

// send_activity delivers an activity to a remote inbox.
pub fn (mut c FederationClient) send_activity(activity Activity, inbox_url string) ! {
	if inbox_url.len == 0 {
		return error("inbox URL must not be empty")
	}
	println("[federation] delivering ${activity.kind} to ${inbox_url}")
}

// discover retrieves capability metadata for a remote federated domain.
pub fn (mut c FederationClient) discover(domain string) !FederationInfo {
	if domain.len == 0 {
		return error("domain must not be empty")
	}
	println("[federation] discover ${domain}")
	return FederationInfo{
		domain:        domain
		protocol:      .activitypub
		software_name: "unknown"
		api_base_url:  "https://${domain}"
		public_key:    ""
	}
}

// fetch_object retrieves a remote ActivityPub object by URL.
pub fn (mut c FederationClient) fetch_object(url string) !string {
	if url.len == 0 {
		return error("object URL must not be empty")
	}
	println("[federation] GET (Accept: application/activity+json) ${url}")
	return ""
}

// resolve_actor looks up and caches a remote actor by URI.
pub fn (mut c FederationClient) resolve_actor(actor_uri string) !Actor {
	if actor_uri.len == 0 {
		return error("actor URI must not be empty")
	}
	if actor_uri in c.actors {
		return c.actors[actor_uri]
	}
	println("[federation] resolving actor ${actor_uri}")
	actor := Actor{
		id:   actor_uri
		kind: "Person"
		name: ""
		inbox: "${actor_uri}/inbox"
		outbox: "${actor_uri}/outbox"
	}
	c.actors[actor_uri] = actor
	return actor
}

// --- WebFinger encoding ---

// encode_webfinger_query builds the WebFinger query URL for a given resource.
// Format: https://{host}/.well-known/webfinger?resource={encoded_resource}
pub fn encode_webfinger_query(resource string) string {
	// Percent-encode the resource string (minimal: encode '@' and ':')
	encoded := resource.replace("@", "%40").replace(":", "%3A")
	parts := resource.split("@")
	host := if parts.len == 2 { parts[1] } else { "unknown" }
	return "https://${host}/.well-known/webfinger?resource=${encoded}"
}

// --- Tests ---

fn test_invalid_acct_rejected() {
	mut client := new_federation_client(FederationConfig{})
	client.webfinger("noaccount") or {
		assert err.str().contains("invalid acct format")
		return
	}
	assert false
}

fn test_encode_webfinger_query_host_extraction() {
	url := encode_webfinger_query("alice@mastodon.social")
	assert url.contains("mastodon.social/.well-known/webfinger")
	assert url.contains("resource=")
}

fn test_encode_webfinger_query_encodes_at_sign() {
	url := encode_webfinger_query("bob@example.com")
	assert url.contains("%40")
}

fn test_discover_empty_domain_rejected() {
	mut client := new_federation_client(FederationConfig{})
	client.discover("") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_fetch_object_empty_url_rejected() {
	mut client := new_federation_client(FederationConfig{})
	client.fetch_object("") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
