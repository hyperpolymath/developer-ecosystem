// SPDX-License-Identifier: PMPL-1.0-or-later
// Safe diagnostic capture modules
// Best-effort, non-destructive data collection
// HIGH-004 fix: PII redaction applied to all captured output
// CRIT-004 fix: Use string matching instead of regex (V regex doesn't support PCRE)

module main

import os
import time

struct CaptureResult {
	name       string
	success    bool
	output     string
	error_msg  string
	duration   i64
}

// Sensitive keywords that indicate PII when followed by = or :
const sensitive_keys = [
	'password', 'passwd', 'pwd', 'secret', 'token',
	'api_key', 'api-key', 'apikey',
	'auth_token', 'auth-token', 'authtoken',
	'access_token', 'access-token', 'accesstoken',
	'private_key', 'private-key', 'privatekey',
	'aws_secret', 'aws-secret',
	'bearer',
]

// Prefixes that indicate sensitive tokens (case-insensitive check)
const sensitive_prefixes = [
	'akia', 'abia', 'acca', 'asia',  // AWS keys
	'ghp_', 'gho_', 'ghu_', 'ghs_', 'ghr_',  // GitHub tokens
]

// CRIT-004: Redact sensitive information using string matching
// V's regex engine doesn't support PCRE lookaheads, so use direct string parsing
fn redact_pii(content string) string {
	mut lines := content.split('\n')
	mut result := []string{}

	for line in lines {
		result << redact_line(line)
	}

	return result.join('\n')
}

// Redact a single line for PII
fn redact_line(line string) string {
	lower := line.to_lower()
	mut redacted := line

	// Check for sensitive key=value or key: value patterns
	for key in sensitive_keys {
		if lower.contains(key) {
			// Find and redact the value after = or :
			redacted = redact_after_key(redacted, key, '=')
			redacted = redact_after_key(redacted, key, ':')
		}
	}

	// Check for AWS/GitHub token prefixes
	for prefix in sensitive_prefixes {
		if lower.contains(prefix) {
			redacted = redact_token_prefix(redacted, prefix)
		}
	}

	// Check for private key markers
	if lower.contains('-----begin') && lower.contains('private key') {
		redacted = '[REDACTED PRIVATE KEY BLOCK]'
	}

	// Check for SSN pattern (###-##-####)
	redacted = redact_ssn(redacted)

	// Check for email patterns (simple check)
	redacted = redact_emails(redacted)

	return redacted
}

// Redact value after a key and separator
fn redact_after_key(line string, key string, sep string) string {
	lower := line.to_lower()
	key_pos := lower.index(key) or { return line }

	// Find separator after key
	rest := line[key_pos + key.len..]
	sep_pos := rest.index(sep) or { return line }

	// Find the value (non-whitespace after separator)
	value_start := key_pos + key.len + sep_pos + 1
	if value_start >= line.len {
		return line
	}

	// Skip whitespace
	mut start := value_start
	for start < line.len && line[start] in [` `, `\t`] {
		start++
	}

	// Find end of value (whitespace or end)
	mut end := start
	for end < line.len && line[end] !in [` `, `\t`, `\n`, `\r`] {
		end++
	}

	if end > start {
		return line[..start] + '[REDACTED]' + line[end..]
	}
	return line
}

// Redact tokens starting with specific prefixes
fn redact_token_prefix(line string, prefix string) string {
	lower := line.to_lower()
	pos := lower.index(prefix) or { return line }

	// Find end of token (alphanumeric + underscore)
	mut end := pos + prefix.len
	for end < line.len {
		c := line[end]
		is_token_char := (c >= `a` && c <= `z`) ||
			(c >= `A` && c <= `Z`) ||
			(c >= `0` && c <= `9`) ||
			c == `_` || c == `-`
		if !is_token_char {
			break
		}
		end++
	}

	if end > pos + prefix.len {
		return line[..pos] + '[REDACTED]' + line[end..]
	}
	return line
}

// Redact SSN patterns (###-##-####)
fn redact_ssn(line string) string {
	mut result := line
	mut i := 0

	for i < result.len - 10 {
		// Check for ###-##-####
		if is_digit(result[i]) && is_digit(result[i + 1]) && is_digit(result[i + 2]) &&
			result[i + 3] == `-` &&
			is_digit(result[i + 4]) && is_digit(result[i + 5]) &&
			result[i + 6] == `-` &&
			is_digit(result[i + 7]) && is_digit(result[i + 8]) &&
			is_digit(result[i + 9]) && is_digit(result[i + 10]) {
			result = result[..i] + '[REDACTED-SSN]' + result[i + 11..]
			i += 14  // Length of [REDACTED-SSN]
		} else {
			i++
		}
	}

	return result
}

// Redact email addresses (simple pattern: word@word.word)
fn redact_emails(line string) string {
	mut result := line
	at_pos := result.index('@') or { return result }

	// Find start of email (word before @)
	mut start := at_pos
	for start > 0 && is_email_char(result[start - 1]) {
		start--
	}

	// Find end of email (word.word after @)
	mut end := at_pos + 1
	mut has_dot := false
	for end < result.len {
		c := result[end]
		if c == `.` {
			has_dot = true
			end++
		} else if is_email_char(c) {
			end++
		} else {
			break
		}
	}

	if has_dot && end > at_pos + 3 && start < at_pos {
		result = result[..start] + '[REDACTED-EMAIL]' + result[end..]
	}

	return result
}

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn is_email_char(c u8) bool {
	return (c >= `a` && c <= `z`) ||
		(c >= `A` && c <= `Z`) ||
		(c >= `0` && c <= `9`) ||
		c == `.` || c == `_` || c == `-` || c == `+` || c == `%`
}

