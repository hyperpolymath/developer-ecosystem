// SPDX-License-Identifier: PMPL-1.0-or-later
// Tests for incident bundle creation and management

module main

import time
import rand

fn test_incident_envelope_has_required_fields() {
	envelope := IncidentEnvelope{
		schema_version: schema_version  // Use constant from utils.v
		id: 'incident-test-123'
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
			version: '0.1.0'
			dry_run: false
			args: 'trigger'
		}
		commands: []
	}

	assert envelope.schema_version == schema_version
	assert envelope.id.starts_with('incident-')
	assert envelope.hostname.len > 0
	assert envelope.platform.os.len > 0
}

fn test_platform_info_creation() {
	info := PlatformInfo{
		os: 'Linux'
		arch: 'x86_64'
		kernel: '6.0.0-test'
	}

	assert info.os == 'Linux'
	assert info.arch == 'x86_64'
	assert info.kernel == '6.0.0-test'
}

fn test_trigger_info_dry_run() {
	trigger := TriggerInfo{
		version: '0.1.0'
		dry_run: true
		args: 'trigger --dry-run'
	}

	assert trigger.dry_run == true
	assert trigger.args.contains('--dry-run')
}

fn test_command_log_creation() {
	log := CommandLog{
		name: 'test_command'
		command: 'echo hello'
		started_at: '2026-01-02T20:00:00Z'
		ended_at: '2026-01-02T20:00:01Z'
		exit_code: 0
		output_len: 6
	}

	assert log.name == 'test_command'
	assert log.exit_code == 0
	assert log.output_len == 6
}

fn test_get_os_name_returns_valid_value() {
	os_name := get_os_name()
	valid_names := ['Linux', 'macOS', 'Windows', 'Unknown']
	assert os_name in valid_names
}

fn test_get_arch_returns_valid_value() {
	arch := get_arch()
	valid_archs := ['x86_64', 'arm64', 'i386', 'unknown']
	assert arch in valid_archs
}

fn test_incident_id_format() {
	// Test that incident IDs follow expected format
	now := time.now()
	timestamp := now.custom_format('YYYYMMDD-HHmmss')
	incident_id := 'incident-${timestamp}'

	assert incident_id.starts_with('incident-')
	assert incident_id.len > 9 // 'incident-' + at least some timestamp
}

fn test_dry_run_config() {
	config := Config{
		quick_backup_dest: ''
		dry_run: true
		verbose: false
	}

	assert config.dry_run == true
	assert config.verbose == false
	assert config.quick_backup_dest == ''
}

fn test_incident_struct_initialization() {
	incident := Incident{
		id: 'incident-test'
		correlation_id: 'corr-test1234'
		path: '/tmp/incident-test'
		logs_path: '/tmp/incident-test/logs'
		created_at: time.now()
		commands: []
	}

	assert incident.id == 'incident-test'
	assert incident.correlation_id == 'corr-test1234'
	assert incident.path.contains('incident-test')
	assert incident.logs_path.contains('logs')
	assert incident.commands.len == 0
}

fn test_correlation_id_format() {
	// Test that correlation IDs start with corr- prefix
	// Format: 'corr-' (5 chars) + 8 hex chars = 13 chars total
	corr_id := 'corr-${rand.hex(8)}'
	assert corr_id.starts_with('corr-')
	assert corr_id.len == 13  // 'corr-' (5) + 8 hex chars
}
