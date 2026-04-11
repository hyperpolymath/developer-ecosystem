// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Integration tests for zig-groove-bridge.
//
// These tests probe real local services and are only meaningful when the
// relevant services are running.  They are intentionally lenient: if a
// service is not reachable the test still passes — we are testing the
// discovery logic, not the service itself.
//
// Run with: zig build test-integration

const std = @import("std");
const bridge = @import("groove_bridge");

// ── Offline tests (no network needed) ────────────────────────────────────────

test "probePort returns null for a port with nothing listening" {
    // Port 1 is reserved and almost certainly not accepting connections
    const result = bridge.probePort(std.testing.allocator, "nothing", 1);
    try std.testing.expect(result == null);
}

test "discoverAll returns without error even with no services running" {
    // May return empty list — that is still correct behaviour
    var list = try bridge.discoverAll(std.testing.allocator);
    defer list.deinit();
    // list.len() >= 0 is always true; confirms no crash and no leak
    _ = list.len();
}

test "attach returns ServiceNotFound for unknown service name" {
    const result = bridge.attach(std.testing.allocator, "this-service-does-not-exist-7654321");
    try std.testing.expectError(error.ServiceNotFound, result);
}
