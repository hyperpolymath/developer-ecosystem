// SPDX-License-Identifier: PMPL-1.0-or-later
// Quick backup functionality with preview mode
// CRIT-002 fix: Path validation to prevent command injection

module main

import os
import time

// Shell metacharacters that could enable injection attacks
const shell_dangerous_chars = [';', '|', '&', r'$', '`', '(', ')', '{', '}', '[', ']', '<', '>', '\n', '\r', '*', '?', '~', '!', '#']

// Validate a path is safe for shell interpolation
// Returns error if path contains dangerous characters
fn validate_safe_path(path string) !string {
	if path.len == 0 {
		return error('Empty path')
	}

	// Check for shell metacharacters
	for c in shell_dangerous_chars {
		if path.contains(c) {
			return error('Path contains dangerous character: ${c}')
		}
	}

	// Check for path traversal attempts beyond expected scope
	normalized := os.norm_path(path)
	if normalized.contains('..') && !path.starts_with(os.home_dir()) {
		return error('Path traversal not allowed outside home directory')
	}

	return normalized
}

struct BackupPlan {
	source_dirs []string
	dest_path   string
mut:
	total_files int
	total_size  i64
	items       []BackupItem
}

struct BackupItem {
	path        string
	size        i64
	is_dir      bool
	will_backup bool
	reason      string
}

fn run_quick_backup(incident Incident, config Config) {
	dest := config.quick_backup_dest

	// Validate destination
	if !os.exists(dest) {
		eprintln('${c_red}[ERROR]${c_reset} Backup destination does not exist: ${dest}')
		eprintln('${c_blue}[INFO]${c_reset} Please create the directory first or mount the drive.')
		log_error(incident.logs_path, 'backup', 'Backup destination does not exist', {
			'destination': dest
		})
		return
	}

	if !os.is_dir(dest) {
		eprintln('${c_red}[ERROR]${c_reset} Backup destination is not a directory: ${dest}')
		log_error(incident.logs_path, 'backup', 'Backup destination is not a directory', {
			'destination': dest
		})
		return
	}

	// Default source directories for quick backup
	home := os.home_dir()
	source_dirs := [
		os.join_path(home, 'Documents'),
		os.join_path(home, 'Desktop'),
		os.join_path(home, '.ssh'),
		os.join_path(home, '.gnupg'),
		os.join_path(home, '.config'),
	]

	println('')
	println('${c_blue}━━━ Quick Backup Preview ━━━${c_reset}')
	println('')

	// Create backup plan
	plan := create_backup_plan(source_dirs, dest)

	println('Source directories:')
	for dir in source_dirs {
		if os.exists(dir) {
			println('  ${c_green}✓${c_reset} ${dir}')
		} else {
			println('  ${c_yellow}○${c_reset} ${dir} (not found)')
		}
	}
	println('')
	println('Destination: ${dest}')
	println('')
	println('Summary:')
	println('  Files to backup: ${plan.total_files}')
	println('  Estimated size:  ${format_size(plan.total_size)}')
	println('')

	// Log the backup plan
	log_backup_plan(incident, plan, config)

	if config.dry_run {
		println('${c_cyan}[DRY-RUN]${c_reset} Would perform backup of ${plan.total_files} files')
		println('${c_cyan}[DRY-RUN]${c_reset} Backup log written to incident bundle')
		return
	}

	// Actually perform backup
	println('${c_blue}[INFO]${c_reset} Starting backup...')
	perform_backup(plan, incident, config)
}

fn create_backup_plan(source_dirs []string, dest string) BackupPlan {
	mut plan := BackupPlan{
		source_dirs: source_dirs
		dest_path: dest
		items: []
	}

	for dir in source_dirs {
		if !os.exists(dir) {
			continue
		}

		// Walk directory and count files
		scan_directory(dir, mut plan)
	}

	return plan
}

fn scan_directory(path string, mut plan BackupPlan) {
	entries := os.ls(path) or { return }

	for entry in entries {
		full_path := os.join_path(path, entry)

		// Skip hidden git directories to save space
		if entry == '.git' {
			continue
		}

		if os.is_dir(full_path) {
			// Recurse into subdirectories (with depth limit)
			depth := full_path.count(os.path_separator)
			if depth < 10 {
				scan_directory(full_path, mut plan)
			}
		} else {
			size := os.file_size(full_path)
			plan.total_files++
			plan.total_size += size

			plan.items << BackupItem{
				path: full_path
				size: size
				is_dir: false
				will_backup: true
			}
		}
	}
}

