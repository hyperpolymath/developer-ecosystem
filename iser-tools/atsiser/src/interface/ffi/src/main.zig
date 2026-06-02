// Atsiser FFI Implementation
//
// This module implements the C-compatible FFI declared in src/interface/abi/Foreign.idr.
// All types and layouts must match the Idris2 ABI definitions.
//
// The FFI provides: C source analysis engine, ownership graph construction,
// ATS2 wrapper generation, and round-trip ATS2 → C compilation.
//
// SPDX-License-Identifier: MPL-2.0

const std = @import("std");

// Version information (keep in sync with Cargo.toml)
const VERSION = "0.1.0";
const BUILD_INFO = "atsiser built with Zig " ++ @import("builtin").zig_version_string;

/// Thread-local error storage
threadlocal var last_error: ?[]const u8 = null;

/// Set the last error message
fn setError(msg: []const u8) void {
    last_error = msg;
}

/// Clear the last error
fn clearError() void {
    last_error = null;
}

//==============================================================================
// Core Types (must match src/interface/abi/Types.idr)
//==============================================================================

/// Result codes (must match Idris2 Result type in Types.idr)
pub const Result = enum(c_int) {
    ok = 0,
    @"error" = 1,
    invalid_param = 2,
    out_of_memory = 3,
    null_pointer = 4,
    ownership_violation = 5,
    bounds_violation = 6,
};

/// Ownership states for tracked pointers (must match Idris2 OwnershipState)
pub const OwnershipState = enum(c_int) {
    unallocated = 0,
    owned = 1,
    borrowed = 2,
    consumed = 3,
    freed = 4,
};

/// Analysis engine handle (opaque to prevent direct access)
pub const Handle = opaque {
    allocator: std.mem.Allocator,
    initialized: bool,
    /// Number of allocation sites found during analysis
    allocation_count: u32,
    /// Number of ownership edges in the graph
    ownership_edge_count: u32,
    /// Number of proof obligations generated
    proof_count: u32,
    /// Number of buffer access sites detected
    buffer_count: u32,
};

//==============================================================================
// Library Lifecycle
//==============================================================================

/// Initialize the atsiser analysis engine.
/// Returns a handle, or null on failure.
export fn atsiser_init() ?*Handle {
    const allocator = std.heap.c_allocator;

    const handle = allocator.create(Handle) catch {
        setError("Failed to allocate atsiser engine handle");
        return null;
    };

    handle.* = .{
        .allocator = allocator,
        .initialized = true,
        .allocation_count = 0,
        .ownership_edge_count = 0,
        .proof_count = 0,
        .buffer_count = 0,
    };

    clearError();
    return handle;
}

/// Free the engine handle and all associated analysis state
export fn atsiser_free(handle: ?*Handle) void {
    const h = handle orelse return;
    const allocator = h.allocator;

    h.initialized = false;
    allocator.destroy(h);
    clearError();
}

//==============================================================================
// C Source Analysis
//==============================================================================

/// Parse a C header file and populate the analysis state.
/// Returns 0 on success, error code on failure.
export fn atsiser_parse_header(handle: ?*Handle, path: ?[*:0]const u8) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    _ = path orelse {
        setError("Null header path");
        return .invalid_param;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return .@"error";
    }

    // TODO: Implement C header parsing with tree-sitter or libclang bindings
    clearError();
    return .ok;
}

/// Analyse allocation patterns in parsed C sources.
/// Returns the number of allocation sites found.
export fn atsiser_analyse_allocations(handle: ?*Handle) u32 {
    const h = handle orelse return 0;
    if (!h.initialized) return 0;

    // TODO: Implement malloc/calloc/realloc/free pair tracking
    clearError();
    return h.allocation_count;
}

/// Build the pointer ownership graph from analysed sources.
/// Returns 0 on success, error code on failure.
export fn atsiser_build_ownership_graph(handle: ?*Handle) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return .@"error";
    }

    // TODO: Implement ownership graph construction
    clearError();
    return .ok;
}

/// Detect buffer access patterns (array indexing, pointer arithmetic).
/// Returns the number of buffer access sites found.
export fn atsiser_detect_buffers(handle: ?*Handle) u32 {
    const h = handle orelse return 0;
    if (!h.initialized) return 0;

    // TODO: Implement buffer access pattern detection
    clearError();
    return h.buffer_count;
}

//==============================================================================
// ATS2 Wrapper Generation
//==============================================================================

/// Generate ATS2 viewtype wrappers for all tracked pointers.
/// Writes .sats and .dats files to the output directory.
export fn atsiser_generate_viewtypes(handle: ?*Handle, output_dir: ?[*:0]const u8) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    _ = output_dir orelse {
        setError("Null output directory");
        return .invalid_param;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return .@"error";
    }

    // TODO: Implement ATS2 viewtype generation
    clearError();
    return .ok;
}

/// Generate ATS2 proof obligations (praxi/prfun) for ownership transfer.
export fn atsiser_generate_proofs(handle: ?*Handle, output_dir: ?[*:0]const u8) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    _ = output_dir orelse {
        setError("Null output directory");
        return .invalid_param;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return .@"error";
    }

    // TODO: Implement praxi/prfun proof generation
    clearError();
    return .ok;
}

