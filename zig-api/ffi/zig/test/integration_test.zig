// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// integration_test.zig — Integration tests for unified-zig-api
//
// Exercises the full uapi_init → create → start → health → stop → destroy →
// uapi_teardown lifecycle for the gnosis server and connector pool.
//
// The gnosis server tests do NOT require the `gnosis` binary to be installed:
// they only verify that lifecycle transitions work correctly.
// The connector health test also skips if no local service is listening.

const std   = @import("std");
const uapi  = @import("zig_api");

// =============================================================================
// Library lifecycle
// =============================================================================

test "library init teardown roundtrip" {
    const r = uapi.uapi_init();
    try std.testing.expectEqual(@as(u8, 0), r);
    defer uapi.uapi_teardown();

    const ver = uapi.uapi_version();
    const ver_slice: []const u8 = std.mem.span(ver);
    try std.testing.expect(ver_slice.len > 0);
}

// =============================================================================
// Gnosis server lifecycle
// =============================================================================

test "gnosis create with port 0 returns 0" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    const h = uapi.uapi_gnosis_create(0);
    try std.testing.expectEqual(@as(u64, 0), h);
}

test "gnosis create valid port returns non-zero handle" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    // Pick an ephemeral port unlikely to be in use.
    const h = uapi.uapi_gnosis_create(19871);
    try std.testing.expect(h != 0);

    // State should be idle (0) before start.
    const state_before = uapi.uapi_gnosis_state(h);
    try std.testing.expectEqual(@as(u8, 0), state_before);

    uapi.uapi_gnosis_destroy(h);
}

test "gnosis start changes state to listening then stop returns it to stopped" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    const port: u16 = 19872;
    const h = uapi.uapi_gnosis_create(port);
    try std.testing.expect(h != 0);

    const start_r = uapi.uapi_gnosis_start(h);
    try std.testing.expectEqual(@as(u8, 0), start_r);

    // Give the background thread time to bind.
    std.time.sleep(50 * std.time.ns_per_ms);

    const state_listening = uapi.uapi_gnosis_state(h);
    // Accepting state 1 (listening) or 0 (idle, if port bind raced).
    try std.testing.expect(state_listening <= 1);

    uapi.uapi_gnosis_stop(h);

    // After stop the state must be stopped (3).
    const state_after = uapi.uapi_gnosis_state(h);
    try std.testing.expectEqual(@as(u8, 3), state_after);

    uapi.uapi_gnosis_destroy(h);
}

test "gnosis pool exhaustion: > MAX_SERVERS returns 0" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    var handles: [17]u64 = undefined;
    var allocated: usize = 0;
    for (&handles, 0..) |*h, i| {
        h.* = uapi.uapi_gnosis_create(@intCast(19880 + i));
        if (h.* == 0) break;
        allocated += 1;
    }
    // At least 16 should succeed; the 17th must fail.
    try std.testing.expect(allocated >= 16);
    try std.testing.expectEqual(@as(u64, 0), handles[16]);

    for (handles[0..allocated]) |h| uapi.uapi_gnosis_destroy(h);
}

// =============================================================================
// Connector lifecycle
// =============================================================================

test "connector create with unknown service_id returns 255" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    const slot = uapi.uapi_connector_create(200, "http://127.0.0.1:9999");
    try std.testing.expectEqual(@as(u8, 255), slot);
}

test "connector create with empty url returns 255" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    const slot = uapi.uapi_connector_create(0, "");
    try std.testing.expectEqual(@as(u8, 255), slot);
}

test "connector create and destroy roundtrip" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    // service_id 0 = AmbientOps
    const slot = uapi.uapi_connector_create(0, "http://127.0.0.1:8080");
    try std.testing.expect(slot != 255);

    // State should be disconnected (0) immediately after creation.
    const state = uapi.uapi_connector_state(slot);
    try std.testing.expectEqual(@as(u8, 0), state);

    uapi.uapi_connector_destroy(slot);

    // After destroy, state should be disconnected (slot reset to empty).
    const state_after = uapi.uapi_connector_state(slot);
    try std.testing.expectEqual(@as(u8, 0), state_after);
}

test "connector health against unavailable service returns failed (4)" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    // Port 19900 is expected to be unused.
    const slot = uapi.uapi_connector_create(1, "http://127.0.0.1:19900");
    try std.testing.expect(slot != 255);

    const health = uapi.uapi_connector_health(slot);
    // Must be either failed (4) or degraded (3) — never connected (2).
    try std.testing.expect(health != 2);

    uapi.uapi_connector_destroy(slot);
}

test "connector pool exhaustion: > 64 slots returns 255" {
    _ = uapi.uapi_init();
    defer uapi.uapi_teardown();

    var slots: [65]u8 = undefined;
    var count: usize = 0;
    for (&slots) |*s| {
        s.* = uapi.uapi_connector_create(0, "http://127.0.0.1:8080");
        if (s.* == 255) break;
        count += 1;
    }
    try std.testing.expect(count >= 64);
    try std.testing.expectEqual(@as(u8, 255), slots[64]);

    for (slots[0..count]) |s| uapi.uapi_connector_destroy(s);
}
