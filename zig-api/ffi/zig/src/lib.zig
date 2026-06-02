// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// lib.zig — Root entry point for libzig_api
//
// Re-exports all uapi_* symbols so the linker produces a single shared/static
// library.  Also provides the uapi_init / uapi_teardown / uapi_version
// lifecycle functions used by every consumer.
//
// Module layout:
//   core.zig      — result codes, error storage, generic Pool
//   process.zig   — subprocess execution, safe path validation, runGnosis
//   gnosis.zig    — HTTP/1.1 server pool (uapi_gnosis_*)
//   connector.zig — service connector pool (uapi_connector_*)

const std = @import("std");
pub const core      = @import("core.zig");
pub const process   = @import("process.zig");
pub const gnosis    = @import("gnosis.zig");
pub const connector = @import("connector.zig");

// Pull all exported symbols into the library's public namespace so they
// appear in the shared/static object without explicit re-export statements.
comptime {
    // gnosis server
    _ = gnosis.uapi_gnosis_create;
    _ = gnosis.uapi_gnosis_start;
    _ = gnosis.uapi_gnosis_stop;
    _ = gnosis.uapi_gnosis_destroy;
    _ = gnosis.uapi_gnosis_state;
    _ = gnosis.uapi_gnosis_health;
    _ = gnosis.uapi_gnosis_set_handler;
    _ = gnosis.uapi_gnosis_write_response;
    // connector pool
    _ = connector.uapi_connector_create;
    _ = connector.uapi_connector_health;
    _ = connector.uapi_connector_call;
    _ = connector.uapi_connector_destroy;
    _ = connector.uapi_connector_state;
    // library lifecycle (defined below)
    _ = uapi_init;
    _ = uapi_teardown;
    _ = uapi_version;
}

// =============================================================================
// Library lifecycle
// =============================================================================

/// One-time library initialisation.  Must be called before any uapi_* function.
/// Returns 0 (ok) on success, non-zero Result tag on failure.
///
/// Idempotent: safe to call multiple times (subsequent calls are no-ops).
pub export fn uapi_init() callconv(.c) u8 {
    core.clearError();
    gnosis.init();
    connector.init();
    return core.Result.ok.toU8();
}

/// Tear down all active servers and connectors and free library-level memory.
/// After this call the library is in an uninitialised state; call uapi_init
/// again before using any uapi_* functions.
pub export fn uapi_teardown() callconv(.c) void {
    gnosis.teardown();
    connector.teardown();
    core.clearError();
}

/// Null-terminated version string, e.g. "0.1.0".
/// Matches core.VERSION and the version field in build.zig.
pub export fn uapi_version() callconv(.c) [*:0]const u8 {
    return core.VERSION.ptr;
}

// =============================================================================
// Tests — exercise the full initialise/teardown cycle
// =============================================================================

test "uapi_init and teardown are idempotent" {
    _ = uapi_init();
    _ = uapi_init(); // second call must not panic or corrupt state
    uapi_teardown();
    uapi_teardown(); // second teardown must not panic
}

test "uapi_version is non-empty" {
    _ = uapi_init();
    defer uapi_teardown();
    const v = uapi_version();
    const v_slice: []const u8 = std.mem.span(v);
    try std.testing.expect(v_slice.len > 0);
}

// Bring in per-module tests so `zig build test` runs everything.
test {
    std.testing.refAllDecls(@This());
}
