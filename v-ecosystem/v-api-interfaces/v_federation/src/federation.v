// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Federation protocol connector for SAML/OIDC/CAS identity federation
// Author: Jonathan D.A. Jewell
//
// Identity federation client supporting SAML 2.0, OpenID Connect (OIDC), and CAS.
// Provides IdP/SP registration, SAML AuthnRequest generation, OIDC token claim
// validation, session management, and binding/flow enumeration.
//
// Standards covered:
//   - SAML 2.0 (OASIS sstc-saml-core-errata-2.0)
//   - OpenID Connect 1.0 (openid.net/specs/openid-connect-core-1_0.html)
//   - CAS 3.0 (apereo.github.io/cas/protocol)
//
// Security notes:
//   - SAML responses must be validated against the IdP's signing certificate.
//   - OIDC ID tokens must be verified with RS256/ES256; this module validates
//     claim presence only — signature verification requires a JWK client.
//   - Sessions have a configurable expiry; expired sessions must be rejected.

module federation

import time
import crypto.sha256
import encoding.base64

// --- Protocol enumerations ---

// FederationProtocol identifies the identity federation standard in use.
pub enum FederationProtocol {
	saml2  // SAML 2.0 — XML-based, widely deployed in enterprise
	oidc   // OpenID Connect 1.0 — JSON/JWT, built on OAuth 2.0
	cas    // Central Authentication Service 3.0 — ticket-based
}

// SamlBinding identifies the SAML 2.0 protocol binding for message transport.
pub enum SamlBinding {
	post      // HTTP POST binding — form-encoded XML in HTML form
	redirect  // HTTP Redirect binding — base64+deflate in query string
	artifact  // HTTP Artifact binding — reference retrieved from IdP
}

// OidcFlow identifies the OAuth 2.0/OIDC authorisation flow.
pub enum OidcFlow {
	authorization_code  // Standard web app flow (most secure)
	client_credentials  // Machine-to-machine (no user involved)
	device              // Device authorisation grant (RFC 8628)
}

// --- Identity provider and service provider ---

// IdentityProvider describes a federated identity provider.
pub struct IdentityProvider {
pub:
	entity_id    string           // Globally unique IdP identifier (URI)
	sso_url      string           // Single Sign-On endpoint URL
	protocol     FederationProtocol
	binding      SamlBinding      // Preferred binding (SAML only)
	metadata_url string           // URL of IdP metadata XML or OIDC discovery doc
	issuer       string           // Token/assertion issuer claim value
}

// ServiceProvider describes this application as a SAML/OIDC service provider.
pub struct ServiceProvider {
pub:
	entity_id    string   // SP entity ID (URI)
	acs_url      string   // Assertion Consumer Service URL (SAML POST endpoint)
	audience     string   // Expected audience in assertions/tokens
	redirect_uri string   // OIDC redirect URI
}

// --- Session ---

// FederationSession holds authenticated session state for a federated user.
pub struct FederationSession {
pub:
	session_id    string              // Unique session identifier
	user_id       string              // Subject/NameID from the IdP
	idp_entity_id string              // Entity ID of the authenticating IdP
	attributes    map[string]string   // Assertion attributes (email, groups, etc.)
	expires_unix  i64                 // Unix timestamp; session is invalid after this
pub mut:
	active        bool                // True while session is live
}

// is_expired returns true if the session has passed its expiry time.
pub fn (s &FederationSession) is_expired() bool {
	return time.now().unix() > s.expires_unix
}

// --- OIDC claims ---

// OidcIdTokenClaims holds the minimum required claims for an OIDC ID token.
pub struct OidcIdTokenClaims {
pub:
	iss string   // Issuer — must match expected IdP issuer
	sub string   // Subject — unique user identifier at the issuer
	aud string   // Audience — must contain SP client_id
	exp i64      // Expiry — Unix timestamp; reject if in the past
	iat i64      // Issued At — Unix timestamp
}

// --- Federation client ---

// FederationConfig holds federation client parameters.
pub struct FederationConfig {
pub:
	instance_url string   // This service's base URL
	client_id    string   // OIDC client ID / SAML SP entity ID
	user_agent   string = 'v-federation/0.1.0'
}

