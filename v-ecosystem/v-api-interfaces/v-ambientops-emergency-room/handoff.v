// SPDX-License-Identifier: MPL-2.0
// Handoff logic to specialized tools (psa, ambientops)
// CRIT-001 fix: Path validation to prevent command injection

module main

import os

struct HandoffTarget {
	name        string
	command     string
	args        []string
	description string
}

// CRIT-001: Check if path contains only safe characters
// Prevents shell injection via incident.path
fn is_path_safe(path string) bool {
	// Allow only alphanumeric, dash, underscore, dot, forward slash
	// Explicitly reject: semicolon, pipe, backtick, $, &, >, <, etc.
	for c in path {
		is_safe := (c >= `a` && c <= `z`) ||
			(c >= `A` && c <= `Z`) ||
			(c >= `0` && c <= `9`) ||
			c == `-` || c == `_` || c == `.` || c == `/`
		if !is_safe {
			return false
		}
	}
	// Also reject empty paths and paths with ..
	if path.len == 0 || path.contains('..') {
		return false
	}
	return true
}

fn handoff(incident Incident, config Config) {
	// CRIT-001: Validate incident path before using in shell commands
	if !is_path_safe(incident.path) {
		eprintln('${c_red}[ERROR]${c_reset} Invalid incident path detected (possible injection attempt)')
		eprintln('${c_yellow}[INFO]${c_reset} Path must contain only alphanumeric, dash, underscore, dot, slash')
		log_error(incident.logs_path, 'handoff', 'Invalid incident path detected (possible injection attempt)', {
			'path': incident.path
		})
		return
	}

	// Try to find specialized tools in order of preference
	// COULD-001: Pass correlation ID for cross-tool tracing
	targets := [
		HandoffTarget{
			name: 'ambientops-clinician'
			command: 'ambientops-clinician'
			args: ['crisis', '--incident', incident.path, '--correlation-id', incident.correlation_id]
			description: 'AmbientOps Clinician crisis mode'
		},
		HandoffTarget{
			name: 'psa'
			command: 'psa'
			args: ['crisis', '--incident', incident.path, '--correlation-id', incident.correlation_id]
			description: 'Personal Sysadmin crisis mode (legacy)'
		},
		HandoffTarget{
			name: 'ambientops'
			command: 'ambientops'
			args: ['scan', '--incident', incident.path, '--correlation-id', incident.correlation_id]
			description: 'Advanced diagnostics (non-mutating)'
		},
	]

	mut found_target := ?HandoffTarget(none)

	for target in targets {
		if tool_exists(target.command) {
			found_target = target
			break
		}
	}

	if target := found_target {
		println('${c_blue}[HANDOFF]${c_reset} Found ${target.name}: ${target.description}')
		println('')

		full_command := '${target.command} ${target.args.join(' ')}'

		if config.dry_run {
			println('${c_cyan}[DRY-RUN]${c_reset} Would execute: ${full_command}')
			return
		}

		println('${c_blue}[INFO]${c_reset} Launching: ${full_command}')
		println('')

		// Log the handoff
		log_handoff(incident, target, config)

		// Execute the handoff (spawn, don't wait)
		spawn_tool(target)
	} else {
		println('${c_yellow}[INFO]${c_reset} No specialized tools found (psa, ambientops)')
		println('${c_blue}[INFO]${c_reset} Incident bundle is ready for manual review')
		println('')
		println('${c_cyan}Suggested next steps:${c_reset}')
		println('  1. Review logs in: ${incident.logs_path}')
		println('  2. Install psa or ambientops for enhanced diagnostics')
		println('  3. Share the incident bundle for analysis')
	}
}

fn tool_exists(name string) bool {
	// Check if tool is in PATH
	$if windows {
		result := os.execute('where ${name} 2>nul')
		return result.exit_code == 0
	} $else {
		result := os.execute('command -v ${name} 2>/dev/null')
		return result.exit_code == 0
	}
}

fn spawn_tool(target HandoffTarget) {
	// Build the command
	mut cmd_args := [target.command]
	cmd_args << target.args

	// Use os.execute for now (synchronous)
	// In a more advanced version, we'd spawn and detach
	full_cmd := cmd_args.join(' ')

	$if windows {
		os.execute('start "" ${full_cmd}')
	} $else {
		// Run in foreground for now - user can Ctrl+C
		result := os.execute(full_cmd)
		if result.exit_code != 0 {
			eprintln('${c_yellow}[WARN]${c_reset} ${target.name} exited with code ${result.exit_code}')
		}
	}
}

fn log_handoff(incident Incident, target HandoffTarget, config Config) {
	if config.dry_run {
		return
	}

	handoff_log := os.join_path(incident.logs_path, 'handoff.log')
	content := 'schema_version: ${schema_version}

Handoff to: ${target.name}
Command: ${target.command} ${target.args.join(' ')}
Description: ${target.description}
'

	// HIGH-006: Use atomic write to prevent corruption
	atomic_write_file(handoff_log, content) or {
		eprintln('${c_yellow}[WARN]${c_reset} Could not write handoff log: ${err}')
	}
}
