// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Hardened server baseline enforcement with CIS benchmark compliance Connector
// Author: Jonathan D.A. Jewell
//
// Hardened server baseline enforcement with CIS benchmark compliance.
// Covers CIS Linux Benchmark controls for kernel, SSH, filesystem, and services.
// Provides typed client bindings for the proven-hardened protocol.

module hardened

import os

// --- Hardening feature ---

// HardeningFeature enumerates kernel and process hardening mechanisms.
pub enum HardeningFeature {
	aslr          // Address Space Layout Randomisation (KASLR/ASLR)
	nx            // No-Execute / DEP (NX bit in hardware)
	stack_canary  // Stack smashing protection (SSP / -fstack-protector)
	seccomp       // seccomp-bpf syscall filtering
	capsicum      // FreeBSD Capsicum capability mode
	pledge        // OpenBSD pledge(2) promise reduction
}

// HardeningProfile groups features to be enabled together.
pub struct HardeningProfile {
pub:
	name     string
	features []HardeningFeature
}

// feature_name returns the canonical string name of a hardening feature.
pub fn (f HardeningFeature) name() string {
	return match f {
		.aslr         { "ASLR" }
		.nx           { "NX" }
		.stack_canary { "STACK_CANARY" }
		.seccomp      { "SECCOMP" }
		.capsicum     { "CAPSICUM" }
		.pledge       { "PLEDGE" }
	}
}

// --- Compliance level ---

// ComplianceLevel indicates the CIS benchmark level.
pub enum ComplianceLevel {
	level_1  // Level 1: essential, minimal performance impact
	level_2  // Level 2: defence in depth, may affect usability
	custom   // Organisation-specific additional control
}

// --- Check result ---

// CheckResult reports a single hardening check outcome.
pub enum CheckResult {
	pass            // Control is applied correctly
	fail            // Control is not applied
	skip            // Not applicable to this system
	not_implemented // Check command not available on this platform
	error           // Check execution failed
}

// --- Data structures ---

// CISControl defines a single CIS benchmark hardening control.
pub struct CISControl {
pub:
	id          string          // CIS control ID, e.g. "1.1.2"
	title       string          // Human-readable title
	level       ComplianceLevel
	description string          // What this control does
	check_cmd   string          // Shell command to audit compliance (empty = manual)
	remediation string          // How to fix if failing
}

// HardeningCheck wraps a CISControl with its runtime result.
pub struct HardeningCheck {
pub:
	id          string          // CIS benchmark ID
	title       string
	level       ComplianceLevel
	result      CheckResult
	remediation string
	output      string          // Raw output from check_cmd
}

// HardeningReport summarises a full scan run.
pub struct HardeningReport {
pub:
	target_host string
	pass_count  int
	fail_count  int
	skip_count  int
	level       ComplianceLevel
	checks      []HardeningCheck
}

// HardenedConfig holds hardening scanner parameters.
pub struct HardenedConfig {
pub:
	target_host string
	level       ComplianceLevel = .level_1
	auto_fix    bool = false   // Experimental: apply remediations automatically
}

// HardenedScanner manages baseline compliance scanning.
pub struct HardenedScanner {
mut:
	config          HardenedConfig
	checks          []HardeningCheck
	active_features []HardeningFeature
}

// --- Hardening feature management ---

// enable activates a hardening feature, recording it in the active list.
pub fn (mut s HardenedScanner) enable(feature HardeningFeature) ! {
	if s.active_features.any(it == feature) {
		return error("feature ${feature.name()} is already enabled")
	}
	s.active_features << feature
	println("[hardened] enabled: ${feature.name()}")
}

// disable deactivates a hardening feature.
pub fn (mut s HardenedScanner) disable(feature HardeningFeature) ! {
	mut remaining := []HardeningFeature{}
	for f in s.active_features {
		if f != feature {
			remaining << f
		}
	}
	if remaining.len == s.active_features.len {
		return error("feature ${feature.name()} is not active")
	}
	s.active_features = remaining
	println("[hardened] disabled: ${feature.name()}")
}