// FederationClient manages identity federation flows.
pub struct FederationClient {
mut:
	config   FederationConfig
	idps     map[string]IdentityProvider // Keyed by entity_id
	sessions map[string]FederationSession
}

// new_federation_client creates a new federation client.
pub fn new_federation_client(config FederationConfig) &FederationClient {
	return &FederationClient{
		config:   config
		idps:     map[string]IdentityProvider{}
		sessions: map[string]FederationSession{}
	}
}

// register_idp registers an identity provider by entity_id.
pub fn (mut c FederationClient) register_idp(idp IdentityProvider) ! {
	if idp.entity_id.len == 0 {
		return error('IdP entity_id must not be empty')
	}
	if idp.sso_url.len == 0 {
		return error('IdP sso_url must not be empty')
	}
	if !idp.sso_url.starts_with('https://') {
		return error('IdP sso_url must use HTTPS: ${idp.sso_url}')
	}
	c.idps[idp.entity_id] = idp
	println('[federation] registered IdP ${idp.entity_id} (${idp.protocol})')
}

// --- SAML 2.0 ---

// build_saml_authn_request generates a minimal SAML 2.0 AuthnRequest XML
// targeting the given IdP.  The request ID is derived from a SHA-256 hash
// of the SP entity_id and current timestamp for uniqueness.
// Returns an error if the IdP is not registered or has no SSO URL.
pub fn (c &FederationClient) build_saml_authn_request(idp_entity_id string, sp ServiceProvider) !string {
	if idp_entity_id !in c.idps {
		return error('IdP "${idp_entity_id}" is not registered')
	}
	idp := c.idps[idp_entity_id]
	if idp.sso_url.len == 0 {
		return error('IdP "${idp_entity_id}" has no SSO URL')
	}
	now_str := time.now().format_ss()
	// Derive a stable request ID from SP entity_id + timestamp
	hash_input := '${sp.entity_id}:${now_str}'.bytes()
	hash_bytes := sha256.sum(hash_input)
	req_id := '_' + base64.url_encode(hash_bytes)[0..16]
	return '<?xml version="1.0" encoding="UTF-8"?>' +
		'<samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" ' +
		'xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" ' +
		'ID="${req_id}" Version="2.0" IssueInstant="${now_str}" ' +
		'Destination="${idp.sso_url}" ' +
		'AssertionConsumerServiceURL="${sp.acs_url}" ' +
		'ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST">' +
		'<saml:Issuer>${sp.entity_id}</saml:Issuer>' +
		'</samlp:AuthnRequest>'
}

// parse_saml_response_issuer extracts the <saml:Issuer> value from a SAML
// response XML string.  This is a text-search based extraction — production
// code should use a proper XML parser.
// Returns an error if no Issuer element is found.
pub fn parse_saml_response_issuer(saml_xml string) !string {
	open_tag := '<saml:Issuer>'
	close_tag := '</saml:Issuer>'
	start := saml_xml.index(open_tag) or {
		return error('SAML response contains no <saml:Issuer> element')
	}
	content_start := start + open_tag.len
	end := saml_xml.index_after(close_tag, content_start) or {
		return error('SAML response has unclosed <saml:Issuer> element')
	}
	issuer := saml_xml[content_start..end]
	if issuer.len == 0 {
		return error('SAML <saml:Issuer> element is empty')
	}
	return issuer
}

// --- OIDC ---

// validate_oidc_id_token_claims checks that all required OIDC ID token claims
// are present and non-empty, and that the token has not expired.
// This validates structure only — cryptographic signature verification is
// the caller's responsibility (use a JWK/JWKS client).
pub fn validate_oidc_id_token_claims(claims OidcIdTokenClaims) ! {
	if claims.iss.len == 0 {
		return error('OIDC ID token missing required claim: iss')
	}
	if claims.sub.len == 0 {
		return error('OIDC ID token missing required claim: sub')
	}
	if claims.aud.len == 0 {
		return error('OIDC ID token missing required claim: aud')
	}
	if claims.exp == 0 {
		return error('OIDC ID token missing required claim: exp')
	}
	now := time.now().unix()
	if now > claims.exp {
		return error('OIDC ID token has expired (exp=${claims.exp}, now=${now})')
	}
}

