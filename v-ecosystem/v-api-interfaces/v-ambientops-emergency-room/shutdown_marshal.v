// SPDX-License-Identifier: PMPL-1.0-or-later
// Shutdown Marshal - Graceful shutdown orchestration
// Addresses CC-002 (unsafe shutdowns)
//
// The Shutdown Marshal coordinates system shutdown to ensure:
// 1. All AmbientOps components are notified and can flush state
// 2. Evidence envelopes are finalized before power loss
// 3. Shutdown reason is recorded for post-mortem analysis
// 4. Ungraceful shutdowns are detected on next boot
//
// Author: Jonathan D.A. Jewell

module main

import os
import time
import json

// ── Configuration ───────────────────────────────────────────────────────

// Default location for shutdown state tracking
const default_shutdown_state_path = '/var/lib/ambientops/shutdown-marshal/state.json'
// Grace period in seconds before forced shutdown
const default_grace_period_secs = 30
// Components that should be notified before shutdown
const default_notify_components = [
	'observatory',
	'clinician',
	'session-sentinel',
]

// ── Types ───────────────────────────────────────────────────────────────

// ShutdownReason categorizes why the system is shutting down
enum ShutdownReason {
	user_initiated     // User requested shutdown/reboot
	scheduled          // Scheduled maintenance window
	emergency          // Emergency shutdown (thermal, hardware failure)
	kernel_panic       // Detected kernel panic in progress
	power_loss         // UPS signaling power loss
	unknown            // Could not determine reason
}

// ShutdownState tracks the current shutdown lifecycle.
// Persisted to disk so the next boot can detect ungraceful shutdowns.
struct ShutdownState {
mut:
	schema_version     string @[json: 'schema_version']
	last_clean_shutdown string @[json: 'last_clean_shutdown']  // RFC 3339 timestamp
	shutdown_in_progress bool  @[json: 'shutdown_in_progress']
	shutdown_reason    string  @[json: 'shutdown_reason']
	notified_components []string @[json: 'notified_components']
	pending_flushes    []string @[json: 'pending_flushes']
	ungraceful_count   int     @[json: 'ungraceful_count']  // consecutive ungraceful shutdowns
}

// ShutdownPlan describes the sequence of actions for an orderly shutdown.
struct ShutdownPlan {
	reason            ShutdownReason
	grace_period_secs int
	components        []string
	actions           []ShutdownAction
}

// ShutdownAction is a single step in the shutdown sequence
struct ShutdownAction {
	name        string
	description string
	command     string
	timeout_ms  int
	critical    bool  // if true, failure aborts shutdown
}

// ShutdownReport is emitted after shutdown orchestration completes (or fails).
struct ShutdownReport {
	schema_version   string              @[json: 'schema_version']
	initiated_at     string              @[json: 'initiated_at']
	completed_at     string              @[json: 'completed_at']
	reason           string
	success          bool
	actions_taken    []ShutdownActionResult @[json: 'actions_taken']
	components_notified []string          @[json: 'components_notified']
}

// ShutdownActionResult records the outcome of a single shutdown action
struct ShutdownActionResult {
	name        string
	success     bool
	duration_ms i64 @[json: 'duration_ms']
	error_msg   string @[json: 'error_msg']
}

// ── Core Functions ──────────────────────────────────────────────────────

// check_last_shutdown examines the persisted state to determine if the
// previous shutdown was clean. Called early on boot.
fn check_last_shutdown(state_path string) ShutdownState {
	mut state := load_shutdown_state(state_path)

	if state.shutdown_in_progress {
		// The shutdown_in_progress flag was never cleared — ungraceful shutdown
		state.ungraceful_count += 1
		state.shutdown_in_progress = false
	}

	return state
}

// prepare_shutdown creates a shutdown plan based on the given reason.
fn prepare_shutdown(reason ShutdownReason, grace_period int) ShutdownPlan {
	mut actions := []ShutdownAction{}

	// Step 1: Flush AmbientOps state files
	actions << ShutdownAction{
		name: 'flush-state'
		description: 'Flush .machine_readable state files'
		command: 'sync'
		timeout_ms: 5000
		critical: false
	}

	// Step 2: Stop session-sentinel cleanly
	actions << ShutdownAction{
		name: 'stop-sentinel'
		description: 'Stop session-sentinel gracefully'
		command: 'systemctl --user stop session-sentinel.service 2>/dev/null || true'
		timeout_ms: 10000
		critical: false
	}

	// Step 3: Sync filesystems
	actions << ShutdownAction{
		name: 'filesystem-sync'
		description: 'Force filesystem sync'
		command: 'sync'
		timeout_ms: 15000
		critical: true
	}

	// Step 4: For emergency shutdowns, also capture a minimal diagnostic snapshot
	if reason == .emergency || reason == .kernel_panic {
		actions << ShutdownAction{
			name: 'emergency-snapshot'
			description: 'Capture minimal emergency snapshot'
			command: 'journalctl -b --no-pager -n 100 > /tmp/ambientops-emergency-snapshot.log 2>/dev/null || true'
			timeout_ms: 5000
			critical: false
		}
	}

	return ShutdownPlan{
		reason: reason
		grace_period_secs: grace_period
		components: default_notify_components
		actions: actions
	}
}

