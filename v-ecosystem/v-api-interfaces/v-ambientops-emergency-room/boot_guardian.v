// SPDX-License-Identifier: PMPL-1.0-or-later
// Boot Guardian - Boot health monitoring, loop detection, safe-mode triggering
// Addresses CC-002 (unsafe shutdowns) and CC-003 (PCIe link failures causing boot loops)
//
// Boot Guardian works by tracking boot events in a persistent stamp file.
// On each boot, it appends the current timestamp. If too many boots occur
// within a short window, it triggers safe-mode recommendations.
//
// Author: Jonathan D.A. Jewell

module main

import os
import time
import json

// ── Configuration ───────────────────────────────────────────────────────

// Maximum boots allowed within the detection window before flagging a loop
const boot_loop_threshold = 5
// Detection window in seconds (10 minutes)
const boot_loop_window_secs = 600
// Default boot stamp file location
const default_stamp_path = '/var/lib/ambientops/boot-guardian/stamps.json'

// ── Types ───────────────────────────────────────────────────────────────

// BootStampFile holds the persistent boot history for loop detection.
// Stored as JSON for easy machine parsing and human inspection.
struct BootStampFile {
mut:
	stamps       []BootStamp
	safe_mode    bool
	loop_count   int    // number of times a loop condition was detected
}

// BootStamp represents a single observed boot event.
struct BootStamp {
	timestamp     string  // RFC 3339
	kernel        string  // uname -r
	epoch_seconds i64     // unix epoch for arithmetic
	boot_id       string  // /proc/sys/kernel/random/boot_id (unique per boot)
}

// BootGuardianReport is the output of a boot health check.
struct BootGuardianReport {
	schema_version    string        @[json: 'schema_version']
	check_time        string        @[json: 'check_time']
	boot_loop_detected bool         @[json: 'boot_loop_detected']
	recent_boot_count int           @[json: 'recent_boot_count']
	window_seconds    int           @[json: 'window_seconds']
	threshold         int
	safe_mode_recommended bool      @[json: 'safe_mode_recommended']
	pcie_link_errors  []PcieLinkError @[json: 'pcie_link_errors']
	stamps            []BootStamp
}

// PcieLinkError represents a PCIe link failure detected from dmesg/sysfs.
// CC-003: These failures can cause repeated reboots when the kernel
// cannot negotiate a stable link with a device.
struct PcieLinkError {
	device     string  // PCI slot (e.g., "01:00.0")
	message    string  // error message from dmesg
	severity   string  // warning, error, critical
}

// ── Core Functions ──────────────────────────────────────────────────────

// record_boot appends the current boot to the stamp file.
// Called early in the boot process (e.g., from a systemd unit).
fn record_boot(stamp_path string, dry_run bool) !BootStampFile {
	mut stamps := load_stamps(stamp_path)

	// Read current boot_id to avoid duplicate entries
	current_boot_id := read_boot_id()
	for s in stamps.stamps {
		if s.boot_id == current_boot_id && current_boot_id.len > 0 {
			// Already recorded this boot — idempotent
			return stamps
		}
	}

	now := time.now()
	stamp := BootStamp{
		timestamp: now.format_rfc3339()
		kernel: get_kernel_version()
		epoch_seconds: now.unix()
		boot_id: current_boot_id
	}

	stamps.stamps << stamp

	// Prune stamps older than 24 hours to keep file bounded
	cutoff := now.unix() - 86400
	stamps.stamps = stamps.stamps.filter(it.epoch_seconds > cutoff)

	if dry_run {
		println('${c_cyan}[DRY-RUN]${c_reset} Would record boot stamp: ${stamp.timestamp}')
		return stamps
	}

	save_stamps(stamp_path, stamps)!
	return stamps
}

// check_boot_loop examines recent stamps and returns a health report.
// This is the primary diagnostic entry point.
fn check_boot_loop(stamp_path string) BootGuardianReport {
	stamps := load_stamps(stamp_path)
	now := time.now()
	cutoff := now.unix() - boot_loop_window_secs

	// Count boots within the detection window
	recent := stamps.stamps.filter(it.epoch_seconds > cutoff)
	loop_detected := recent.len >= boot_loop_threshold

	// Scan for PCIe link errors (CC-003)
	pcie_errors := scan_pcie_link_errors()

	// Safe mode is recommended if we detect a boot loop AND PCIe errors
	// (or if the loop count is extreme — more than 2x threshold)
	safe_mode := loop_detected && (pcie_errors.len > 0 || recent.len >= boot_loop_threshold * 2)

	return BootGuardianReport{
		schema_version: schema_version
		check_time: now.format_rfc3339()
		boot_loop_detected: loop_detected
		recent_boot_count: recent.len
		window_seconds: boot_loop_window_secs
		threshold: boot_loop_threshold
		safe_mode_recommended: safe_mode
		pcie_link_errors: pcie_errors
		stamps: recent
	}
}