// --- Session management ---

// create_session creates and registers a new federation session.
pub fn (mut c FederationClient) create_session(user_id string, idp_entity_id string, attrs map[string]string, ttl_secs i64) FederationSession {
	sid := 'sess-${user_id}-${time.now().unix()}'
	sess := FederationSession{
		session_id:    sid
		user_id:       user_id
		idp_entity_id: idp_entity_id
		attributes:    attrs
		expires_unix:  time.now().unix() + ttl_secs
		active:        true
	}
	c.sessions[sid] = sess
	return sess
}

// validate_session returns the session if it exists and has not expired.
pub fn (c &FederationClient) validate_session(session_id string) !FederationSession {
	if session_id !in c.sessions {
		return error('session "${session_id}" not found')
	}
	sess := c.sessions[session_id]
	if sess.is_expired() {
		return error('session "${session_id}" has expired')
	}
	return sess
}

// --- ActivityPub / WebFinger (retained from prior version) ---

// encode_webfinger_query builds the WebFinger query URL for a resource.
// Format: https://{host}/.well-known/webfinger?resource={encoded}
pub fn encode_webfinger_query(resource string) string {
	encoded := resource.replace('@', '%40').replace(':', '%3A')
	parts := resource.split('@')
	host := if parts.len == 2 { parts[1] } else { 'unknown' }
	return 'https://${host}/.well-known/webfinger?resource=${encoded}'
}

// --- Tests ---

fn test_idp_url_validation() {
	mut client := new_federation_client(FederationConfig{})
	client.register_idp(IdentityProvider{
		entity_id:    'https://idp.example.com'
		sso_url:      'http://idp.example.com/sso'  // HTTP — should be rejected
		protocol:     .saml2
		binding:      .post
		metadata_url: ''
		issuer:       ''
	}) or {
		assert err.str().contains('HTTPS')
		return
	}
	assert false, 'expected HTTPS enforcement error'
}

fn test_saml_authn_request_contains_issuer() {
	mut client := new_federation_client(FederationConfig{})
	client.register_idp(IdentityProvider{
		entity_id:    'https://idp.corp.example'
		sso_url:      'https://idp.corp.example/sso'
		protocol:     .saml2
		binding:      .post
		metadata_url: ''
		issuer:       ''
	}) or { panic(err) }
	sp := ServiceProvider{
		entity_id:    'https://app.example.com/sp'
		acs_url:      'https://app.example.com/acs'
		audience:     'https://app.example.com/sp'
		redirect_uri: ''
	}
	xml := client.build_saml_authn_request('https://idp.corp.example', sp) or { panic(err) }
	assert xml.contains('<saml:Issuer>')
	assert xml.contains('https://app.example.com/sp')
	assert xml.contains('AuthnRequest')
}

fn test_expired_session_detection() {
	mut client := new_federation_client(FederationConfig{})
	// Create a session that expired 10 seconds ago
	past_ttl := i64(-10) // negative TTL places expiry in the past
	sess := client.create_session('user@example.com', 'https://idp.example', map[string]string{}, past_ttl)
	client.validate_session(sess.session_id) or {
		assert err.str().contains('expired')
		return
	}
	assert false, 'expected expired session error'
}

fn test_oidc_claims_validation_missing_sub() {
	claims := OidcIdTokenClaims{
		iss: 'https://idp.example.com'
		sub: ''  // missing
		aud: 'my-client-id'
		exp: time.now().unix() + 3600
		iat: time.now().unix()
	}
	validate_oidc_id_token_claims(claims) or {
		assert err.str().contains('sub')
		return
	}
	assert false, 'expected missing sub error'
}

fn test_parse_saml_response_issuer() {
	xml := '<samlp:Response><saml:Issuer>https://idp.example.com</saml:Issuer></samlp:Response>'
	issuer := parse_saml_response_issuer(xml) or { panic(err) }
	assert issuer == 'https://idp.example.com'
}

fn test_parse_saml_response_issuer_missing() {
	parse_saml_response_issuer('<samlp:Response></samlp:Response>') or {
		assert err.str().contains('no <saml:Issuer>')
		return
	}
	assert false
}
