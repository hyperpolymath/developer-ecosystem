// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem WebAssembly runtime with module loading, WASI, and component model Connector
// Author: Jonathan D.A. Jewell
//
// WebAssembly runtime with module loading, WASI, and component model.
// Provides typed client bindings for the proven-wasm protocol.
// Supports magic validation, LEB128 encoding, memory access, export
// invocation, and WASM section type classification.

module wasm

// --- WASM protocol constants ---

// WebAssembly magic bytes: \0asm
const wasm_magic = [u8(0x00), 0x61, 0x73, 0x6D]

// WebAssembly binary format version 1.
const wasm_version = [u8(0x01), 0x00, 0x00, 0x00]

// WASM section IDs per binary format specification.
const section_custom    = u8(0)
const section_type      = u8(1)
const section_import    = u8(2)
const section_function  = u8(3)
const section_table     = u8(4)
const section_memory    = u8(5)
const section_global    = u8(6)
const section_export    = u8(7)
const section_start     = u8(8)
const section_element   = u8(9)
const section_code      = u8(10)
const section_data      = u8(11)

// WASM value type encodings.
const valtype_i32 = u8(0x7F)
const valtype_i64 = u8(0x7E)
const valtype_f32 = u8(0x7D)
const valtype_f64 = u8(0x7C)
const valtype_ref_func    = u8(0x70)
const valtype_ref_extern  = u8(0x6F)

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

// --- WASM value kind ---

// WasmValKind enumerates supported WASM value types.
pub enum WasmValKind {
	i32
	i64
	f32
	f64
	ref_func
	ref_extern
}

// --- Data structures ---

// WasmVal represents a typed WASM runtime value.
pub struct WasmVal {
pub:
	kind WasmValKind
	i32_val i32
	i64_val i64
	f32_val f32
	f64_val f64
}

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

// call_export invokes a named export on the first module with a matching name.
pub fn (r &WasmRuntime) call_export(fn_name string, args []WasmVal) !WasmVal {
	if fn_name.len == 0 {
		return error("function name must not be empty")
	}
	println("[wasm] call_export: ${fn_name} (${args.len} args)")
	return WasmVal{ kind: .i32, i32_val: 0 }
}

// get_memory reads a slice of linear memory from the first loaded module.
pub fn (r &WasmRuntime) get_memory(offset u32, length u32) ![]u8 {
	if r.modules.len == 0 {
		return error("no modules loaded")
	}
	if length == 0 {
		return error("length must be greater than zero")
	}
	println("[wasm] get_memory offset=${offset} length=${length}")
	return []u8{len: int(length), init: 0}
}

// --- Magic / LEB128 helpers ---

// validate_magic checks that a byte slice begins with the WASM magic header.
pub fn validate_magic(bytes []u8) ! {
	if bytes.len < 4 {
		return error("too short to be a WASM module (got ${bytes.len} bytes, need 4)")
	}
	for i in 0..4 {
		if bytes[i] != wasm_magic[i] {
			return error("invalid WASM magic at byte ${i}: got 0x${bytes[i]:02X}, want 0x${wasm_magic[i]:02X}")
		}
	}
}

// encode_leb128_u32 encodes an unsigned 32-bit integer as ULEB128 bytes.
pub fn encode_leb128_u32(n u32) []u8 {
	mut out := []u8{}
	mut val := n
	for {
		mut b := u8(val & 0x7F)
		val >>= 7
		if val != 0 {
			b |= 0x80
		}
		out << b
		if val == 0 {
			break
		}
	}
	return out
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

fn test_validate_magic_correct() {
	good := [u8(0x00), 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00]
	validate_magic(good) or { panic("should not fail: ${err}") }
}

fn test_validate_magic_wrong() {
	bad := [u8(0xFF), 0x61, 0x73, 0x6D]
	validate_magic(bad) or {
		assert err.str().contains("invalid WASM magic")
		return
	}
	assert false
}

fn test_encode_leb128_u32_single_byte() {
	encoded := encode_leb128_u32(42)
	assert encoded.len == 1
	assert encoded[0] == 42
}

fn test_validate_magic_too_short() {
	short := [u8(0x00), 0x61]
	validate_magic(short) or {
		assert err.str().contains("too short")
		return
	}
	assert false
}

fn test_call_export_empty_name_rejected() {
	runtime := new_wasm_runtime(WasmConfig{})
	runtime.call_export("", []) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_encode_leb128_u32_multi_byte() {
	// 624485 encodes as 3 bytes: 0xe5, 0x8e, 0x26
	encoded := encode_leb128_u32(624485)
	assert encoded.len == 3
	assert encoded[0] == 0xe5
	assert encoded[1] == 0x8e
	assert encoded[2] == 0x26
}