// ── PCIe Link Error Detection (CC-003) ──────────────────────────────────

// scan_pcie_link_errors checks dmesg and sysfs for PCIe link failures.
// These are a common cause of boot loops on systems with flaky hardware
// (e.g., degraded NVMe, failing GPU, bad riser cable).
fn scan_pcie_link_errors() []PcieLinkError {
	mut errors := []PcieLinkError{}

	// Check dmesg for PCIe errors (best-effort, may need root)
	$if linux {
		result := os.execute('dmesg 2>/dev/null | grep -i "pcie\\|pcieport\\|link down\\|link training\\|AER" | tail -20')
		if result.exit_code == 0 {
			for line in result.output.split('\n') {
				trimmed := line.trim_space()
				if trimmed.len == 0 {
					continue
				}

				severity := classify_pcie_severity(trimmed)
				device := extract_pcie_device(trimmed)

				errors << PcieLinkError{
					device: device
					message: redact_pii(trimmed)
					severity: severity
				}
			}
		}

		// Also check for AER (Advanced Error Reporting) counts in sysfs
		aer_errors := scan_aer_counters()
		errors << aer_errors
	}

	return errors
}

// classify_pcie_severity determines the severity of a PCIe error message
fn classify_pcie_severity(line string) string {
	lower := line.to_lower()
	if lower.contains('fatal') || lower.contains('link down') {
		return 'critical'
	}
	if lower.contains('error') || lower.contains('uncorrectable') {
		return 'error'
	}
	if lower.contains('warning') || lower.contains('correctable') {
		return 'warning'
	}
	return 'warning'
}

// extract_pcie_device attempts to extract a PCI device address from a log line
fn extract_pcie_device(line string) string {
	// Look for patterns like "0000:01:00.0" or "01:00.0"
	// Simple string scanning — no regex needed
	for i := 0; i < line.len - 6; i++ {
		// Check for XX:XX.X pattern
		if i + 7 <= line.len &&
			is_hex_char(line[i]) && is_hex_char(line[i + 1]) &&
			line[i + 2] == `:` &&
			is_hex_char(line[i + 3]) && is_hex_char(line[i + 4]) &&
			line[i + 5] == `.` &&
			is_hex_char(line[i + 6]) {
			return line[i..i + 7]
		}
	}
	return 'unknown'
}

// is_hex_char returns true for 0-9, a-f, A-F
fn is_hex_char(c u8) bool {
	return (c >= `0` && c <= `9`) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}

// scan_aer_counters reads AER error counters from sysfs for all PCI devices
fn scan_aer_counters() []PcieLinkError {
	mut errors := []PcieLinkError{}

	$if linux {
		pci_path := '/sys/bus/pci/devices'
		devices := os.ls(pci_path) or { return errors }

		for dev in devices {
			aer_path := os.join_path(pci_path, dev, 'aer_dev_fatal')
			if os.exists(aer_path) {
				content := os.read_file(aer_path) or { continue }
				// Parse AER counters — non-zero means errors occurred
				for line in content.split('\n') {
					trimmed := line.trim_space()
					if trimmed.len == 0 {
						continue
					}
					// Format: "ErrorType    COUNT"
					// We care about non-zero counts
					parts := trimmed.split_any(' \t').filter(it.len > 0)
					if parts.len >= 2 {
						count := parts[parts.len - 1].int()
						if count > 0 {
							errors << PcieLinkError{
								device: dev
								message: 'AER fatal error: ${parts[0]} (count: ${count})'
								severity: 'critical'
							}
						}
					}
				}
			}
		}
	}

	return errors
}

// ── Persistence ─────────────────────────────────────────────────────────

// load_stamps reads the stamp file, returning empty state if not found
fn load_stamps(path string) BootStampFile {
	content := os.read_file(path) or {
		return BootStampFile{
			stamps: []
			safe_mode: false
			loop_count: 0
		}
	}

	return json.decode(BootStampFile, content) or {
		return BootStampFile{
			stamps: []
			safe_mode: false
			loop_count: 0
		}
	}
}

