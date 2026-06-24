// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_kerberos.
// Validates KDC creation, principal management, AS/TGS exchanges,
// ticket validation, and password changes.
module main

import v_kerberos

// test_new_kdc_creates_with_realm verifies that a new KDC is created
// with the specified realm and has the krbtgt principal registered.
fn test_new_kdc_creates_with_realm() {
	kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	assert kdc.realm == 'EXAMPLE.COM'
	assert 'krbtgt' in kdc.principals
	assert kdc.issued_tickets.len == 0
}

// test_register_principal verifies that principals can be registered.
fn test_register_principal() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'password123') or {
		assert false, 'register failed: ${err}'
		return
	}
	assert 'alice' in kdc.principals
	principals := kdc.list_principals()
	assert principals.len == 2 // krbtgt + alice
}

// test_register_empty_name_returns_error verifies that empty principal
// names are rejected.
fn test_register_empty_name_returns_error() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('', 'password') or {
		assert err.msg().contains('must not be empty')
		return
	}
	assert false, 'expected error for empty name'
}

// test_register_duplicate_returns_error verifies that duplicate
// principal registration is rejected.
fn test_register_duplicate_returns_error() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('bob', 'pass1') or { return }
	kdc.register_principal('bob', 'pass2') or {
		assert err.msg().contains('already exists')
		return
	}
	assert false, 'expected error for duplicate principal'
}

// test_authenticate_success verifies that a registered principal can
// authenticate and receive a TGT.
fn test_authenticate_success() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'secret') or { return }
	tgt := kdc.authenticate('alice', 'secret') or {
		assert false, 'authenticate failed: ${err}'
		return
	}
	assert tgt.client.name == 'alice'
	assert tgt.client.realm == 'EXAMPLE.COM'
	assert tgt.ticket.sname.name == 'krbtgt'
	assert tgt.session_key.len == 32
	assert kdc.issued_tickets.len == 1
}

// test_authenticate_wrong_password_returns_error verifies that
// authentication fails with the wrong password.
fn test_authenticate_wrong_password_returns_error() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'correct') or { return }
	kdc.authenticate('alice', 'wrong') or {
		assert err.msg().contains('authentication failed')
		return
	}
	assert false, 'expected authentication failure'
}

// test_authenticate_unknown_principal_returns_error verifies that
// authentication fails for an unregistered principal.
fn test_authenticate_unknown_principal_returns_error() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.authenticate('nobody', 'pass') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for unknown principal'
}

// test_request_service_ticket verifies the TGS exchange flow.
fn test_request_service_ticket() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'secret') or { return }
	kdc.register_principal('http/web.example.com', 'svc-secret') or { return }
	tgt := kdc.authenticate('alice', 'secret') or { return }
	svc_ticket := kdc.request_service_ticket(tgt, 'http/web.example.com') or {
		assert false, 'service ticket request failed: ${err}'
		return
	}
	assert svc_ticket.sname.name == 'http/web.example.com'
	assert svc_ticket.validity == 3600
	assert kdc.issued_tickets.len == 2 // TGT + service ticket
}

// test_request_service_ticket_unknown_service_returns_error verifies
// that requesting a ticket for an unregistered service fails.
fn test_request_service_ticket_unknown_service_returns_error() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'secret') or { return }
	tgt := kdc.authenticate('alice', 'secret') or { return }
	kdc.request_service_ticket(tgt, 'unknown/service') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for unknown service'
}

// test_validate_ticket_valid verifies that a freshly issued ticket
// passes validation.
fn test_validate_ticket_valid() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'secret') or { return }
	tgt := kdc.authenticate('alice', 'secret') or { return }
	kdc.validate_ticket(tgt.ticket) or {
		assert false, 'validate failed: ${err}'
		return
	}
}

// test_validate_ticket_expired verifies that an expired ticket is
// rejected.
fn test_validate_ticket_expired() {
	kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	mut ticket := v_kerberos.Ticket{
		sname: v_kerberos.Principal{name: 'krbtgt', realm: 'EXAMPLE.COM'}
		validity: 1
		enc_type: .aes256_cts_hmac
	}
	ticket.expired = true
	kdc.validate_ticket(ticket) or {
		assert err.msg().contains('expired')
		return
	}
	assert false, 'expected expired ticket error'
}

// test_validate_ticket_wrong_realm verifies that a ticket from a
// different realm is rejected.
fn test_validate_ticket_wrong_realm() {
	kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	ticket := v_kerberos.Ticket{
		sname: v_kerberos.Principal{name: 'krbtgt', realm: 'OTHER.COM'}
		validity: 36000
		enc_type: .aes256_cts_hmac
	}
	kdc.validate_ticket(ticket) or {
		assert err.msg().contains('realm mismatch')
		return
	}
	assert false, 'expected realm mismatch error'
}

// test_change_password verifies that a principal can change their
// password.
fn test_change_password() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'old-pass') or { return }
	kdc.change_password('alice', 'old-pass', 'new-pass') or {
		assert false, 'change_password failed: ${err}'
		return
	}
	// Old password should no longer work.
	kdc.authenticate('alice', 'old-pass') or {
		assert err.msg().contains('authentication failed')
		// New password should work.
		kdc.authenticate('alice', 'new-pass') or {
			assert false, 'new password failed: ${err}'
			return
		}
		return
	}
	assert false, 'expected old password to fail'
}

// test_change_password_wrong_old_returns_error verifies that password
// change fails with the wrong old password.
fn test_change_password_wrong_old_returns_error() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'correct') or { return }
	kdc.change_password('alice', 'wrong', 'new') or {
		assert err.msg().contains('verification failed')
		return
	}
	assert false, 'expected old password verification failure'
}

// test_list_principals_includes_realm verifies that list_principals
// returns fully qualified principal names.
fn test_list_principals_includes_realm() {
	mut kdc := v_kerberos.new_kdc('EXAMPLE.COM')
	kdc.register_principal('alice', 'pass') or { return }
	principals := kdc.list_principals()
	mut found_alice := false
	for p in principals {
		if p == 'alice@EXAMPLE.COM' {
			found_alice = true
		}
	}
	assert found_alice
}