fn perform_backup(plan BackupPlan, incident Incident, config Config) {
	timestamp := time.now().custom_format('YYYYMMDD-HHmmss')

	// CRIT-002 fix: Validate destination path before use
	safe_dest := validate_safe_path(plan.dest_path) or {
		eprintln('${c_red}[ERROR]${c_reset} Invalid backup destination path: ${err}')
		log_error(incident.logs_path, 'backup', 'Invalid backup destination path', {
			'path': plan.dest_path
			'error': err.str()
		})
		return
	}

	backup_dir := os.join_path(safe_dest, 'emergency-backup-${timestamp}')

	os.mkdir_all(backup_dir) or {
		eprintln('${c_red}[ERROR]${c_reset} Failed to create backup directory: ${err}')
		log_error(incident.logs_path, 'backup', 'Failed to create backup directory', {
			'directory': backup_dir
			'error': err.str()
		})
		return
	}

	mut copied := 0
	mut failed := 0

	for dir in plan.source_dirs {
		if !os.exists(dir) {
			continue
		}

		// CRIT-002 fix: Validate source path before shell interpolation
		safe_source := validate_safe_path(dir) or {
			eprintln('${c_yellow}[WARN]${c_reset} Skipping unsafe path: ${dir}')
			log_warn(incident.logs_path, 'backup', 'Skipping unsafe source path: ${dir}')
			failed++
			continue
		}

		dir_name := os.base(safe_source)
		dest_dir := os.join_path(backup_dir, dir_name)

		// Validate constructed destination path
		safe_dest_dir := validate_safe_path(dest_dir) or {
			eprintln('${c_yellow}[WARN]${c_reset} Skipping invalid destination: ${dest_dir}')
			log_warn(incident.logs_path, 'backup', 'Skipping invalid destination: ${dest_dir}')
			failed++
			continue
		}

		// Use system copy for efficiency - paths are now validated
		$if windows {
			result := os.execute('xcopy /E /I /H /Y "${safe_source}" "${safe_dest_dir}"')
			if result.exit_code == 0 {
				copied++
				println('  ${c_green}✓${c_reset} ${dir_name}')
			} else {
				failed++
				println('  ${c_red}✗${c_reset} ${dir_name}')
			}
		} $else {
			result := os.execute('cp -r "${safe_source}" "${safe_dest_dir}" 2>/dev/null')
			if result.exit_code == 0 {
				copied++
				println('  ${c_green}✓${c_reset} ${dir_name}')
			} else {
				failed++
				println('  ${c_red}✗${c_reset} ${dir_name}')
			}
		}
	}

	println('')
	if failed == 0 {
		println('${c_green}[OK]${c_reset} Backup complete: ${backup_dir}')
	} else {
		println('${c_yellow}[WARN]${c_reset} Backup completed with ${failed} errors')
	}

	// Log backup result
	log_backup_result(incident, backup_dir, copied, failed)
}

fn log_backup_plan(incident Incident, plan BackupPlan, config Config) {
	log_path := os.join_path(incident.logs_path, 'backup_plan.log')

	mut lines := []string{}
	lines << 'schema_version: ${schema_version}'
	lines << ''
	lines << 'Quick Backup Plan'
	lines << '================='
	lines << ''
	lines << 'Destination: ${plan.dest_path}'
	lines << 'Total files: ${plan.total_files}'
	lines << 'Total size:  ${format_size(plan.total_size)}'
	lines << ''
	lines << 'Source directories:'
	for dir in plan.source_dirs {
		exists := if os.exists(dir) { 'exists' } else { 'not found' }
		lines << '  - ${dir} (${exists})'
	}
	lines << ''
	lines << 'Dry run: ${config.dry_run}'

	if config.dry_run {
		println('${c_cyan}[DRY-RUN]${c_reset} Would write backup plan to logs')
		return
	}

	// HIGH-006: Use atomic write to prevent corruption
	atomic_write_file(log_path, lines.join('\n')) or {
		eprintln('${c_yellow}[WARN]${c_reset} Could not write backup plan: ${err}')
	}
}

fn log_backup_result(incident Incident, backup_dir string, copied int, failed int) {
	log_path := os.join_path(incident.logs_path, 'backup_result.log')

	content := 'schema_version: ${schema_version}

Backup Result
=============

Backup directory: ${backup_dir}
Directories copied: ${copied}
Directories failed: ${failed}
Status: ${if failed == 0 { 'SUCCESS' } else { 'PARTIAL' }}
'

	// HIGH-006: Use atomic write to prevent corruption
	atomic_write_file(log_path, content) or {
		eprintln('${c_yellow}[WARN]${c_reset} Could not write backup result: ${err}')
	}
}

fn format_size(bytes i64) string {
	if bytes >= 1073741824 {
		return '${f64(bytes) / 1073741824.0:.1}G'
	} else if bytes >= 1048576 {
		return '${f64(bytes) / 1048576.0:.1}M'
	} else if bytes >= 1024 {
		return '${f64(bytes) / 1024.0:.1}K'
	}
	return '${bytes}B'
}