// save_stamps writes the stamp file atomically
fn save_stamps(path string, stamps BootStampFile) ! {
	// Ensure parent directory exists
	dir := os.dir(path)
	if !os.exists(dir) {
		os.mkdir_all(dir) or {
			return error('Failed to create stamp directory ${dir}: ${err}')
		}
	}

	content := json.encode_pretty(stamps)
	atomic_write_file(path, content)!
}

// read_boot_id reads the kernel's unique boot identifier
fn read_boot_id() string {
	$if linux {
		content := os.read_file('/proc/sys/kernel/random/boot_id') or { return '' }
		return content.trim_space()
	}
	return ''
}

// ── CLI Integration ─────────────────────────────────────────────────────

// run_boot_guardian is the CLI entry point for boot-guardian subcommand.
// Called from main.v when 'boot-guardian' subcommand is invoked.
fn run_boot_guardian(args []string) {
	mut fp := flag.new_flag_parser(args)
	fp.application('${app_name} boot-guardian')
	fp.description('Boot health monitoring and loop detection.\nAddresses CC-002 (unsafe shutdowns) and CC-003 (PCIe link failures).')

	stamp_path := fp.string('stamps', `s`, default_stamp_path, 'Path to boot stamp file')
	dry_run := fp.bool('dry-run', `n`, false, 'Preview actions without executing')
	record := fp.bool('record', `r`, false, 'Record current boot (run at startup)')
	check_only := fp.bool('check', `c`, false, 'Check boot health without recording')
	json_output := fp.bool('json', `j`, false, 'Output report as JSON')

	_ := fp.finalize() or {
		eprintln(fp.usage())
		exit(1)
	}

	if record {
		stamps := record_boot(stamp_path, dry_run) or {
			eprintln('${c_red}[ERROR]${c_reset} Failed to record boot: ${err}')
			exit(1)
		}
		println('${c_green}[OK]${c_reset} Boot recorded (${stamps.stamps.len} stamps in history)')
	}

	if check_only || !record {
		report := check_boot_loop(stamp_path)

		if json_output {
			println(json.encode_pretty(report))
			return
		}

		// Human-readable output
		println('')
		println('${c_blue}╔══════════════════════════════════════════╗${c_reset}')
		println('${c_blue}║${c_reset}       ${c_bold}BOOT GUARDIAN${c_reset}                      ${c_blue}║${c_reset}')
		println('${c_blue}╚══════════════════════════════════════════╝${c_reset}')
		println('')

		if report.boot_loop_detected {
			println('${c_red}[ALERT]${c_reset} Boot loop detected!')
			println('  ${report.recent_boot_count} boots in the last ${report.window_seconds / 60} minutes (threshold: ${report.threshold})')
		} else {
			println('${c_green}[OK]${c_reset} No boot loop detected')
			println('  ${report.recent_boot_count} boots in the last ${report.window_seconds / 60} minutes')
		}

		if report.pcie_link_errors.len > 0 {
			println('')
			println('${c_yellow}[WARN]${c_reset} PCIe link errors detected:')
			for err in report.pcie_link_errors {
				severity_color := match err.severity {
					'critical' { c_red }
					'error' { c_red }
					else { c_yellow }
				}
				println('  ${severity_color}[${err.severity}]${c_reset} ${err.device}: ${err.message}')
			}
		}

		if report.safe_mode_recommended {
			println('')
			println('${c_red}╔══════════════════════════════════════════╗${c_reset}')
			println('${c_red}║${c_reset}  ${c_bold}SAFE MODE RECOMMENDED${c_reset}                    ${c_red}║${c_reset}')
			println('${c_red}║${c_reset}                                            ${c_red}║${c_reset}')
			println('${c_red}║${c_reset}  Boot loop + PCIe errors detected.         ${c_red}║${c_reset}')
			println('${c_red}║${c_reset}  Consider booting with:                    ${c_red}║${c_reset}')
			println('${c_red}║${c_reset}    pci=noaer pci=nomsi                     ${c_red}║${c_reset}')
			println('${c_red}║${c_reset}  or blacklisting the failing device.       ${c_red}║${c_reset}')
			println('${c_red}╚══════════════════════════════════════════╝${c_reset}')
		}
	}
}
