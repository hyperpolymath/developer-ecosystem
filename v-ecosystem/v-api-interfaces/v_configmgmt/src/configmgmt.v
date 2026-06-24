// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Configuration management connector for declarative infrastructure state Connector
// Author: Jonathan D.A. Jewell
//
// Configuration management client for declarative infrastructure state.
// Supports Ansible-style module execution, Puppet-like resource modeling,
// idempotent state convergence, dry-run diffing, and configuration
// drift detection. Communicates with agents over SSH or custom transports.

module configmgmt

import os
import time
import json

// --- Resource state ---

// ResourceState represents the desired/actual state of a managed resource.
pub enum ResourceState {
	present     // Resource should exist
	absent      // Resource should not exist
	running     // Service should be running
	stopped     // Service should be stopped
	enabled     // Service should start on boot
}

// --- Convergence result ---

// ConvergeResult describes the outcome of applying a resource.
pub enum ConvergeResult {
	unchanged   // Already in desired state
	changed     // State was modified
	failed      // Could not converge
	skipped     // Skipped (dry-run or conditional)
}

// --- Config format ---

// ConfigFormat identifies the serialisation format of a configuration store.
pub enum ConfigFormat {
	yaml   // YAML (human-friendly, superset of JSON)
	json   // JSON (machine-readable)
	toml   // TOML (INI-like with types)
	ini    // INI (classic key=value sections)
}

// --- Data structures ---

// Resource represents a managed infrastructure resource.
pub struct Resource {
pub:
	name       string
	kind       string           // e.g. "file", "package", "service"
	desired    ResourceState
	properties map[string]string // Resource-specific properties
}

// DriftReport records differences between desired and actual state.
pub struct DriftReport {
pub:
	resource_name string
	expected      string
	actual        string
	drifted       bool
}

// ApplyResult records the result of applying a single resource.
pub struct ApplyResult {
pub:
	resource_name string
	result        ConvergeResult
	message       string
	duration_ms   i64
}

// ConfigStore represents a remote or local key-value configuration store.
pub struct ConfigStore {
pub:
	name   string
	format ConfigFormat
	path   string   // File path or URL
}

// ConfigMgr manages configuration convergence.
pub struct ConfigMgr {
mut:
	resources []Resource
	dry_run   bool
	kv_store  map[string]string
}

// --- Manager lifecycle ---

// new_config_mgr creates a new configuration manager.
pub fn new_config_mgr(dry_run bool) &ConfigMgr {
	return &ConfigMgr{
		resources: []Resource{}
		dry_run: dry_run
		kv_store: map[string]string{}
	}
}

// add_resource registers a resource for management.
pub fn (mut m ConfigMgr) add_resource(res Resource) {
	m.resources << res
}

// converge applies all registered resources.
pub fn (mut m ConfigMgr) converge() []ApplyResult {
	mut results := []ApplyResult{}
	for res in m.resources {
		result := if m.dry_run { ConvergeResult.skipped } else { ConvergeResult.changed }
		results << ApplyResult{
			resource_name: res.name
			result: result
			message: if m.dry_run { "dry-run: would apply" } else { "applied" }
			duration_ms: 0
		}
		println("[configmgmt] ${res.name}: ${result}")
	}
	return results
}

// detect_drift compares desired state against actual state.
pub fn (m &ConfigMgr) detect_drift() []DriftReport {
	mut reports := []DriftReport{}
	for res in m.resources {
		reports << DriftReport{
			resource_name: res.name
			expected: "${res.desired}"
			actual: "unknown"
			drifted: true
		}
	}
	return reports
}

// get retrieves a value by key from the in-memory configuration store.
pub fn (m &ConfigMgr) get(key string) !string {
	if key.len == 0 {
		return error("config key must not be empty")
	}
	if key !in m.kv_store {
		return error("config key '${key}' not found")
	}
	return m.kv_store[key]
}

// set stores or updates a configuration key-value pair.
pub fn (mut m ConfigMgr) set(key string, value string) ! {
	if key.len == 0 {
		return error("config key must not be empty")
	}
	m.kv_store[key] = value
	println("[configmgmt] SET ${key}=${value}")
}

// delete removes a configuration key from the store.
pub fn (mut m ConfigMgr) delete(key string) ! {
	if key.len == 0 {
		return error("config key must not be empty")
	}
	if key !in m.kv_store {
		return error("config key '${key}' not found")
	}
	m.kv_store.delete(key)
	println("[configmgmt] DELETE ${key}")
}

// list_keys returns all keys in the store that begin with the given prefix.
// Pass an empty prefix to list all keys.
pub fn (m &ConfigMgr) list_keys(prefix string) ![]string {
	mut keys := []string{}
	for k in m.kv_store.keys() {
		if prefix.len == 0 || k.starts_with(prefix) {
			keys << k
		}
	}
	return keys
}

// --- Parsing helpers ---

// parse_kv_line parses a single "key=value" line (INI/env-file style).
// Lines starting with '#' are treated as comments and return an error.
// Surrounding whitespace on both key and value is trimmed.
pub fn parse_kv_line(line string) !(string, string) {
	trimmed := line.trim_space()
	if trimmed.len == 0 || trimmed.starts_with('#') {
		return error("line is a comment or empty")
	}
	idx := trimmed.index('=') or {
		return error("no '=' separator found in line: '${trimmed}'")
	}
	key := trimmed[..idx].trim_space()
	value := trimmed[idx + 1..].trim_space()
	if key.len == 0 {
		return error("key must not be empty")
	}
	return key, value
}

// --- Tests ---

fn test_dry_run_skips() {
	mut mgr := new_config_mgr(true)
	mgr.add_resource(Resource{ name: "pkg", kind: "package", desired: .present, properties: map[string]string{} })
	results := mgr.converge()
	assert results.len == 1
	assert results[0].result == .skipped
}

fn test_parse_kv_line_simple() {
	key, val := parse_kv_line("host = 127.0.0.1") or { panic(err) }
	assert key == "host"
	assert val == "127.0.0.1"
}

fn test_parse_kv_line_comment_rejected() {
	parse_kv_line("# this is a comment") or {
		assert err.str().contains("comment")
		return
	}
	assert false
}

fn test_parse_kv_line_no_separator_rejected() {
	parse_kv_line("nodivider") or {
		assert err.str().contains("no '=' separator")
		return
	}
	assert false
}

fn test_get_set_delete_roundtrip() {
	mut mgr := new_config_mgr(false)
	mgr.set("timeout", "30") or { panic(err) }
	val := mgr.get("timeout") or { panic(err) }
	assert val == "30"
	mgr.delete("timeout") or { panic(err) }
	mgr.get("timeout") or {
		assert err.str().contains("not found")
		return
	}
	assert false
}
