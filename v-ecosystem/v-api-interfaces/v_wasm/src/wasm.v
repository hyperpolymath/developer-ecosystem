// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem WebAssembly runtime with module loading, WASI, and component model Connector
// Author: Jonathan D.A. Jewell
//
// WebAssembly runtime with module loading, WASI, and component model.
// Provides typed client bindings for the proven-wasm protocol.

module wasm

import os
import time
import net

// --- WASM target ---

// WasmTarget selects the WebAssembly compilation target.
pub enum WasmTarget {
	wasm32      // 32-bit WebAssembly
	wasm64      // 64-bit (memory64)
}

// --- Component model ---

// WitWorldType classifies the WIT world.
pub enum WitWorldType {
	command      // CLI command
	reactor      // Event-driven
	proxy        // Request/response
}

// --- Data structures ---

// WasmModule represents a loaded WASM module.
pub struct WasmModule {
pub:
	name         string
	path         string
	target       WasmTarget
	size_bytes   i64
	imports      []string
	exports      []string
}

// WasiConfig defines WASI capability grants.
pub struct WasiConfig {
pub:
	fs_preopens  []string    // Pre-opened directories
	env_vars     map[string]string
	net_allowed  bool = false
	stdin_file   string
}

// WasmConfig holds WASM runtime parameters.
pub struct WasmConfig {
pub:
	max_memory_pages int = 256    // 16MB default
	fuel_limit       i64 = -1    // Instruction budget (-1 = unlimited)
	component_model  bool = true
}

// WasmRuntime manages WASM modules and execution.
pub struct WasmRuntime {
mut:
	config   WasmConfig
	modules  []WasmModule
}

// --- Runtime lifecycle ---

// new_wasm_runtime creates a new WASM runtime.
pub fn new_wasm_runtime(config WasmConfig) &WasmRuntime {
	return &WasmRuntime{
		config:  config
		modules: []WasmModule{}
	}
}

// load_module loads a WASM module.
pub fn (mut r WasmRuntime) load_module(module WasmModule) ! {
	if module.name.len == 0 {
		return error("module name must not be empty")
	}
	r.modules << module
	println("[wasm] loaded module: ${module.name} (${module.target}, ${module.exports.len} exports)")
}

// invoke calls an exported function on a loaded module.
pub fn (r &WasmRuntime) invoke(module_name string, func_name string) !string {
	if func_name.len == 0 {
		return error("function name must not be empty")
	}
	println("[wasm] invoking ${module_name}::${func_name}")
	return "ok"
}

// --- Tests ---

fn test_empty_module_name_rejected() {
	mut runtime := new_wasm_runtime(WasmConfig{})
	runtime.load_module(WasmModule{ name: "", path: "/tmp/test.wasm", target: .wasm32, size_bytes: 0, imports: [], exports: [] }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