fn capture_diagnostics(mut incident Incident, config Config) {
	// List of safe capture modules to run
	modules := [
		CaptureModule{'os_version', 'OS Version', get_os_version_commands()},
		CaptureModule{'uptime', 'System Uptime', get_uptime_commands()},
		CaptureModule{'disk_free', 'Disk Space', get_disk_commands()},
		CaptureModule{'memory', 'Memory Status', get_memory_commands()},
		CaptureModule{'network_summary', 'Network Summary', get_network_commands()},
		CaptureModule{'process_summary', 'Process Summary', get_process_commands()},
	]

	for mod in modules {
		result := run_capture_module(mod, incident, config)
		if result.success {
			println('  ${c_green}✓${c_reset} ${mod.display_name}')
		} else {
			println('  ${c_yellow}○${c_reset} ${mod.display_name} (skipped)')
		}

		// Log command execution
		incident.commands << CommandLog{
			name: mod.name
			command: mod.commands.join(' | ')
			started_at: time.now().format_rfc3339()
			ended_at: time.now().format_rfc3339()
			exit_code: if result.success { 0 } else { 1 }
			output_len: result.output.len
		}
	}

	// Update incident.json with command logs
	update_incident_json(incident, config)
}

struct CaptureModule {
	name         string
	display_name string
	commands     []string
}

fn run_capture_module(mod CaptureModule, incident Incident, config Config) CaptureResult {
	start := time.now()
	mut outputs := []string{}
	mut success := false

	for cmd in mod.commands {
		if config.dry_run {
			outputs << '[DRY-RUN] Would execute: ${cmd}'
			success = true
			continue
		}

		result := os.execute(cmd)
		if result.exit_code == 0 {
			outputs << '=== ${cmd} ==='
			outputs << result.output
			outputs << ''
			success = true
		}
	}

	raw_output := outputs.join('\n')
	// HIGH-004: Apply PII redaction before writing
	output := redact_pii(raw_output)
	duration := time.now() - start

	// Write to log file (with PII redacted)
	// HIGH-006: Use atomic write to prevent corruption
	if !config.dry_run && output.len > 0 {
		log_file := os.join_path(incident.logs_path, '${mod.name}.log')
		atomic_write_file(log_file, output) or {
			// HIGH-008: Log structured error
			log_error(incident.logs_path, 'capture', 'Failed to write log for ${mod.name}', {
				'module': mod.name
				'error': err.str()
			})
			return CaptureResult{
				name: mod.name
				success: false
				error_msg: 'Failed to write log: ${err}'
				duration: duration.milliseconds()
			}
		}
	}

	return CaptureResult{
		name: mod.name
		success: success
		output: output
		duration: duration.milliseconds()
	}
}

// Platform-specific command lists

fn get_os_version_commands() []string {
	$if linux {
		return [
			'cat /etc/os-release',
			'uname -a',
			'hostnamectl 2>/dev/null || true',
		]
	} $else $if macos {
		return [
			'sw_vers',
			'uname -a',
		]
	} $else $if windows {
		return [
			'systeminfo | findstr /B /C:"OS"',
			'ver',
		]
	} $else {
		return ['uname -a']
	}
}

fn get_uptime_commands() []string {
	$if linux {
		return [
			'uptime',
			'cat /proc/uptime',
		]
	} $else $if macos {
		return [
			'uptime',
		]
	} $else $if windows {
		return [
			'net statistics workstation | find "Statistics"',
		]
	} $else {
		return ['uptime']
	}
}

fn get_disk_commands() []string {
	$if linux {
		return [
			'df -h',
			'df -i',
			'lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null || true',
		]
	} $else $if macos {
		return [
			'df -h',
			'diskutil list',
		]
	} $else $if windows {
		return [
			'wmic logicaldisk get size,freespace,caption',
		]
	} $else {
		return ['df -h']
	}
}

fn get_memory_commands() []string {
	$if linux {
		return [
			'free -h',
			'cat /proc/meminfo | head -20',
		]
	} $else $if macos {
		return [
			'vm_stat',
			'top -l 1 | head -10',
		]
	} $else $if windows {
		return [
			'systeminfo | findstr Memory',
		]
	} $else {
		return []
	}
}

fn get_network_commands() []string {
	$if linux {
		return [
			'ip addr show 2>/dev/null || ifconfig',
			'ip route show 2>/dev/null || route -n',
			'ss -tuln 2>/dev/null || netstat -tuln',
		]
	} $else $if macos {
		return [
			'ifconfig',
			'netstat -rn',
			'netstat -an | head -50',
		]
	} $else $if windows {
		return [
			'ipconfig /all',
			'netstat -an | findstr LISTENING',
		]
	} $else {
		return []
	}
}

fn get_process_commands() []string {
	$if linux {
		return [
			'ps aux --sort=-%mem | head -20',
			'ps aux --sort=-%cpu | head -20',
		]
	} $else $if macos {
		return [
			'ps aux | head -20',
			'top -l 1 -o mem | head -20',
		]
	} $else $if windows {
		return [
			'tasklist /V | findstr /V "N/A"',
		]
	} $else {
		return ['ps aux | head -20']
	}
}
