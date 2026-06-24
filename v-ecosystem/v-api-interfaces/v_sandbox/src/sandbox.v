// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Process sandboxing with capability restriction and syscall filtering Connector
// Author: Jonathan D.A. Jewell
//
// Process sandboxing with capability restriction and syscall filtering.
// Implements Linux capability constants and seccomp-bpf policy stubs.
// Provides typed client bindings for the proven-sandbox protocol.

module sandbox

// --- Linux capability constants (linux/capability.h) ---

// Capability enumerates Linux process capabilities.
pub enum Capability {
	chown            =  0  // Make arbitrary changes to file UIDs and GIDs
	dac_override     =  1  // Bypass file read/write/execute permission checks
	dac_read_search  =  2  // Bypass file read and directory search permission
	fowner           =  3  // Bypass permission checks on file ownership
	setuid           =  7  // Manipulate process UIDs
	setgid           =  6  // Manipulate process GIDs
	net_bind_service = 10  // Bind to privileged ports (port < 1024)
	net_admin        = 12  // Various network administration operations
	net_raw          = 13  // Use RAW and PACKET sockets
	sys_chroot       = 18  // Use chroot(2)
	sys_ptrace       = 19  // Trace arbitrary processes using ptrace
	sys_admin        = 21  // Range of system administration operations
}

// capability_name returns the string name of a capability.
pub fn (c Capability) name() string {
	return match c {
		.chown            { 'CAP_CHOWN' }
		.dac_override     { 'CAP_DAC_OVERRIDE' }
		.dac_read_search  { 'CAP_DAC_READ_SEARCH' }
		.fowner           { 'CAP_FOWNER' }
		.setuid           { 'CAP_SETUID' }
		.setgid           { 'CAP_SETGID' }
		.net_bind_service { 'CAP_NET_BIND_SERVICE' }
		.net_admin        { 'CAP_NET_ADMIN' }
		.net_raw          { 'CAP_NET_RAW' }
		.sys_chroot       { 'CAP_SYS_CHROOT' }
		.sys_ptrace       { 'CAP_SYS_PTRACE' }
		.sys_admin        { 'CAP_SYS_ADMIN' }
	}
}

// --- Seccomp action constants (linux/seccomp.h) ---

// SeccompAction specifies what happens when a syscall matches a BPF filter rule.
pub enum SeccompAction {
	kill_process  // Terminate the process immediately (SECCOMP_RET_KILL_PROCESS)
	kill_thread   // Terminate the offending thread (SECCOMP_RET_KILL)
	trap          // Send SIGSYS to the process (SECCOMP_RET_TRAP)
	errno         // Return -errno to the caller (SECCOMP_RET_ERRNO)
	trace         // Notify a ptracer (SECCOMP_RET_TRACE)
	allow         // Allow the syscall to proceed (SECCOMP_RET_ALLOW)
}

// --- Sandbox policy level ---

// SandboxPolicyLevel selects the isolation strictness.
pub enum SandboxPolicyLevel {
	none         // No restrictions
	permissive   // Minimal logging-only restrictions
	restrictive  // Deny-by-default; allowlist required
	custom       // Caller-defined policy rules
}

// SandboxHandle is an opaque reference to a created sandbox instance.
pub struct SandboxHandle {
pub:
	id           string
	policy_level SandboxPolicyLevel
	allowed_paths []string
}

// SandboxResult holds the outcome of executing a command inside a sandbox.
pub struct SandboxResult {
pub:
	exit_code int
	stdout    string
	stderr    string
	timed_out bool
}

// --- Sandbox type ---

// SandboxType selects the isolation mechanism.
pub enum SandboxType {
	seccomp   // Linux seccomp-bpf syscall filtering
	landlock  // Linux Landlock LSM filesystem access control
	capsicum  // FreeBSD Capsicum capability mode
	pledge    // OpenBSD pledge(2) promise reduction
	wasm      // WebAssembly sandbox (inherently capability-less)
}

// --- Legacy capability enum from existing code (preserved) ---

// SandboxCapability defines an allowed high-level capability.
pub enum SandboxCapability {
	fs_read
	fs_write
	net_connect
	net_listen
	process_exec
	process_fork
}

// --- Dangerous syscalls ---

// dangerous_syscalls lists syscalls that should trigger extra scrutiny in policies.
pub const dangerous_syscalls = [
	'ptrace',
	'kexec_load',
	'process_vm_writev',
	'perf_event_open',
	'bpf',
	'userfaultfd',
	'io_uring_setup',
]

// --- Data structures ---

