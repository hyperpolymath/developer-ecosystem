// SPDX-License-Identifier: PMPL-1.0-or-later
// Emergency Button - V Language Implementation
// A tiny cross-platform emergency launcher/orchestrator

module main

import os
import flag

const version = '0.1.0'
const app_name = 'emergency-button'

struct Config {
mut:
	quick_backup_dest string
	dry_run           bool
	verbose           bool
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application(app_name)
	fp.version(version)
	fp.description('Emergency system recovery launcher.\nOffline-first, non-destructive, idempotent.')
	fp.skip_executable()

	// Parse subcommand
	remaining := fp.finalize() or {
		eprintln(fp.usage())
		exit(1)
	}

	if remaining.len == 0 {
		show_help()
		exit(0)
	}

	match remaining[0] {
		'trigger' {
			run_trigger(remaining[1..])
		}
		'help', '--help', '-h' {
			show_help()
		}
		'version', '--version', '-v' {
			println('${app_name} ${version}')
		}
		else {
			eprintln('Unknown command: ${remaining[0]}')
			eprintln('Use "${app_name} help" for usage information.')
			exit(1)
		}
	}
}

fn run_trigger(args []string) {
	mut fp := flag.new_flag_parser(args)
	fp.application('${app_name} trigger')
	fp.description('Create incident bundle and capture safe diagnostics.')

	quick_backup := fp.string('quick-backup', `b`, '', 'Destination path for quick backup (opt-in)')
	dry_run := fp.bool('dry-run', `n`, false, 'Preview actions without executing')
	verbose := fp.bool('verbose', `V`, false, 'Verbose output')

	_ := fp.finalize() or {
		eprintln(fp.usage())
		exit(1)
	}

	config := Config{
		quick_backup_dest: quick_backup
		dry_run: dry_run
		verbose: verbose
	}

	println('')
	println('${c_blue}╔══════════════════════════════════════════╗${c_reset}')
	println('${c_blue}║${c_reset}       ${c_bold}EMERGENCY BUTTON${c_reset}                   ${c_blue}║${c_reset}')
	println('${c_blue}║${c_reset}       Safe • Offline • Idempotent        ${c_blue}║${c_reset}')
	println('${c_blue}╚══════════════════════════════════════════╝${c_reset}')
	println('')

	if config.dry_run {
		println('${c_yellow}[DRY-RUN]${c_reset} Preview mode - no changes will be made')
		println('')
	}

	// Create incident bundle
	mut incident := create_incident_bundle(config) or {
		eprintln('${c_red}[ERROR]${c_reset} Failed to create incident bundle: ${err}')
		// Note: Can't use structured logging here as incident doesn't exist yet
		exit(1)
	}

	println('${c_green}[OK]${c_reset} Created incident bundle: ${incident.path}')
	println('${c_blue}[INFO]${c_reset} Correlation ID: ${incident.correlation_id}')
	println('')

	// Capture diagnostics
	println('${c_blue}[INFO]${c_reset} Capturing safe diagnostics...')
	capture_diagnostics(mut incident, config)

	// Write receipt
	write_receipt(incident, config) or {
		eprintln('${c_yellow}[WARN]${c_reset} Could not write receipt: ${err}')
		log_warn(incident.logs_path, 'main', 'Could not write receipt: ${err}')
	}

	// Quick backup if requested
	if config.quick_backup_dest.len > 0 {
		println('')
		println('${c_blue}[INFO]${c_reset} Quick backup requested to: ${config.quick_backup_dest}')
		run_quick_backup(incident, config)
	}

	// Handoff to specialized tool
	println('')
	handoff(incident, config)

	println('')
	println('${c_green}════════════════════════════════════════════${c_reset}')
	println('${c_green}[DONE]${c_reset} Incident bundle ready: ${incident.path}')
	println('${c_green}════════════════════════════════════════════${c_reset}')
}

fn show_help() {
	println('${c_bold}${app_name}${c_reset} - Emergency system recovery launcher')
	println('')
	println('${c_bold}USAGE:${c_reset}')
	println('    ${app_name} trigger [OPTIONS]')
	println('')
	println('${c_bold}COMMANDS:${c_reset}')
	println('    trigger     Create incident bundle and capture diagnostics')
	println('    help        Show this help message')
	println('    version     Show version information')
	println('')
	println('${c_bold}OPTIONS (for trigger):${c_reset}')
	println('    -b, --quick-backup <path>   Run quick backup to destination (opt-in)')
	println('    -n, --dry-run               Preview actions without executing')
	println('    -V, --verbose               Verbose output')
	println('')
	println('${c_bold}EXAMPLES:${c_reset}')
	println('    ${app_name} trigger')
	println('    ${app_name} trigger --dry-run')
	println('    ${app_name} trigger --quick-backup /mnt/backup')
	println('')
	println('${c_bold}SAFETY:${c_reset}')
	println('    - Default action is non-destructive and offline-first')
	println('    - No silent downloads, no auto-fixes')
	println('    - Idempotent: pressing twice is safe')
	println('    - Everything logged to incident bundle')
}

// Terminal colors
const c_reset = '\x1b[0m'
const c_bold = '\x1b[1m'
const c_red = '\x1b[31m'
const c_green = '\x1b[32m'
const c_yellow = '\x1b[33m'
const c_blue = '\x1b[34m'
const c_cyan = '\x1b[36m'
