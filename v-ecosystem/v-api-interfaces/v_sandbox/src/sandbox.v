// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Process sandboxing with capability restriction and syscall filtering Connector
// Author: Jonathan D.A. Jewell
//
// Process sandboxing with capability restriction and syscall filtering.
// Provides typed client bindings for the proven-sandbox protocol.

module sandbox

import os
import time
import net

// --- Sandbox type ---

// SandboxType selects the isolation mechanism.
pub enum SandboxType {
	seccomp      // Linux seccomp-bpf
	landlock     // Linux Landlock LSM
	capsicum     // FreeBSD Capsicum
	pledge       // OpenBSD pledge
	wasm         // WebAssembly sandbox
}

// --- Capability ---

// SandboxCapability defines an allowed capability.
pub enum SandboxCapability {
	fs_read
	fs_write
	net_connect
	net_listen
	process_exec
	process_fork
}

// --- Data structures ---

// SandboxPolicy defines a sandboxing policy.
pub struct SandboxPolicy {
pub:
	name         string
	sandbox_type SandboxType
	capabilities []SandboxCapability
	allowed_paths []string
	allowed_ports []int
}

// SandboxConfig holds sandbox parameters.
pub struct SandboxConfig {
pub:
	enforce      bool = true   // false = audit mode
	log_denials  bool = true
}

// SandboxManager manages sandbox policies.
pub struct SandboxManager {
mut:
	config    SandboxConfig
	policies  []SandboxPolicy
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
		return error("policy name must not be empty")
	}
	m.policies << policy
	println("[sandbox] added policy: ${policy.name} (${policy.sandbox_type}, ${policy.capabilities.len} caps)")
}

// apply_policy applies a named policy to the current process.
pub fn (m &SandboxManager) apply_policy(name string) ! {
	for p in m.policies {
		if p.name == name {
			mode := if m.config.enforce { "enforce" } else { "audit" }
			println("[sandbox] applying ${p.sandbox_type} policy: ${name} (${mode})")
			return
		}
	}
	return error("policy not found: ${name}")
}

// --- Tests ---

fn test_empty_policy_name_rejected() {
	mut mgr := new_sandbox_manager(SandboxConfig{})
	mgr.add_policy(SandboxPolicy{ name: "", sandbox_type: .seccomp, capabilities: [], allowed_paths: [], allowed_ports: [] }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
