// SPDX-License-Identifier: AGPL-3.0-or-later
// Example Zig library demonstrating ReScript FFI patterns

const std = @import("std");

// ============================================================================
// EXPORTED FUNCTIONS (C ABI for Deno FFI)
// ============================================================================

/// Add two integers
export fn add(a: i32, b: i32) callconv(.C) i32 {
    return a + b;
}

/// Multiply two integers
export fn multiply(a: i32, b: i32) callconv(.C) i32 {
    return a * b;
}

/// Calculate factorial (demonstrates recursion)
export fn factorial(n: u32) callconv(.C) u64 {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

/// Compute fibonacci number
export fn fibonacci(n: u32) callconv(.C) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    for (2..n + 1) |_| {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// ============================================================================
// STRING OPERATIONS
// ============================================================================

/// Get the length of a null-terminated string
export fn string_length(str: [*:0]const u8) callconv(.C) usize {
    return std.mem.len(str);
}

/// Check if string is empty
export fn string_is_empty(str: [*:0]const u8) callconv(.C) bool {
    return str[0] == 0;
}

// ============================================================================
// BUFFER OPERATIONS
// ============================================================================

/// Sum all bytes in a buffer
export fn buffer_sum(ptr: [*]const u8, len: usize) callconv(.C) u64 {
    var sum: u64 = 0;
    for (ptr[0..len]) |byte| {
        sum += byte;
    }
    return sum;
}

/// XOR all bytes in a buffer
export fn buffer_xor(ptr: [*]const u8, len: usize) callconv(.C) u8 {
    var result: u8 = 0;
    for (ptr[0..len]) |byte| {
        result ^= byte;
    }
    return result;
}

// ============================================================================
// VERSION INFO
// ============================================================================

pub const VERSION_MAJOR: u32 = 0;
pub const VERSION_MINOR: u32 = 1;
pub const VERSION_PATCH: u32 = 0;

/// Get library version as packed u32 (major << 16 | minor << 8 | patch)
export fn get_version() callconv(.C) u32 {
    return (VERSION_MAJOR << 16) | (VERSION_MINOR << 8) | VERSION_PATCH;
}

// ============================================================================
// TESTS
// ============================================================================

test "add" {
    try std.testing.expectEqual(@as(i32, 5), add(2, 3));
    try std.testing.expectEqual(@as(i32, 0), add(-5, 5));
}

test "factorial" {
    try std.testing.expectEqual(@as(u64, 1), factorial(0));
    try std.testing.expectEqual(@as(u64, 1), factorial(1));
    try std.testing.expectEqual(@as(u64, 120), factorial(5));
    try std.testing.expectEqual(@as(u64, 3628800), factorial(10));
}

test "fibonacci" {
    try std.testing.expectEqual(@as(u64, 0), fibonacci(0));
    try std.testing.expectEqual(@as(u64, 1), fibonacci(1));
    try std.testing.expectEqual(@as(u64, 55), fibonacci(10));
}

test "buffer_sum" {
    const data = [_]u8{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqual(@as(u64, 15), buffer_sum(&data, data.len));
}