// check_status returns whether a given hardening feature is currently active.
pub fn (s &HardenedScanner) check_status(feature HardeningFeature) !bool {
	return s.active_features.any(it == feature)
}

// apply_profile enables all features listed in a HardeningProfile.
pub fn (mut s HardenedScanner) apply_profile(profile HardeningProfile) ! {
	if profile.name.len == 0 {
		return error("profile name must not be empty")
	}
	for feature in profile.features {
		if !s.active_features.any(it == feature) {
			s.active_features << feature
		}
	}
	println("[hardened] applied profile: ${profile.name} (${profile.features.len} features)")
}

// list_active returns the currently active hardening features.
pub fn (s &HardenedScanner) list_active() ![]HardeningFeature {
	return s.active_features.clone()
}

// --- Built-in CIS controls ---

// cis_level1_controls returns the built-in Level 1 CIS Linux controls.
pub fn cis_level1_controls() []CISControl {
	return [
		CISControl{
			id:          '1.1.1'
			title:       'Disable unused filesystems: cramfs'
			level:       .level_1
			description: 'Unused filesystem modules increase attack surface.'
			check_cmd:   'modprobe -n -v cramfs 2>&1 | grep -q "Module cramfs not found" && echo PASS || echo FAIL'
			remediation: 'Add "install cramfs /bin/true" to /etc/modprobe.d/disable-filesystems.conf'
		},
		CISControl{
			id:          '1.1.2'
			title:       'Disable unused filesystems: squashfs'
			level:       .level_1
			description: 'Squashfs is rarely needed on hardened servers.'
			check_cmd:   'modprobe -n -v squashfs 2>&1 | grep -q "Module squashfs not found" && echo PASS || echo FAIL'
			remediation: 'Add "install squashfs /bin/true" to /etc/modprobe.d/disable-filesystems.conf'
		},
		CISControl{
			id:          '2.1.1'
			title:       'Disable xinetd service'
			level:       .level_1
			description: 'xinetd is a super-server not needed on modern systems.'
			check_cmd:   'systemctl is-enabled xinetd 2>/dev/null | grep -q disabled && echo PASS || echo FAIL'
			remediation: 'systemctl disable xinetd && systemctl stop xinetd'
		},
		CISControl{
			id:          '3.1.1'
			title:       'Disable IP forwarding'
			level:       .level_1
			description: 'Hosts that are not routers should not forward packets.'
			check_cmd:   'sysctl net.ipv4.ip_forward | grep -q "= 0" && echo PASS || echo FAIL'
			remediation: 'echo "net.ipv4.ip_forward = 0" >> /etc/sysctl.d/99-hardened.conf && sysctl -p'
		},
		CISControl{
			id:          '4.2.1'
			title:       'sshd: PermitRootLogin no'
			level:       .level_1
			description: 'Direct root SSH login must be disabled.'
			check_cmd:   'sshd -T 2>/dev/null | grep -qi "permitrootlogin no" && echo PASS || echo FAIL'
			remediation: 'Set "PermitRootLogin no" in /etc/ssh/sshd_config and restart sshd'
		},
		CISControl{
			id:          '4.2.2'
			title:       'sshd: MaxAuthTries 4'
			level:       .level_1
			description: 'Limit SSH authentication attempts to reduce brute-force risk.'
			check_cmd:   'sshd -T 2>/dev/null | grep -qi "maxauthtries [1-4]$" && echo PASS || echo FAIL'
			remediation: 'Set "MaxAuthTries 4" in /etc/ssh/sshd_config and restart sshd'
		},
		CISControl{
			id:          '4.2.3'
			title:       'sshd: PasswordAuthentication no'
			level:       .level_1
			description: 'Require public key authentication only.'
			check_cmd:   'sshd -T 2>/dev/null | grep -qi "passwordauthentication no" && echo PASS || echo FAIL'
			remediation: 'Set "PasswordAuthentication no" in /etc/ssh/sshd_config'
		},
		CISControl{
			id:          '4.2.4'
			title:       'sshd: Protocol 2 only'
			level:       .level_1
			description: 'SSH protocol version 1 is insecure and must not be used.'
			check_cmd:   'sshd -T 2>/dev/null | grep -qi "protocol 2" && echo PASS || echo FAIL'
			remediation: 'Ensure "Protocol 2" appears in /etc/ssh/sshd_config'
		},
		CISControl{
			id:          '5.1.1'
			title:       'Set default umask to 027'
			level:       .level_1
			description: 'Restrictive umask prevents world-readable file creation.'
			check_cmd:   'grep -r "^UMASK" /etc/login.defs | grep -q "027" && echo PASS || echo FAIL'
			remediation: 'Set "UMASK 027" in /etc/login.defs'
		},
		CISControl{
			id:          '6.1.1'
			title:       'Kernel: randomize_va_space=2'
			level:       .level_1
			description: 'Full ASLR hardens against memory corruption exploits.'
			check_cmd:   'sysctl kernel.randomize_va_space | grep -q "= 2" && echo PASS || echo FAIL'
			remediation: 'echo "kernel.randomize_va_space = 2" >> /etc/sysctl.d/99-hardened.conf'
		},
		CISControl{
			id:          '6.1.2'
			title:       'Kernel: dmesg_restrict=1'
			level:       .level_1
			description: 'Restrict dmesg access to root to reduce information leakage.'
			check_cmd:   'sysctl kernel.dmesg_restrict | grep -q "= 1" && echo PASS || echo FAIL'
			remediation: 'echo "kernel.dmesg_restrict = 1" >> /etc/sysctl.d/99-hardened.conf'
		},
		CISControl{
			id:          '6.1.3'
			title:       'Kernel: kptr_restrict=2'
			level:       .level_2
			description: 'Hide kernel symbol addresses from non-root users.'
			check_cmd:   'sysctl kernel.kptr_restrict | grep -q "= 2" && echo PASS || echo FAIL'
			remediation: 'echo "kernel.kptr_restrict = 2" >> /etc/sysctl.d/99-hardened.conf'
		},
		CISControl{
			id:          '6.2.1'
			title:       'Ensure /tmp is mounted with noexec'
			level:       .level_1
			description: 'Preventing execution from /tmp stops common exploit staging.'
			check_cmd:   'mount | grep -E "on /tmp " | grep -q noexec && echo PASS || echo FAIL'
			remediation: 'Add "noexec" to /tmp mount options in /etc/fstab'
		},
		CISControl{
			id:          '6.3.1'
			title:       'Disable core dumps'
			level:       .level_1
			description: 'Core dumps can leak sensitive memory contents.'
			check_cmd:   'ulimit -c | grep -q "^0$" && echo PASS || echo FAIL'
			remediation: 'Add "* hard core 0" to /etc/security/limits.conf'
		},
		CISControl{
			id:          '7.1.1'
			title:       'Ensure auditd is running'
			level:       .level_2
			description: 'Audit logging is required for forensic investigations.'
			check_cmd:   'systemctl is-active auditd | grep -q active && echo PASS || echo FAIL'
			remediation: 'systemctl enable auditd && systemctl start auditd'
		},
	]
}

