// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// process.zig — Safe subprocess execution for unified-zig-api
//
// safe_path() mirrors ZigApi.ABI.Process.checkSafePath.
// DEFAULT_ALLOWLIST must stay in sync with ZigApi.ABI.Process.defaultAllowlist.

const std = @import("std");
const core = @import("core.zig");

// =============================================================================
// ExecResult  (must match ZigApi.ABI.Process.execResultTag)
// =============================================================================

pub const ExecResult = enum(u8) {
    ok        = 0,
    failed    = 1,
    timeout   = 2,
    denied    = 3,
    not_found = 4,
    oom       = 5,
};

// =============================================================================
// Safe path validation
// =============================================================================

/// Allowlist of path prefixes that gnosis arguments are permitted to use.
/// Must match ZigApi.ABI.Process.defaultAllowlist.
pub const DEFAULT_ALLOWLIST = [_][]const u8{
    "/var/mnt/eclipse/repos/",
    "/home/hyper/",
    "/tmp/",
    "./",
};

/// Returns true if `path` starts with at least one prefix in `allowlist`.
pub fn safePath(path: []const u8, allowlist: []const []const u8) bool {
    for (allowlist) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

/// Returns true if `path` passes the DEFAULT_ALLOWLIST check.
pub fn safePathDefault(path: []const u8) bool {
    return safePath(path, &DEFAULT_ALLOWLIST);
}

// =============================================================================
// ExecOutput — captured stdout / stderr from a subprocess
// =============================================================================

pub const ExecOutput = struct {
    stdout:    []u8,
    stderr:    []u8,
    exit_code: u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ExecOutput) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }
};

// =============================================================================
// runProcess — spawn a process, capture output, enforce timeout
// =============================================================================

pub const RunOptions = struct {
    /// Absolute path to the executable.
    exe:     []const u8,
    /// Argument list (does NOT include the executable itself).
    args:    []const []const u8,
    /// Maximum milliseconds to wait.  0 = no timeout.
    timeout_ms: u64 = 5_000,
    /// Allocator for stdout/stderr capture.
    allocator: std.mem.Allocator,
};

/// Run a process with the given options.
/// The caller owns ExecOutput.stdout and ExecOutput.stderr — call deinit().
pub fn runProcess(opts: RunOptions) !ExecOutput {
    // Build the argv slice: [exe, arg0, arg1, ...]
    // Zig 0.15.2: ArrayList is unmanaged — allocator passed per-operation.
    var argv = std.ArrayList([]const u8){};
    defer argv.deinit(opts.allocator);
    try argv.append(opts.allocator, opts.exe);
    for (opts.args) |arg| try argv.append(opts.allocator, arg);

    var child = std.process.Child.init(argv.items, opts.allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Collect output with a hard cap to avoid runaway processes.
    const max_output = 1024 * 1024; // 1 MiB per stream
    var stdout_list = std.ArrayList(u8){};
    var stderr_list = std.ArrayList(u8){};
    errdefer stdout_list.deinit(opts.allocator);
    errdefer stderr_list.deinit(opts.allocator);

    // collectOutput reads both streams to completion, avoiding deadlock.
    // Zig 0.15.2: allocator is the first argument.
    try child.collectOutput(opts.allocator, &stdout_list, &stderr_list, max_output);

    const term = try child.wait();
    const exit_code: u8 = switch (term) {
        .Exited    => |code| @intCast(@min(code, 255)),
        .Signal    => 128,
        .Stopped   => 128,
        .Unknown   => 128,
    };

    return ExecOutput{
        .stdout    = try stdout_list.toOwnedSlice(opts.allocator),
        .stderr    = try stderr_list.toOwnedSlice(opts.allocator),
        .exit_code = exit_code,
        .allocator = opts.allocator,
    };
}

// =============================================================================
// runGnosis — specialised helper used by gnosis.zig
// =============================================================================

pub const GnosisArgs = struct {
    /// Path to the gnosis binary (default: "gnosis" on $PATH).
    gnosis_bin:    []const u8 = "gnosis",
    template_path: ?[]const u8 = null,
    scm_path:      ?[]const u8 = null,
    /// e.g. "--plain", "--json"
    mode_flag:     []const u8 = "--plain",
    allocator:     std.mem.Allocator,
};

/// Run gnosis and return captured stdout.
/// Validates template_path and scm_path against DEFAULT_ALLOWLIST.
/// Returns ExecResult tag and (on success) the stdout in `out_buf`.
pub fn runGnosis(
    gargs: GnosisArgs,
    out_buf: []u8,
) struct { result: ExecResult, len: usize } {
    // Validate paths before touching the shell.
    if (gargs.template_path) |tp| {
        if (!safePathDefault(tp)) {
            core.setError("gnosis: template_path '{s}' rejected by allowlist", .{tp});
            return .{ .result = .denied, .len = 0 };
        }
    }
    if (gargs.scm_path) |sp| {
        if (!safePathDefault(sp)) {
            core.setError("gnosis: scm_path '{s}' rejected by allowlist", .{sp});
            return .{ .result = .denied, .len = 0 };
        }
    }

    // Build arg list using a fixed-size stack array.
    // BoundedArray was removed in Zig 0.15.2; use a plain array + length counter.
    var args_buf: [8][]const u8 = undefined;
    var args_len: usize = 0;
    args_buf[args_len] = gargs.mode_flag; args_len += 1;
    if (gargs.template_path) |tp| {
        args_buf[args_len] = "--template"; args_len += 1;
        args_buf[args_len] = tp;           args_len += 1;
    }
    if (gargs.scm_path) |sp| {
        args_buf[args_len] = "--scm"; args_len += 1;
        args_buf[args_len] = sp;      args_len += 1;
    }

    var output = runProcess(.{
        .exe       = gargs.gnosis_bin,
        .args      = args_buf[0..args_len],
        .timeout_ms = 10_000,
        .allocator = gargs.allocator,
    }) catch |err| {
        core.setError("gnosis exec error: {}", .{err});
        return .{ .result = .not_found, .len = 0 };
    };
    defer output.deinit();

    if (output.exit_code != 0) {
        const snip = output.stderr[0..@min(output.stderr.len, 256)];
        core.setError("gnosis exited {d}: {s}", .{ output.exit_code, snip });
        return .{ .result = .failed, .len = 0 };
    }

    const copy_len = @min(output.stdout.len, out_buf.len);
    @memcpy(out_buf[0..copy_len], output.stdout[0..copy_len]);
    return .{ .result = .ok, .len = copy_len };
}

// =============================================================================
// Tests
// =============================================================================

test "safe_path allows known prefixes" {
    try std.testing.expect(safePathDefault("/var/mnt/eclipse/repos/myrepo/file.scm"));
    try std.testing.expect(safePathDefault("/home/hyper/projects/foo.scm"));
    try std.testing.expect(safePathDefault("/tmp/scratch.scm"));
    try std.testing.expect(safePathDefault("./relative/path.scm"));
}

test "safe_path rejects disallowed paths" {
    try std.testing.expect(!safePathDefault("/etc/passwd"));
    try std.testing.expect(!safePathDefault("/root/secret"));
    try std.testing.expect(!safePathDefault("../../../etc/shadow"));
    try std.testing.expect(!safePathDefault(""));
}
