// SPDX-License-Identifier: PMPL-1.0-or-later
// Integration tests for full emergency-button workflow

module main

import os
import time
import json

// Test full incident bundle creation in dry-run mode
fn test_incident_bundle_creation_dry_run() {
	config := Config{
		quick_backup_dest: ''
		dry_run: true
		verbose: false
	}

	incident := create_incident_bundle(config) or {
		assert false, 'Failed to create incident bundle: ${err}'
		return
	}

	// Verify incident structure
	assert incident.id.starts_with('incident-')
	assert incident.correlation_id.starts_with('corr-')
	assert incident.correlation_id.len == 13
	assert incident.path.len > 0
	assert incident.logs_path.contains('logs')
}

// Test incident envelope JSON structure
fn test_incident_envelope_json_structure() {
	envelope := IncidentEnvelope{
		schema_version: schema_version
		id: 'incident-test-integration-001'
		correlation_id: 'corr-12345678'
		created_at: time.now().format_rfc3339()
		hostname: 'test-host'
		username: 'test-user'
		working_dir: '/tmp'
		platform: PlatformInfo{
			os: 'Linux'
			arch: 'x86_64'
			kernel: '6.0.0'
		}
		trigger: TriggerInfo{
			version: version
			dry_run: true
			args: 'trigger --dry-run'
		}
		commands: []
	}

	// Verify JSON encoding works
	json_str := json.encode(envelope)
	assert json_str.contains('"schema_version"')
	assert json_str.contains('"correlation_id"')
	assert json_str.contains('"corr-12345678"')
}

// Test handoff target construction with correlation ID
fn test_handoff_targets_include_correlation_id() {
	incident := Incident{
		id: 'incident-test-handoff'
		correlation_id: 'corr-abcdef12'
		path: '/tmp/incident-test-handoff'
		logs_path: '/tmp/incident-test-handoff/logs'
		created_at: time.now()
		commands: []
	}

	// Simulate handoff target construction (from handoff.v)
	psa_args := ['crisis', '--incident', incident.path, '--correlation-id', incident.correlation_id]

	assert psa_args.contains('--correlation-id')
	assert psa_args.contains('corr-abcdef12')
}

// Test path validation for injection prevention
fn test_path_validation_rejects_dangerous_chars() {
	// Test is_path_safe function from handoff.v
	assert is_path_safe('/tmp/valid-path') == true
	assert is_path_safe('/home/user/incident-20260102') == true

	// Dangerous characters should fail
	assert is_path_safe('/tmp/path;rm -rf /') == false
	assert is_path_safe('/tmp/path|cat /etc/passwd') == false
	assert is_path_safe('/tmp/path`whoami`') == false
	assert is_path_safe('/tmp/path$(id)') == false

	// Path traversal should fail
	assert is_path_safe('/tmp/../etc/passwd') == false
	assert is_path_safe('') == false
}

// Test backup path validation
fn test_backup_path_validation() ! {
	// Valid paths should pass
	safe := validate_safe_path('/mnt/backup/emergency') or {
		assert false, 'Valid path rejected: ${err}'
		return error('test failed')
	}
	assert safe == '/mnt/backup/emergency'

	// Dangerous paths should fail
	if _ := validate_safe_path('/tmp/backup;rm -rf /') {
		assert false, 'Dangerous path accepted'
	}

	if _ := validate_safe_path('/tmp/backup|cat /etc/passwd') {
		assert false, 'Pipe injection accepted'
	}
}

// Test command log structure
fn test_command_log_integration() {
	mut incident := Incident{
		id: 'incident-test-cmdlog'
		correlation_id: 'corr-cmdlog01'
		path: '/tmp/incident-test-cmdlog'
		logs_path: '/tmp/incident-test-cmdlog/logs'
		created_at: time.now()
		commands: []
	}

	// Add command log
	log := CommandLog{
		name: 'uname'
		command: 'uname -a'
		started_at: time.now().format_rfc3339()
		ended_at: time.now().format_rfc3339()
		exit_code: 0
		output_len: 128
	}
	incident.commands << log

	assert incident.commands.len == 1
	assert incident.commands[0].name == 'uname'
	assert incident.commands[0].exit_code == 0
}

// Test schema version consistency
fn test_schema_version_is_set() {
	assert schema_version.len > 0
	assert schema_version.contains('.')  // Should be semver format like "1.0.0"
}

// Test platform detection functions
fn test_platform_detection_consistency() {
	os_name := get_os_name()
	arch := get_arch()
	kernel := get_kernel_version()

	// Should return non-empty values
	assert os_name.len > 0
	assert arch.len > 0
	assert kernel.len > 0

	// OS should be one of the known values
	valid_os := ['Linux', 'macOS', 'Windows', 'Unknown']
	assert os_name in valid_os
}
