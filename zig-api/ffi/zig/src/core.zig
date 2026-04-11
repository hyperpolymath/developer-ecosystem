// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// core.zig — Base types and utilities for unified-zig-api
//
// All types here must stay in sync with src/abi/Types.idr.
// Tag values are the single source of truth — the Idris2 proofs verify
// that encoding/decoding is a roundtrip.

const std = @import("std");

// =============================================================================
// Result codes  (must match ZigApi.ABI.Types.resultTag)
// =============================================================================

pub const Result = enum(u8) {
    ok            = 0,
    err           = 1,
    invalid_param = 2,
    out_of_memory = 3,
    null_pointer  = 4,
    path_denied   = 5,
    process_failed = 6,
    timeout       = 7,
    not_found     = 8,
    already_exists = 9,
    slot_exhausted = 10,

    pub fn toU8(self: Result) u8 {
        return @intFromEnum(self);
    }
};

// =============================================================================
// Thread-local error storage
// =============================================================================

threadlocal var last_error_buf: [512]u8 = undefined;
threadlocal var last_error_len: usize   = 0;

pub fn setError(comptime fmt: []const u8, args: anytype) void {
    const msg = std.fmt.bufPrint(&last_error_buf, fmt, args) catch "error message truncated";
    last_error_len = msg.len;
}

pub fn clearError() void {
    last_error_len = 0;
}

pub fn lastError() ?[]const u8 {
    if (last_error_len == 0) return null;
    return last_error_buf[0..last_error_len];
}

// =============================================================================
// Pool — fixed-size mutex-protected slot pool
// Used by both the gnosis server pool and the connector pool.
// =============================================================================

pub fn Pool(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();
        const EMPTY: ?T = null;

        mutex:   std.Thread.Mutex = .{},
        slots:   [capacity]?T     = [_]?T{null} ** capacity,
        count:   usize            = 0,

        /// Acquire a free slot, store `item`, and return the slot index.
        /// Returns null if all slots are occupied.
        pub fn acquire(self: *Self, item: T) ?u8 {
            self.mutex.lock();
            defer self.mutex.unlock();
            for (&self.slots, 0..) |*slot, i| {
                if (slot.* == null) {
                    slot.* = item;
                    self.count += 1;
                    return @intCast(i);
                }
            }
            return null;
        }

        /// Read the item at `idx`.  Returns null if the slot is empty.
        pub fn get(self: *Self, idx: u8) ?*T {
            if (idx >= capacity) return null;
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.slots[idx]) |*item| return item;
            return null;
        }

        /// Release the slot at `idx`.
        pub fn release(self: *Self, idx: u8) void {
            if (idx >= capacity) return;
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.slots[idx] != null) {
                self.slots[idx] = null;
                self.count -|= 1;
            }
        }

        pub fn activeCount(self: *Self) usize {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.count;
        }
    };
}

// =============================================================================
// Version
// =============================================================================

pub const VERSION: [:0]const u8 = "0.1.0";

// =============================================================================
// Tests
// =============================================================================

test "pool acquire and release" {
    var pool: Pool(u32, 4) = .{};

    const s0 = pool.acquire(10) orelse return error.NoSlot;
    const s1 = pool.acquire(20) orelse return error.NoSlot;
    try std.testing.expectEqual(@as(usize, 2), pool.activeCount());

    pool.release(s0);
    try std.testing.expectEqual(@as(usize, 1), pool.activeCount());

    const s2 = pool.acquire(30) orelse return error.NoSlot;
    try std.testing.expectEqual(s0, s2); // slot 0 was reused
    _ = s1;
}

test "pool exhaustion" {
    var pool: Pool(u32, 2) = .{};
    _ = pool.acquire(1) orelse return error.NoSlot;
    _ = pool.acquire(2) orelse return error.NoSlot;
    const overflow = pool.acquire(3);
    try std.testing.expectEqual(@as(?u8, null), overflow);
}

test "error storage" {
    clearError();
    try std.testing.expectEqual(@as(?[]const u8, null), lastError());

    setError("test error {d}", .{42});
    const msg = lastError() orelse return error.NoError;
    try std.testing.expectEqualStrings("test error 42", msg);

    clearError();
    try std.testing.expectEqual(@as(?[]const u8, null), lastError());
}