// execute_shutdown runs the shutdown plan and returns a report.
fn execute_shutdown(plan ShutdownPlan, state_path string, dry_run bool) ShutdownReport {
	initiated := time.now()

	// Mark shutdown in progress
	if !dry_run {
		mut state := load_shutdown_state(state_path)
		state.shutdown_in_progress = true
		state.shutdown_reason = shutdown_reason_str(plan.reason)
		save_shutdown_state(state_path, state) or {
			eprintln('${c_yellow}[WARN]${c_reset} Could not persist shutdown state: ${err}')
		}
	}

	mut results := []ShutdownActionResult{}
	mut all_success := true

	// Notify components
	mut notified := []string{}
	for component in plan.components {
		if dry_run {
			println('${c_cyan}[DRY-RUN]${c_reset} Would notify: ${component}')
			notified << component
			continue
		}
		// Best-effort notification via systemd user units
		notify_result := os.execute('systemctl --user kill -s SIGTERM ${component}.service 2>/dev/null')
		if notify_result.exit_code == 0 {
			notified << component
			println('${c_green}[OK]${c_reset} Notified: ${component}')
		} else {
			println('${c_yellow}[SKIP]${c_reset} Component not running: ${component}')
		}
	}

	// Execute shutdown actions
	for action in plan.actions {
		start := time.now()

		if dry_run {
			println('${c_cyan}[DRY-RUN]${c_reset} Would execute: ${action.name} — ${action.description}')
			results << ShutdownActionResult{
				name: action.name
				success: true
				duration_ms: 0
			}
			continue
		}

		println('${c_blue}[EXEC]${c_reset} ${action.name}: ${action.description}')
		exec_result := os.execute(action.command)
		duration := (time.now() - start).milliseconds()
		success := exec_result.exit_code == 0

		if !success && action.critical {
			all_success = false
			eprintln('${c_red}[FAIL]${c_reset} Critical action failed: ${action.name}')
		}

		results << ShutdownActionResult{
			name: action.name
			success: success
			duration_ms: duration
			error_msg: if success { '' } else { 'exit code ${exec_result.exit_code}' }
		}
	}

	completed := time.now()

	// Mark shutdown complete (clean)
	if !dry_run {
		mut state := load_shutdown_state(state_path)
		state.shutdown_in_progress = false
		state.last_clean_shutdown = completed.format_rfc3339()
		state.shutdown_reason = shutdown_reason_str(plan.reason)
		state.notified_components = notified
		state.ungraceful_count = 0  // reset on clean shutdown
		save_shutdown_state(state_path, state) or {}
	}

	return ShutdownReport{
		schema_version: schema_version
		initiated_at: initiated.format_rfc3339()
		completed_at: completed.format_rfc3339()
		reason: shutdown_reason_str(plan.reason)
		success: all_success
		actions_taken: results
		components_notified: notified
	}
}

// ── Persistence ─────────────────────────────────────────────────────────

// load_shutdown_state reads the shutdown state file
fn load_shutdown_state(path string) ShutdownState {
	content := os.read_file(path) or {
		return ShutdownState{
			schema_version: schema_version
			shutdown_in_progress: false
			ungraceful_count: 0
		}
	}

	return json.decode(ShutdownState, content) or {
		return ShutdownState{
			schema_version: schema_version
			shutdown_in_progress: false
			ungraceful_count: 0
		}
	}
}

// save_shutdown_state persists the shutdown state atomically
fn save_shutdown_state(path string, state ShutdownState) ! {
	dir := os.dir(path)
	if !os.exists(dir) {
		os.mkdir_all(dir) or {
			return error('Failed to create state directory ${dir}: ${err}')
		}
	}

	content := json.encode_pretty(state)
	atomic_write_file(path, content)!
}

// ── Helpers ─────────────────────────────────────────────────────────────