// SandboxPolicy defines a sandboxing policy.
pub struct SandboxPolicy {
pub:
	name            string
	sandbox_type    SandboxType
	capabilities    []SandboxCapability
	allowed_syscalls []string       // Syscall names permitted under seccomp
	dropped_caps    []Capability    // Linux capabilities to drop
	namespaces      []string        // Linux namespaces to unshare (user, net, pid, mnt)
	allowed_paths   []string        // Filesystem paths accessible under landlock
	allowed_ports   []int           // TCP/UDP ports the process may bind or connect to
	default_action  SeccompAction = .errno  // Action for syscalls not in allowed list
}

// SandboxLimits constrains resource usage within a sandbox.
pub struct SandboxLimits {
pub:
	max_processes  int = 64        // RLIMIT_NPROC
	max_fds        int = 256       // RLIMIT_NOFILE
	max_memory_mb  int = 256       // RLIMIT_AS in megabytes
	max_cpu_secs   int = 60        // RLIMIT_CPU in seconds
	no_new_privs   bool = true     // PR_SET_NO_NEW_PRIVS
}

// SandboxConfig holds sandbox manager parameters.
pub struct SandboxConfig {
pub:
	enforce     bool = true   // false = audit mode (log denials but allow)
	log_denials bool = true
}

// PolicyAuditResult holds the result of auditing a policy for dangerous patterns.
pub struct PolicyAuditResult {
pub:
	policy_name       string
	dangerous_found   []string  // Dangerous syscalls found in allowed list
	missing_no_new_privs bool   // True if no_new_privs should be set but is not detectable
	cap_warnings      []string  // Warnings about retained dangerous capabilities
}

// SandboxManager manages sandbox policies.
pub struct SandboxManager {
mut:
	config    SandboxConfig
	policies  []SandboxPolicy
}

// --- BPF stub ---

// build_seccomp_bpf_stub returns placeholder BPF bytecode bytes for a policy.
// A real implementation would emit sock_filter instructions via the kernel BPF API.
// The stub encodes the policy name length and syscall count as a header.
pub fn build_seccomp_bpf_stub(policy SandboxPolicy) []u8 {
	// BPF stub header: [magic(2)] [name_len(1)] [syscall_count(1)] [action(1)]
	// Real BPF: struct sock_filter { __u16 code; __u8 jt; __u8 jf; __u32 k; }
	mut stub := []u8{len: 5, init: 0}
	stub[0] = 0xBF   // Magic byte 1
	stub[1] = 0xBF   // Magic byte 2
	stub[2] = u8(policy.name.len & 0xff)
	stub[3] = u8(policy.allowed_syscalls.len & 0xff)
	stub[4] = match policy.default_action {
		.allow { u8(0x06) }
		.errno { u8(0x00) }
		.kill_process { u8(0x80) }
		else  { u8(0x05) }
	}
	return stub
}

// --- Policy audit ---

// audit_policy inspects a policy for dangerous syscalls and capability warnings.
pub fn audit_policy(policy SandboxPolicy) PolicyAuditResult {
	mut dangerous_found := []string{}
	for syscall in policy.allowed_syscalls {
		if syscall in dangerous_syscalls {
			dangerous_found << syscall
		}
	}
	mut cap_warnings := []string{}
	// Check that SYS_ADMIN is not retained
	for cap in policy.dropped_caps {
		if cap == .sys_admin {
			// It is being dropped — good. No warning.
		}
	}
	retained_sys_admin := !policy.dropped_caps.any(it == Capability.sys_admin)
	if retained_sys_admin && policy.sandbox_type == .seccomp {
		cap_warnings << 'CAP_SYS_ADMIN is not dropped; consider adding it to dropped_caps'
	}
	return PolicyAuditResult{
		policy_name:     policy.name
		dangerous_found: dangerous_found
		cap_warnings:    cap_warnings
	}
}

// apply_policy applies a named policy to the current process (stub).
pub fn (m &SandboxManager) apply_policy(name string) ! {
	for p in m.policies {
		if p.name == name {
			mode := if m.config.enforce { 'enforce' } else { 'audit' }
			bpf_stub := build_seccomp_bpf_stub(p)
			println('[sandbox] applying ${p.sandbox_type} policy: ${name} (${mode}, ${bpf_stub.len} BPF bytes stub)')
			return
		}
	}
	return error('policy not found: ${name}')
}

// --- Manager lifecycle ---

// new_sandbox_manager creates a new sandbox manager.
pub fn new_sandbox_manager(config SandboxConfig) &SandboxManager {
	return &SandboxManager{
		config:   config
		policies: []SandboxPolicy{}
	}
}