/// Generate array bounds proofs for detected buffer accesses.
export fn atsiser_generate_bounds_proofs(handle: ?*Handle, output_dir: ?[*:0]const u8) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    _ = output_dir orelse {
        setError("Null output directory");
        return .invalid_param;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return .@"error";
    }

    // TODO: Implement arrayview bounds proof generation
    clearError();
    return .ok;
}

//==============================================================================
// ATS2 Compilation (Round-Trip)
//==============================================================================

/// Invoke patsopt to typecheck and compile ATS2 wrappers to C.
/// Returns 0 on success. Non-zero means proof obligations failed.
export fn atsiser_compile_ats2(handle: ?*Handle, ats2_dir: ?[*:0]const u8, c_output_dir: ?[*:0]const u8) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    _ = ats2_dir orelse {
        setError("Null ATS2 source directory");
        return .invalid_param;
    };

    _ = c_output_dir orelse {
        setError("Null C output directory");
        return .invalid_param;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return .@"error";
    }

    // TODO: Implement patsopt invocation for ATS2 → C compilation
    clearError();
    return .ok;
}

/// Verify that generated C code links against the original library.
export fn atsiser_verify_linkage(handle: ?*Handle, generated_c: ?[*:0]const u8, original_lib: ?[*:0]const u8) Result {
    const h = handle orelse {
        setError("Null handle");
        return .null_pointer;
    };

    _ = generated_c orelse {
        setError("Null generated C path");
        return .invalid_param;
    };

    _ = original_lib orelse {
        setError("Null original library path");
        return .invalid_param;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return .@"error";
    }

    // TODO: Implement linkage verification
    clearError();
    return .ok;
}

//==============================================================================
// Analysis Results
//==============================================================================

/// Get the number of allocation sites found
export fn atsiser_allocation_count(handle: ?*Handle) u32 {
    const h = handle orelse return 0;
    return h.allocation_count;
}

/// Get the number of ownership edges in the graph
export fn atsiser_ownership_edge_count(handle: ?*Handle) u32 {
    const h = handle orelse return 0;
    return h.ownership_edge_count;
}

/// Get the number of proof obligations generated
export fn atsiser_proof_count(handle: ?*Handle) u32 {
    const h = handle orelse return 0;
    return h.proof_count;
}

/// Get analysis report as a JSON string.
/// Caller must free the returned string with atsiser_free_string.
export fn atsiser_analysis_report(handle: ?*Handle) ?[*:0]const u8 {
    const h = handle orelse {
        setError("Null handle");
        return null;
    };

    if (!h.initialized) {
        setError("Engine not initialized");
        return null;
    }

    const report = std.fmt.allocPrintZ(h.allocator, "{{\"allocations\":{d},\"edges\":{d},\"proofs\":{d},\"buffers\":{d}}}", .{
        h.allocation_count,
        h.ownership_edge_count,
        h.proof_count,
        h.buffer_count,
    }) catch {
        setError("Failed to allocate report string");
        return null;
    };

    clearError();
    return report.ptr;
}

//==============================================================================
// String Operations
//==============================================================================

/// Free a string allocated by the library
export fn atsiser_free_string(str: ?[*:0]const u8) void {
    const s = str orelse return;
    const allocator = std.heap.c_allocator;
    const slice = std.mem.span(s);
    allocator.free(slice);
}

//==============================================================================
// Error Handling
//==============================================================================

/// Get the last error message.
/// Returns null if no error.
export fn atsiser_last_error() ?[*:0]const u8 {
    const err = last_error orelse return null;
    const allocator = std.heap.c_allocator;
    const c_str = allocator.dupeZ(u8, err) catch return null;
    return c_str.ptr;
}

//==============================================================================
// Version Information
//==============================================================================

/// Get the library version
export fn atsiser_version() [*:0]const u8 {
    return VERSION.ptr;
}

/// Get build information
export fn atsiser_build_info() [*:0]const u8 {
    return BUILD_INFO.ptr;
}

//==============================================================================
// Utility Functions
//==============================================================================

/// Check if handle is initialized
export fn atsiser_is_initialized(handle: ?*Handle) u32 {
    const h = handle orelse return 0;
    return if (h.initialized) 1 else 0;
}

//==============================================================================
// Tests
//==============================================================================

test "lifecycle" {
    const handle = atsiser_init() orelse return error.InitFailed;
    defer atsiser_free(handle);

    try std.testing.expect(atsiser_is_initialized(handle) == 1);
}

test "error handling" {
    const result = atsiser_parse_header(null, null);
    try std.testing.expectEqual(Result.null_pointer, result);

    const err = atsiser_last_error();
    try std.testing.expect(err != null);
}

test "version" {
    const ver = atsiser_version();
    const ver_str = std.mem.span(ver);
    try std.testing.expectEqualStrings(VERSION, ver_str);
}

test "analysis counts start at zero" {
    const handle = atsiser_init() orelse return error.InitFailed;
    defer atsiser_free(handle);

    try std.testing.expectEqual(@as(u32, 0), atsiser_allocation_count(handle));
    try std.testing.expectEqual(@as(u32, 0), atsiser_ownership_edge_count(handle));
    try std.testing.expectEqual(@as(u32, 0), atsiser_proof_count(handle));
}
