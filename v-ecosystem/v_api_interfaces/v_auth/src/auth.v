// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_auth -- Authentication server protocol types for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-authserver.
// Implements multi-method authentication, token issuance, claims validation,
// and password hashing via HMAC-SHA256.
module v_auth

import crypto.hmac
import crypto.sha256
import encoding.hex
import time

// AuthMethod enumerates supported authentication mechanisms.
pub enum AuthMethod {
	password
	token
	certificate
	oauth2
	saml
	webauthn
	kerberos
}

// auth_method_to_string returns the canonical string label for an AuthMethod.
pub fn auth_method_to_string(m AuthMethod) string {
	return match m {
		.password { 'password' }
		.token { 'token' }
		.certificate { 'certificate' }
		.oauth2 { 'oauth2' }
		.saml { 'saml' }
		.webauthn { 'webauthn' }
		.kerberos { 'kerberos' }
	}
}

// AuthResult enumerates the possible outcomes of an authentication attempt.
pub enum AuthResult {
	granted
	denied
	mfa_required
	expired
	locked
	rate_limited
}

// auth_result_to_string returns the human-readable label for an AuthResult.
pub fn auth_result_to_string(r AuthResult) string {
	return match r {
		.granted { 'GRANTED' }
		.denied { 'DENIED' }
		.mfa_required { 'MFA_REQUIRED' }
		.expired { 'EXPIRED' }
		.locked { 'LOCKED' }
		.rate_limited { 'RATE_LIMITED' }
	}
}

// ClientInfo carries metadata about the client making an authentication request.
pub struct ClientInfo {
pub:
	// ip_address is the originating IP of the client.
	ip_address string
	// user_agent is the HTTP User-Agent or equivalent identifier.
	user_agent string
	// session_id is an optional pre-existing session reference.
	session_id string
}

// AuthRequest encapsulates an incoming authentication attempt.
pub struct AuthRequest {
pub:
	// method selects the authentication mechanism to use.
	method AuthMethod
	// credentials holds the primary secret (password, token, certificate PEM, etc.).
	credentials string
	// username is the identity being authenticated.
	username string
	// client_info carries contextual metadata about the requester.
	client_info ClientInfo
	// mfa_code is an optional multi-factor code when MFA is required.
	mfa_code string
}

// TokenClaims represents the decoded payload of a bearer token, following
// the standard JWT claim names.
pub struct TokenClaims {
pub:
	// sub (subject) identifies the principal.
	sub string
	// iss (issuer) identifies the auth server that issued the token.
	iss string
	// aud (audience) specifies the intended recipients.
	aud string
	// exp (expiration) is the Unix epoch timestamp after which the token is invalid.
	exp i64
	// iat (issued-at) is the Unix epoch timestamp when the token was issued.
	iat i64
	// scopes lists the granted permission scopes.
	scopes []string
}

// AuthResponse is returned by the server after processing an AuthRequest.
pub struct AuthResponse {
pub:
	// result is the authentication outcome.
	result AuthResult
	// token is the bearer token string issued on success.
	token string
	// expires_at is the Unix epoch timestamp when the token expires.
	expires_at i64
	// refresh_token is an opaque string used to obtain a new token.
	refresh_token string
	// claims contains the decoded token payload.
	claims TokenClaims
}

// ProviderConfig holds the configuration for a single authentication provider.
pub struct ProviderConfig {
pub:
	// method identifies which AuthMethod this provider handles.
	method AuthMethod
	// config holds provider-specific key/value settings.
	config map[string]string
}

// AuthServer maintains authentication state including registered providers,
// known credentials, issued tokens, and timing parameters.
pub struct AuthServer {
pub:
	// port is the TCP port the auth server listens on.
	port int
pub mut:
	// providers holds the registered authentication providers.
	providers []ProviderConfig
	// token_ttl is the default token lifetime in seconds.
	token_ttl i64 = 3600
	// credential_store maps username to password hash for the password provider.
	credential_store map[string]string
	// token_store maps issued token strings to their claims.
	token_store map[string]TokenClaims
	// revoked_tokens tracks tokens that have been explicitly revoked.
	revoked_tokens map[string]bool
	// issuer is the identifier placed in the "iss" claim of issued tokens.
	issuer string = 'v_auth'
}

// hmac_secret is the internal key used for HMAC-SHA256 operations.
// In production this MUST be replaced with a securely-generated secret
// loaded from configuration or a secrets manager.
const hmac_secret = 'v_auth_default_hmac_secret_CHANGE_ME'.bytes()

// new_server creates a new AuthServer listening on the given TCP port.
pub fn new_server(port int) &AuthServer {
	return &AuthServer{
		port: port
	}
}

// add_provider registers an authentication provider with the server.
// The provider's method determines which AuthRequests it can handle.
pub fn (mut s AuthServer) add_provider(method AuthMethod, config map[string]string) {
	s.providers << ProviderConfig{
		method: method
		config: config
	}
}

// has_provider returns true if the server has a registered provider for
// the given authentication method.
pub fn (s AuthServer) has_provider(method AuthMethod) bool {
	for p in s.providers {
		if p.method == method {
			return true
		}
	}
	return false
}