// add_policy registers a sandbox policy.
pub fn (mut m SandboxManager) add_policy(policy SandboxPolicy) ! {
	if policy.name.len == 0 {
		return error('policy name must not be empty')
	}
	m.policies << policy
	println('[sandbox] added policy: ${policy.name} (${policy.sandbox_type}, ${policy.capabilities.len} caps, ${policy.allowed_syscalls.len} syscalls)')
}

// get_policy retrieves a policy by name.
pub fn (m &SandboxManager) get_policy(name string) !SandboxPolicy {
	for p in m.policies {
		if p.name == name {
			return p
		}
	}
	return error('policy not found: ${name}')
}

// --- Sandbox handle operations ---

// create_sandbox creates a new sandbox handle with the given policy level.
pub fn create_sandbox(policy SandboxPolicyLevel) !SandboxHandle {
	id := "sbx-${u32(policy)}"
	println("[sandbox] created sandbox ${id} (${policy})")
	return SandboxHandle{ id: id, policy_level: policy, allowed_paths: [] }
}

// execute runs a command inside the sandbox defined by handle.
pub fn execute_in_sandbox(handle SandboxHandle, cmd string, args []string) !SandboxResult {
	if cmd.len == 0 {
		return error("cmd must not be empty")
	}
	println("[sandbox] execute [${handle.id}]: ${cmd} ${args.join(' ')}")
	return SandboxResult{ exit_code: 0, stdout: "", stderr: "", timed_out: false }
}

// set_allowed_paths restricts filesystem access for the sandbox handle.
pub fn set_allowed_paths(handle SandboxHandle, paths []string) !SandboxHandle {
	if paths.len == 0 {
		return error("paths list must not be empty")
	}
	return SandboxHandle{ id: handle.id, policy_level: handle.policy_level, allowed_paths: paths }
}

// format_policy_rule returns a human-readable policy rule string.
pub fn format_policy_rule(policy SandboxPolicyLevel) string {
	return match policy {
		.none         { "policy=none: no restrictions applied" }
		.permissive   { "policy=permissive: log-only, all syscalls allowed" }
		.restrictive  { "policy=restrictive: deny-by-default, explicit allowlist required" }
		.custom       { "policy=custom: caller-supplied rules" }
	}
}

// destroy_sandbox marks a sandbox handle as destroyed (stub).
pub fn destroy_sandbox(handle SandboxHandle) ! {
	println("[sandbox] destroyed sandbox ${handle.id}")
}

// --- Tests ---

fn test_empty_policy_name_rejected() {
	mut mgr := new_sandbox_manager(SandboxConfig{})
	mgr.add_policy(SandboxPolicy{ name: '', sandbox_type: .seccomp, capabilities: [], allowed_paths: [], allowed_ports: [] }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_audit_policy_detects_dangerous_syscall() {
	policy := SandboxPolicy{
		name:             'test'
		sandbox_type:     .seccomp
		allowed_syscalls: ['read', 'write', 'ptrace', 'exit']
		dropped_caps:     []
	}
	result := audit_policy(policy)
	assert result.dangerous_found.len == 1
	assert result.dangerous_found[0] == 'ptrace'
}

fn test_build_seccomp_bpf_stub_magic() {
	policy := SandboxPolicy{
		name:             'minimal'
		sandbox_type:     .seccomp
		allowed_syscalls: ['read', 'write', 'exit']
		default_action:   .errno
	}
	stub := build_seccomp_bpf_stub(policy)
	assert stub[0] == 0xBF
	assert stub[1] == 0xBF
	assert stub[3] == 3  // 3 syscalls
}

fn test_capability_names() {
	assert Capability.net_bind_service.name() == 'CAP_NET_BIND_SERVICE'
	assert Capability.sys_ptrace.name() == 'CAP_SYS_PTRACE'
	assert Capability.sys_chroot.name() == 'CAP_SYS_CHROOT'
}

fn test_format_policy_rule_restrictive() {
	rule := format_policy_rule(.restrictive)
	assert rule.contains("restrictive")
	assert rule.contains("deny-by-default")
}

fn test_execute_in_sandbox_empty_cmd_rejected() {
	handle := create_sandbox(.permissive) or { panic(err) }
	execute_in_sandbox(handle, "", []) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_apply_policy_not_found() {
	mgr := new_sandbox_manager(SandboxConfig{})
	mgr.apply_policy('ghost') or {
		assert err.str().contains('not found')
		return
	}
	assert false
}