// --- Check execution ---

// check_control evaluates a single CIS control, running its check_cmd if set.
// Returns a HardeningCheck populated with the result.
pub fn check_control(ctrl CISControl) HardeningCheck {
	if ctrl.check_cmd.len == 0 {
		return HardeningCheck{
			id:          ctrl.id
			title:       ctrl.title
			level:       ctrl.level
			result:      .not_implemented
			remediation: ctrl.remediation
			output:      'no check_cmd defined'
		}
	}
	result := os.execute(ctrl.check_cmd)
	output := result.output.trim_space()
	check_result := if result.exit_code == 0 && output.ends_with('PASS') {
		CheckResult.pass
	} else if result.exit_code != 0 {
		CheckResult.error
	} else {
		CheckResult.fail
	}
	return HardeningCheck{
		id:          ctrl.id
		title:       ctrl.title
		level:       ctrl.level
		result:      check_result
		remediation: ctrl.remediation
		output:      output
	}
}

// --- Scanner lifecycle ---

// new_hardened_scanner creates a new hardening scanner.
pub fn new_hardened_scanner(config HardenedConfig) &HardenedScanner {
	return &HardenedScanner{
		config: config
		checks: []HardeningCheck{}
	}
}

// run_check executes a single hardening check.
pub fn (mut s HardenedScanner) run_check(check HardeningCheck) ! {
	if check.id.len == 0 {
		return error('check id must not be empty')
	}
	s.checks << check
	println('[hardened] check ${check.id}: ${check.result}')
}