// shutdown_reason_str converts ShutdownReason to a string
fn shutdown_reason_str(reason ShutdownReason) string {
	return match reason {
		.user_initiated { 'user_initiated' }
		.scheduled { 'scheduled' }
		.emergency { 'emergency' }
		.kernel_panic { 'kernel_panic' }
		.power_loss { 'power_loss' }
		.unknown { 'unknown' }
	}
}

// parse_shutdown_reason converts a string to ShutdownReason
fn parse_shutdown_reason(s string) ShutdownReason {
	return match s {
		'user' { .user_initiated }
		'user_initiated' { .user_initiated }
		'scheduled' { .scheduled }
		'emergency' { .emergency }
		'panic' { .kernel_panic }
		'kernel_panic' { .kernel_panic }
		'power' { .power_loss }
		'power_loss' { .power_loss }
		else { .unknown }
	}
}

// ── CLI Integration ─────────────────────────────────────────────────────

// run_shutdown_marshal is the CLI entry point for the shutdown-marshal subcommand.
fn run_shutdown_marshal(args []string) {
	mut fp := flag.new_flag_parser(args)
	fp.application('${app_name} shutdown-marshal')
	fp.description('Graceful shutdown orchestration.\nAddresses CC-002 (unsafe shutdowns).')

	state_path := fp.string('state', `s`, default_shutdown_state_path, 'Path to shutdown state file')
	dry_run := fp.bool('dry-run', `n`, false, 'Preview actions without executing')
	reason_str := fp.string('reason', `r`, 'user', 'Shutdown reason (user, scheduled, emergency, panic, power)')
	grace := fp.int('grace', `g`, default_grace_period_secs, 'Grace period in seconds')
	check := fp.bool('check', `c`, false, 'Check last shutdown status only')
	json_output := fp.bool('json', `j`, false, 'Output as JSON')

	_ := fp.finalize() or {
		eprintln(fp.usage())
		exit(1)
	}

	if check {
		state := check_last_shutdown(state_path)

		if json_output {
			println(json.encode_pretty(state))
			return
		}

		println('')
		println('${c_blue}╔══════════════════════════════════════════╗${c_reset}')
		println('${c_blue}║${c_reset}       ${c_bold}SHUTDOWN MARSHAL${c_reset}                   ${c_blue}║${c_reset}')
		println('${c_blue}╚══════════════════════════════════════════╝${c_reset}')
		println('')

		if state.last_clean_shutdown.len > 0 {
			println('${c_green}[OK]${c_reset} Last clean shutdown: ${state.last_clean_shutdown}')
		} else {
			println('${c_yellow}[WARN]${c_reset} No clean shutdown on record')
		}

		if state.ungraceful_count > 0 {
			println('${c_red}[ALERT]${c_reset} ${state.ungraceful_count} consecutive ungraceful shutdown(s) detected')
			println('  This may indicate power loss, kernel panic, or forced reboot')
		} else {
			println('${c_green}[OK]${c_reset} No ungraceful shutdowns detected')
		}
		return
	}

	// Execute shutdown orchestration
	reason := parse_shutdown_reason(reason_str)
	plan := prepare_shutdown(reason, grace)

	println('')
	println('${c_blue}╔══════════════════════════════════════════╗${c_reset}')
	println('${c_blue}║${c_reset}       ${c_bold}SHUTDOWN MARSHAL${c_reset}                   ${c_blue}║${c_reset}')
	println('${c_blue}║${c_reset}       Graceful Shutdown Orchestrator      ${c_blue}║${c_reset}')
	println('${c_blue}╚══════════════════════════════════════════╝${c_reset}')
	println('')
	println('${c_blue}[INFO]${c_reset} Reason: ${shutdown_reason_str(reason)}')
	println('${c_blue}[INFO]${c_reset} Grace period: ${grace}s')
	println('${c_blue}[INFO]${c_reset} Actions: ${plan.actions.len}')
	println('')

	report := execute_shutdown(plan, state_path, dry_run)

	if json_output {
		println(json.encode_pretty(report))
		return
	}

	if report.success {
		println('')
		println('${c_green}════════════════════════════════════════════${c_reset}')
		println('${c_green}[DONE]${c_reset} Shutdown orchestration complete')
		println('${c_green}════════════════════════════════════════════${c_reset}')
	} else {
		println('')
		println('${c_yellow}════════════════════════════════════════════${c_reset}')
		println('${c_yellow}[WARN]${c_reset} Shutdown orchestration completed with errors')
		println('${c_yellow}════════════════════════════════════════════${c_reset}')
	}
}