// generate_token produces a hex-encoded HMAC-SHA256 token from the
// subject, issuer, and current timestamp. The token is deterministic
// for the same inputs, which simplifies testing.
fn generate_token(subject string, issuer string, timestamp i64) string {
	payload := '${subject}:${issuer}:${timestamp}'
	digest := hmac.new(hmac_secret, payload.bytes(), sha256.sum256, sha256.block_size)
	return hex.encode(digest)
}

// generate_refresh_token produces a refresh token derived from the
// primary token via an additional HMAC round.
fn generate_refresh_token(primary_token string) string {
	digest := hmac.new(hmac_secret, 'refresh:${primary_token}'.bytes(), sha256.sum256,
		sha256.block_size)
	return hex.encode(digest)
}

// authenticate processes an AuthRequest and returns an AuthResponse.
// Currently implements the password and token methods; other methods
// return Denied with a descriptive error.
pub fn (mut s AuthServer) authenticate(req AuthRequest) !AuthResponse {
	// Ensure we have a provider for this method
	if !s.has_provider(req.method) {
		return AuthResponse{
			result: .denied
			token: ''
			expires_at: 0
			refresh_token: ''
			claims: TokenClaims{}
		}
	}

	match req.method {
		.password {
			return s.authenticate_password(req)
		}
		.token {
			return s.authenticate_token(req)
		}
		.certificate, .oauth2, .saml, .webauthn, .kerberos {
			// TODO: Implement remaining auth methods.
			//       Each requires protocol-specific handshake logic.
			return error('auth method ${auth_method_to_string(req.method)} not yet implemented')
		}
	}
}

// authenticate_password validates username/password credentials against
// the server's credential store and issues a token on success.
fn (mut s AuthServer) authenticate_password(req AuthRequest) AuthResponse {
	stored_hash := s.credential_store[req.username] or {
		return AuthResponse{
			result: .denied
			token: ''
			expires_at: 0
			refresh_token: ''
			claims: TokenClaims{}
		}
	}

	if !verify_password(req.credentials, stored_hash) {
		return AuthResponse{
			result: .denied
			token: ''
			expires_at: 0
			refresh_token: ''
			claims: TokenClaims{}
		}
	}

	// Check if MFA is required (provider config key "require_mfa")
	for p in s.providers {
		if p.method == .password {
			if 'require_mfa' in p.config && p.config['require_mfa'] == 'true' {
				if req.mfa_code == '' {
					return AuthResponse{
						result: .mfa_required
						token: ''
						expires_at: 0
						refresh_token: ''
						claims: TokenClaims{}
					}
				}
				// TODO: Validate the MFA code against a TOTP or similar provider.
			}
			break
		}
	}

	now := time.now().unix()
	expires := now + s.token_ttl
	token_str := generate_token(req.username, s.issuer, now)
	refresh := generate_refresh_token(token_str)

	claims := TokenClaims{
		sub: req.username
		iss: s.issuer
		aud: 'v_auth_clients'
		exp: expires
		iat: now
		scopes: ['default']
	}

	// Store the token for later validation
	s.token_store[token_str] = claims

	return AuthResponse{
		result: .granted
		token: token_str
		expires_at: expires
		refresh_token: refresh
		claims: claims
	}
}

// authenticate_token validates a bearer token against the token store.
fn (s AuthServer) authenticate_token(req AuthRequest) AuthResponse {
	claims := s.validate_token(req.credentials) or {
		return AuthResponse{
			result: .denied
			token: ''
			expires_at: 0
			refresh_token: ''
			claims: TokenClaims{}
		}
	}

	return AuthResponse{
		result: .granted
		token: req.credentials
		expires_at: claims.exp
		refresh_token: ''
		claims: claims
	}
}

// validate_token checks whether a token string is valid, not revoked,
// and not expired. Returns the associated claims on success.
pub fn (s AuthServer) validate_token(token string) !TokenClaims {
	if token in s.revoked_tokens {
		return error('token has been revoked')
	}
	claims := s.token_store[token] or {
		return error('token not found')
	}
	now := time.now().unix()
	if claims.exp > 0 && now > claims.exp {
		return error('token expired')
	}
	return claims
}

// revoke_token marks a token as revoked so it can no longer be validated.
pub fn (mut s AuthServer) revoke_token(token string) ! {
	if token !in s.token_store {
		return error('token not found')
	}
	s.revoked_tokens[token] = true
}

// hash_password produces an HMAC-SHA256 hex digest of the given password.
// The HMAC key is the module-level hmac_secret constant.
pub fn hash_password(password string) string {
	digest := hmac.new(hmac_secret, password.bytes(), sha256.sum256, sha256.block_size)
	return hex.encode(digest)
}

// verify_password checks whether a plaintext password matches the given
// HMAC-SHA256 hash. Uses constant-time comparison to resist timing attacks.
pub fn verify_password(password string, hash string) bool {
	computed := hash_password(password)
	// Constant-time comparison: always compare all bytes
	if computed.len != hash.len {
		return false
	}
	mut result := u8(0)
	for i in 0 .. computed.len {
		result |= computed[i] ^ hash[i]
	}
	return result == 0
}
