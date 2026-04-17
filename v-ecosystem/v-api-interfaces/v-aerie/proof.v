// SPDX-License-Identifier: PMPL-1.0-or-later
//
// proof.v — Proof Envelope Generation
//
// Every API response (GraphQL, gRPC, REST) is wrapped in a ProofEnvelope
// that provides tamper-evident hashing. Phase 1 uses "light" mode (SHA-256
// hash only). Phase 2+ will add Ed448 signatures ("full" mode).
//
// The envelope matches the protobuf ProofEnvelope message definition
// in src/api/proto/aerie.proto.

module main

import crypto.sha256
import rand
import time

// ProofEnvelope wraps every API response with a cryptographic hash
// and metadata for auditability and tamper detection.
//
// Fields:
//   result_hash  — SHA-256 hex digest of the JSON response body
//   policy_hash  — SHA-256 hex digest of the policy rules applied
//   query_id     — UUID v4 identifying this specific request
//   issued_at    — RFC 3339 timestamp of when the response was generated
//   proof_type   — "light" (hash-only, Phase 1) or "full" (signed, Phase 2+)
//   signature    — Empty in Phase 1; Ed448 signature in Phase 2+
pub struct ProofEnvelope {
pub:
	result_hash string
	policy_hash string
	query_id    string
	issued_at   string
	proof_type  string
	signature   string
}

// generate_uuid_v4 produces a version 4 UUID string.
// Uses random bytes with the version and variant bits set per RFC 4122.
fn generate_uuid_v4() string {
	// Generate 16 random bytes
	mut bytes := []u8{len: 16}
	for i in 0 .. 16 {
		bytes[i] = u8(rand.intn(256) or { 0 })
	}
	// Set version 4 (bits 12-15 of time_hi_and_version)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	// Set variant bits (bits 6-7 of clk_seq_hi_res)
	bytes[8] = (bytes[8] & 0x3f) | 0x80

	return '${bytes[0]:02x}${bytes[1]:02x}${bytes[2]:02x}${bytes[3]:02x}-${bytes[4]:02x}${bytes[5]:02x}-${bytes[6]:02x}${bytes[7]:02x}-${bytes[8]:02x}${bytes[9]:02x}-${bytes[10]:02x}${bytes[11]:02x}${bytes[12]:02x}${bytes[13]:02x}${bytes[14]:02x}${bytes[15]:02x}'
}

// wrap_response creates a ProofEnvelope for the given response body
// and policy context string. The result_hash is SHA-256 of the body,
// the policy_hash is SHA-256 of the policy context, and a fresh UUID
// and timestamp are generated.
pub fn wrap_response(body string, policy_context string) ProofEnvelope {
	result_hash := sha256.hexhash(body)
	policy_hash := sha256.hexhash(policy_context)
	query_id := generate_uuid_v4()
	now := time.now()
	issued_at := now.format_rfc3339()

	return ProofEnvelope{
		result_hash: result_hash
		policy_hash: policy_hash
		query_id:    query_id
		issued_at:   issued_at
		proof_type:  'light'
		signature:   ''
	}
}

// envelope_to_json serialises a ProofEnvelope to a JSON object string.
pub fn envelope_to_json(env ProofEnvelope) string {
	return '{"result_hash":"${env.result_hash}","policy_hash":"${env.policy_hash}","query_id":"${env.query_id}","issued_at":"${env.issued_at}","proof_type":"${env.proof_type}","signature":"${env.signature}"}'
}

// wrap_body_with_proof takes a JSON response body and policy context,
// generates a ProofEnvelope, and returns the final JSON string with
// the proof embedded alongside the data.
//
// Output format:
//   {"data": <original body>, "proof": <envelope>}
pub fn wrap_body_with_proof(body string, policy_context string) string {
	env := wrap_response(body, policy_context)
	proof_json := envelope_to_json(env)
	return '{"data":${body},"proof":${proof_json}}'
}