// run_all_level1_checks runs all built-in Level 1 controls and records results.
pub fn (mut s HardenedScanner) run_all_level1_checks() {
	for ctrl in cis_level1_controls() {
		if ctrl.level == .level_1 || ctrl.level == .level_2 {
			checked := check_control(ctrl)
			s.checks << checked
		}
	}
}

// summary returns pass/fail/skip counts.
pub fn (s &HardenedScanner) summary() (int, int, int) {
	mut pass_count := 0
	mut fail_count := 0
	mut skip_count := 0
	for c in s.checks {
		match c.result {
			.pass            { pass_count++ }
			.fail            { fail_count++ }
			.skip            { skip_count++ }
			.not_implemented { skip_count++ }
			.error           { fail_count++ }
		}
	}
	return pass_count, fail_count, skip_count
}

// report builds a HardeningReport from the scanner state.
pub fn (s &HardenedScanner) report() HardeningReport {
	pass, fail, skip := s.summary()
	return HardeningReport{
		target_host: s.config.target_host
		pass_count:  pass
		fail_count:  fail
		skip_count:  skip
		level:       s.config.level
		checks:      s.checks.clone()
	}
}

// --- Tests ---

fn test_empty_check_id_rejected() {
	mut scanner := new_hardened_scanner(HardenedConfig{ target_host: 'localhost' })
	scanner.run_check(HardeningCheck{ id: '', title: 'test', level: .level_1, result: .pass, remediation: '' }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_summary_counts_correctly() {
	mut scanner := new_hardened_scanner(HardenedConfig{ target_host: 'localhost' })
	scanner.run_check(HardeningCheck{ id: '1.1', title: 'A', level: .level_1, result: .pass, remediation: '' }) or { panic(err) }
	scanner.run_check(HardeningCheck{ id: '1.2', title: 'B', level: .level_1, result: .fail, remediation: 'fix it' }) or { panic(err) }
	scanner.run_check(HardeningCheck{ id: '1.3', title: 'C', level: .level_2, result: .skip, remediation: '' }) or { panic(err) }
	pass, fail, skip := scanner.summary()
	assert pass == 1
	assert fail == 1
	assert skip == 1
}

fn test_cis_controls_include_ssh_hardening() {
	controls := cis_level1_controls()
	ssh_controls := controls.filter(it.id.starts_with('4.2'))
	assert ssh_controls.len >= 3
}

fn test_enable_disable_feature_round_trip() {
	mut scanner := new_hardened_scanner(HardenedConfig{ target_host: 'localhost' })
	scanner.enable(.aslr) or { panic(err) }
	active := scanner.list_active() or { panic(err) }
	assert active.len == 1
	assert active[0] == HardeningFeature.aslr
	scanner.disable(.aslr) or { panic(err) }
	after := scanner.list_active() or { panic(err) }
	assert after.len == 0
}

fn test_apply_profile_enables_features() {
	mut scanner := new_hardened_scanner(HardenedConfig{ target_host: 'host1' })
	profile := HardeningProfile{ name: "baseline", features: [HardeningFeature.aslr, HardeningFeature.nx, HardeningFeature.stack_canary] }
	scanner.apply_profile(profile) or { panic(err) }
	active := scanner.list_active() or { panic(err) }
	assert active.len == 3
}

fn test_report_reflects_scanner_state() {
	mut scanner := new_hardened_scanner(HardenedConfig{ target_host: 'web01', level: .level_1 })
	scanner.run_check(HardeningCheck{ id: '6.1.1', title: 'ASLR', level: .level_1, result: .pass, remediation: '' }) or { panic(err) }
	rpt := scanner.report()
	assert rpt.target_host == 'web01'
	assert rpt.pass_count == 1
	assert rpt.checks.len == 1
}
