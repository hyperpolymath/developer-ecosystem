// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// gnosis.zig — HTTP/1.1 API server replacing v-grpc and v-rest
//
// Replaces:
//   developer-ecosystem/v-grpc/  (Render / Context / Health gRPC)
//   developer-ecosystem/v-rest/  (render / context / health / discovery REST)
//
// Both upstream callers shell out to the `gnosis` binary, so a single
// HTTP interface with both path families is sufficient.
//
// Route map (all handled in serveRequest):
//   POST /gnosis.GnosisService/Render  — gRPC-style compat
//   POST /render                       — REST compat
//   POST /gnosis.GnosisService/Context — gRPC-style compat
//   GET  /context                      — REST compat
//   POST /gnosis.GnosisService/Health  — gRPC-style compat
//   GET  /health                       — 200/503 for load balancers
//   GET  /                             — discovery / well-known
//
// Server pool: 16 concurrent gnosis server instances (MAX_SERVERS).
// Each instance runs a background thread that owns a std.net.Server.
// The exported uapi_gnosis_* functions are the C ABI entry points.

const std = @import("std");
const core = @import("core.zig");
const process = @import("process.zig");

// =============================================================================
// Constants
// =============================================================================

const MAX_SERVERS: usize    = 16;
const MAX_BODY_BYTES: usize = 256 * 1024; // 256 KiB request body cap
const OUT_BUF_SIZE: usize   = 1024 * 1024; // 1 MiB gnosis output buffer

// Response body for the discovery endpoint.
const DISCOVERY_BODY =
    \\{"service":"gnosis","version":"0.1.0","endpoints":["/render","/context","/health","/"]}
;

// =============================================================================
// ServerState enum  (must match ZigApi.ABI.Http.ServerState)
// =============================================================================

pub const ServerState = enum(u8) {
    idle     = 0,
    listening = 1,
    draining = 2,
    stopped  = 3,
};

// =============================================================================
// GnosisServer — one slot in the pool
// =============================================================================

const GnosisServer = struct {
    port:       u16,
    state:      ServerState,
    active:     bool,
    /// Background serve thread handle.
    thread:     ?std.Thread,
    /// Signals the serve loop to stop.
    stop_flag:  std.atomic.Value(bool),
    /// gnosis binary path (null-terminated, heap-owned by pool allocator).
    gnosis_bin: [:0]const u8,

    /// Return a zeroed-out default slot.
    fn empty() GnosisServer {
        return .{
            .port       = 0,
            .state      = .idle,
            .active     = false,
            .thread     = null,
            .stop_flag  = std.atomic.Value(bool).init(false),
            .gnosis_bin = "",
        };
    }
};

// =============================================================================
// Global pool + pool allocator
// =============================================================================

var pool_mutex: std.Thread.Mutex                         = .{};
var pool: [MAX_SERVERS]GnosisServer                      = undefined;
var pool_initialised: bool                               = false;
/// GPA for pool-level allocations (gnosis_bin strings, server threads).
var gpa: std.heap.GeneralPurposeAllocator(.{})           = .{};

fn poolAllocator() std.mem.Allocator {
    return gpa.allocator();
}

/// Must be called before any uapi_gnosis_* function.
pub fn init() void {
    pool_mutex.lock();
    defer pool_mutex.unlock();
    if (pool_initialised) return;
    for (&pool) |*s| s.* = GnosisServer.empty();
    pool_initialised = true;
}

pub fn teardown() void {
    pool_mutex.lock();
    defer pool_mutex.unlock();
    if (!pool_initialised) return; // idempotent
    for (&pool, 0..) |*s, i| {
        if (s.active) {
            stopServerSlot(i);
        }
    }
    _ = gpa.deinit();
    gpa = .{}; // reset so re-init works
    pool_initialised = false;
}

// =============================================================================
// Handle encoding  (handle = slot_index + 1; 0 = invalid)
// =============================================================================

fn handleFromIdx(idx: usize) u64 {
    return @as(u64, idx) + 1;
}

fn idxFromHandle(handle: u64) ?usize {
    if (handle == 0 or handle > MAX_SERVERS) return null;
    const idx: usize = @intCast(handle - 1);
    return idx;
}

// =============================================================================
// HTTP helpers
// =============================================================================

/// Write a minimal HTTP/1.1 response with a text body.
/// `status_code` e.g. 200, 400, 404, 503.
fn writeResponse(
    conn: *std.net.Server.Connection,
    status_code: u16,
    content_type: []const u8,
    body: []const u8,
) void {
    // Reuse a stack buffer for the status line + headers.
    var header_buf: [512]u8 = undefined;
    const headers = std.fmt.bufPrint(
        &header_buf,
        "HTTP/1.1 {d} \r\nContent-Type: {s}\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
        .{ status_code, content_type, body.len },
    ) catch return;

    const stream = conn.stream;
    stream.writeAll(headers) catch return;
    stream.writeAll(body) catch return;
}

/// Write a JSON 400 error response.
fn writeBadRequest(conn: *std.net.Server.Connection, msg: []const u8) void {
    var buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&buf, "{{\"error\":\"{s}\"}}", .{msg}) catch
        "{\"error\":\"bad request\"}";
    writeResponse(conn, 400, "application/json", body);
}

/// Write a JSON 500 error response.
fn writeInternalError(conn: *std.net.Server.Connection, msg: []const u8) void {
    var buf: [512]u8 = undefined;
    const body = std.fmt.bufPrint(&buf, "{{\"error\":\"{s}\"}}", .{msg}) catch
        "{\"error\":\"internal server error\"}";
    writeResponse(conn, 500, "application/json", body);
}

// =============================================================================
// Request body reading
// =============================================================================

/// Read the HTTP body up to MAX_BODY_BYTES.
/// Caller must free the returned slice with `allocator.free`.
fn readBody(
    allocator: std.mem.Allocator,
    stream: std.net.Stream,
    content_length: usize,
) ![]u8 {
    const to_read = @min(content_length, MAX_BODY_BYTES);
    const buf = try allocator.alloc(u8, to_read);
    var total: usize = 0;
    while (total < to_read) {
        const n = try stream.read(buf[total..]);
        if (n == 0) break;
        total += n;
    }
    return buf[0..total];
}

// =============================================================================
// Route handlers
// =============================================================================

/// POST /render  and  POST /gnosis.GnosisService/Render
/// Body (optional JSON): { "template": "/path/to/template.scm", "scm": "/path/to/file.scm" }
fn handleRender(
    conn: *std.net.Server.Connection,
    body: []const u8,
    gnosis_bin: []const u8,
    allocator: std.mem.Allocator,
) void {
    // Parse optional template + scm paths from the JSON body.
    var template_path: ?[]const u8 = null;
    var scm_path:      ?[]const u8 = null;

    // Simple extraction: look for "template":"..." and "scm":"..." keys.
    // Full JSON parsing would pull in a dependency; this covers the common case.
    if (body.len > 2) {
        template_path = extractJsonString(body, "template");
        scm_path      = extractJsonString(body, "scm");
    }

    var out_buf: [OUT_BUF_SIZE]u8 = undefined;
    const res = process.runGnosis(.{
        .gnosis_bin    = gnosis_bin,
        .template_path = template_path,
        .scm_path      = scm_path,
        .mode_flag     = "--json",
        .allocator     = allocator,
    }, &out_buf);

    switch (res.result) {
        .ok => writeResponse(conn, 200, "application/json", out_buf[0..res.len]),
        .denied => writeBadRequest(conn, "path rejected by allowlist"),
        .not_found => writeInternalError(conn, "gnosis binary not found"),
        .failed => writeInternalError(conn, core.lastError() orelse "gnosis failed"),
        .timeout => writeInternalError(conn, "gnosis timed out"),
        .oom => writeInternalError(conn, "out of memory"),
    }
}

/// POST /context  and  POST /gnosis.GnosisService/Context
/// Body (optional JSON): { "scm": "/path/to/file.scm" }
fn handleContext(
    conn: *std.net.Server.Connection,
    body: []const u8,
    gnosis_bin: []const u8,
    allocator: std.mem.Allocator,
) void {
    var scm_path: ?[]const u8 = null;
    if (body.len > 2) scm_path = extractJsonString(body, "scm");

    var out_buf: [OUT_BUF_SIZE]u8 = undefined;
    const res = process.runGnosis(.{
        .gnosis_bin    = gnosis_bin,
        .scm_path      = scm_path,
        .mode_flag     = "--plain",
        .allocator     = allocator,
    }, &out_buf);

    switch (res.result) {
        .ok      => writeResponse(conn, 200, "application/json", out_buf[0..res.len]),
        .denied  => writeBadRequest(conn, "path rejected by allowlist"),
        .not_found => writeInternalError(conn, "gnosis binary not found"),
        .failed  => writeInternalError(conn, core.lastError() orelse "gnosis failed"),
        .timeout => writeInternalError(conn, "gnosis timed out"),
        .oom     => writeInternalError(conn, "out of memory"),
    }
}

/// GET /health  and  POST /gnosis.GnosisService/Health
/// Returns 200 {"status":"serving"} if gnosis binary is reachable, 503 otherwise.
fn handleHealth(
    conn: *std.net.Server.Connection,
    gnosis_bin: []const u8,
    allocator: std.mem.Allocator,
) void {
    // Probe: run gnosis --version (fast, no file I/O).
    var res = process.runProcess(.{
        .exe        = gnosis_bin,
        .args       = &[_][]const u8{"--version"},
        .timeout_ms = 2_000,
        .allocator  = allocator,
    }) catch {
        writeResponse(conn, 503, "application/json",
            "{\"status\":\"not_serving\",\"reason\":\"gnosis unreachable\"}");
        return;
    };
    defer res.deinit();

    if (res.exit_code == 0) {
        writeResponse(conn, 200, "application/json", "{\"status\":\"serving\"}");
    } else {
        writeResponse(conn, 503, "application/json",
            "{\"status\":\"not_serving\",\"reason\":\"gnosis unhealthy\"}");
    }
}

/// GET / — service discovery.
fn handleDiscovery(conn: *std.net.Server.Connection) void {
    writeResponse(conn, 200, "application/json", DISCOVERY_BODY);
}

// =============================================================================
// JSON string extraction helper
// =============================================================================

/// Extract the string value for `key` from a flat JSON object.
/// Returns null if the key is absent or the value is not a string.
/// Only handles one level of nesting and unescaped ASCII values.
fn extractJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    // Look for `"key":"` pattern.
    var needle_buf: [128]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;
    const start_pos = std.mem.indexOf(u8, json, needle) orelse return null;
    const val_start = start_pos + needle.len;
    if (val_start >= json.len) return null;
    const end_pos = std.mem.indexOfScalarPos(u8, json, val_start, '"') orelse return null;
    return json[val_start..end_pos];
}

// =============================================================================
// Per-connection handler
// =============================================================================

const ServeCtx = struct {
    gnosis_bin: []const u8,
    allocator:  std.mem.Allocator,
};

/// Parse and dispatch one HTTP/1.1 request.
fn serveRequest(conn: *std.net.Server.Connection, ctx: ServeCtx) void {
    // Read the request line: "METHOD /path HTTP/1.1\r\n"
    var request_line_buf: [1024]u8 = undefined;
    const request_line = readLine(conn.stream, &request_line_buf) catch {
        writeBadRequest(conn, "malformed request line");
        return;
    };

    // Split into method, path, version.
    var parts = std.mem.splitScalar(u8, request_line, ' ');
    const method_str = parts.next() orelse {
        writeBadRequest(conn, "missing method");
        return;
    };
    const path_str = parts.next() orelse {
        writeBadRequest(conn, "missing path");
        return;
    };

    // Drain headers, extracting Content-Length.
    var content_length: usize = 0;
    var header_buf: [256]u8   = undefined;
    while (true) {
        const line = readLine(conn.stream, &header_buf) catch break;
        if (line.len == 0) break; // blank line = end of headers
        if (std.ascii.startsWithIgnoreCase(line, "content-length:")) {
            const val = std.mem.trimLeft(u8, line["content-length:".len..], " \t");
            content_length = std.fmt.parseInt(usize, val, 10) catch 0;
        }
    }

    // Read body if present.
    var body_slice: []const u8 = "";
    var body_owned: ?[]u8 = null;
    defer if (body_owned) |b| ctx.allocator.free(b);
    if (content_length > 0) {
        body_owned = readBody(ctx.allocator, conn.stream, content_length) catch {
            writeInternalError(conn, "failed to read request body");
            return;
        };
        body_slice = body_owned.?;
    }

    // Dispatch by method + path.
    const is_get  = std.mem.eql(u8, method_str, "GET");
    const is_post = std.mem.eql(u8, method_str, "POST");

    if (is_get and std.mem.eql(u8, path_str, "/health")) {
        handleHealth(conn, ctx.gnosis_bin, ctx.allocator);
    } else if (is_get and std.mem.eql(u8, path_str, "/context")) {
        handleContext(conn, body_slice, ctx.gnosis_bin, ctx.allocator);
    } else if (is_get and std.mem.eql(u8, path_str, "/")) {
        handleDiscovery(conn);
    } else if (is_post and (std.mem.eql(u8, path_str, "/render") or
               std.mem.eql(u8, path_str, "/gnosis.GnosisService/Render")))
    {
        handleRender(conn, body_slice, ctx.gnosis_bin, ctx.allocator);
    } else if (is_post and (std.mem.eql(u8, path_str, "/context") or
               std.mem.eql(u8, path_str, "/gnosis.GnosisService/Context")))
    {
        handleContext(conn, body_slice, ctx.gnosis_bin, ctx.allocator);
    } else if (is_post and std.mem.eql(u8, path_str, "/gnosis.GnosisService/Health")) {
        handleHealth(conn, ctx.gnosis_bin, ctx.allocator);
    } else {
        writeResponse(conn, 404, "application/json",
            "{\"error\":\"not found\"}");
    }
}

/// Read one CRLF-terminated line from `stream` into `buf`.
/// Returns the line without the trailing \r\n.
fn readLine(stream: std.net.Stream, buf: []u8) ![]const u8 {
    var pos: usize = 0;
    while (pos < buf.len) {
        const n = try stream.read(buf[pos..][0..1]);
        if (n == 0) break;
        if (buf[pos] == '\n') {
            // Strip trailing \r if present.
            const end = if (pos > 0 and buf[pos - 1] == '\r') pos - 1 else pos;
            return buf[0..end];
        }
        pos += 1;
    }
    return buf[0..pos];
}

// =============================================================================
// Serve thread entry point
// =============================================================================

const ServeThreadArgs = struct {
    idx:        usize,
    gnosis_bin: []const u8,
};

fn serveThread(args: ServeThreadArgs) void {
    // Each connection gets its own arena.
    var arena = std.heap.ArenaAllocator.init(poolAllocator());
    defer arena.deinit();

    const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, pool[args.idx].port);
    var net_server = std.net.Address.listen(addr, .{ .reuse_address = true }) catch |err| {
        core.setError("gnosis listen failed on port {d}: {}", .{ pool[args.idx].port, err });
        pool_mutex.lock();
        pool[args.idx].state = .stopped;
        pool_mutex.unlock();
        return;
    };
    defer net_server.deinit();

    pool_mutex.lock();
    pool[args.idx].state = .listening;
    pool_mutex.unlock();

    const ctx = ServeCtx{
        .gnosis_bin = args.gnosis_bin,
        .allocator  = arena.allocator(),
    };

    while (!pool[args.idx].stop_flag.load(.acquire)) {
        // Non-blocking accept via poll-style: set a short timeout.
        // std.net.Server.accept() is blocking; we rely on stop_flag checked
        // between connections.  Under light load the latency is acceptable.
        var conn = net_server.accept() catch |err| {
            if (err == error.WouldBlock) continue;
            // Any other error: log and break.
            core.setError("gnosis accept error: {}", .{err});
            break;
        };
        defer conn.stream.close();

        // Reset the arena between connections.
        _ = arena.reset(.retain_capacity);

        serveRequest(&conn, ctx);
    }

    pool_mutex.lock();
    pool[args.idx].state = .stopped;
    pool_mutex.unlock();
}

// =============================================================================
// Internal stop helper  (caller must hold pool_mutex)
// =============================================================================

fn stopServerSlot(idx: usize) void {
    pool[idx].stop_flag.store(true, .release);
    pool[idx].state = .draining;
    if (pool[idx].thread) |t| {
        // Unblock the accept() by connecting briefly.
        const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, pool[idx].port);
        if (std.net.tcpConnectToAddress(addr)) |conn| {
            conn.close();
        } else |_| {}
        // Temporarily release the lock while joining.
        pool_mutex.unlock();
        t.join();
        pool_mutex.lock();
        pool[idx].thread = null;
    }
    pool[idx].active = false;
    pool[idx].state  = .stopped;
}

// =============================================================================
// Exported C ABI  (uapi_gnosis_*)
// =============================================================================

/// Create a gnosis server bound to `port`.
/// Returns handle (non-zero on success, 0 on failure).
pub export fn uapi_gnosis_create(port: u16) callconv(.c) u64 {
    pool_mutex.lock();
    defer pool_mutex.unlock();

    if (!pool_initialised) {
        core.setError("gnosis: library not initialised — call uapi_init first", .{});
        return 0;
    }
    if (port == 0) {
        core.setError("gnosis: port 0 is invalid", .{});
        return 0;
    }

    for (&pool, 0..) |*s, i| {
        if (!s.active) {
            s.* = GnosisServer.empty();
            s.port   = port;
            s.active = true;
            s.state  = .idle;
            // Default gnosis binary: "gnosis" on $PATH.
            s.gnosis_bin = "gnosis";
            return handleFromIdx(i);
        }
    }
    core.setError("gnosis: pool exhausted (max {d} servers)", .{MAX_SERVERS});
    return 0;
}

/// Start serving — spawns a background thread.
/// Returns 0 (ok) or a non-zero Result tag on failure.
pub export fn uapi_gnosis_start(handle: u64) callconv(.c) u8 {
    const idx = idxFromHandle(handle) orelse {
        core.setError("gnosis: invalid handle {d}", .{handle});
        return core.Result.invalid_param.toU8();
    };

    pool_mutex.lock();
    defer pool_mutex.unlock();

    if (!pool[idx].active) return core.Result.invalid_param.toU8();
    if (pool[idx].state == .listening) return core.Result.ok.toU8(); // idempotent
    if (pool[idx].state != .idle) return core.Result.process_failed.toU8();

    pool[idx].stop_flag.store(false, .release);

    pool[idx].thread = std.Thread.spawn(
        .{},
        serveThread,
        .{ServeThreadArgs{ .idx = idx, .gnosis_bin = pool[idx].gnosis_bin }},
    ) catch |err| {
        core.setError("gnosis: thread spawn failed: {}", .{err});
        return core.Result.process_failed.toU8();
    };

    return core.Result.ok.toU8();
}

/// Signal the server to stop.
pub export fn uapi_gnosis_stop(handle: u64) callconv(.c) void {
    const idx = idxFromHandle(handle) orelse return;

    pool_mutex.lock();
    defer pool_mutex.unlock();

    if (!pool[idx].active) return;
    stopServerSlot(idx);
}

/// Destroy the server handle and free resources.
/// Caller must have called uapi_gnosis_stop first.
pub export fn uapi_gnosis_destroy(handle: u64) callconv(.c) void {
    const idx = idxFromHandle(handle) orelse return;

    pool_mutex.lock();
    defer pool_mutex.unlock();

    if (pool[idx].active) stopServerSlot(idx);
    pool[idx] = GnosisServer.empty();
}

/// Query server state.  Returns ServerState tag.
pub export fn uapi_gnosis_state(handle: u64) callconv(.c) u8 {
    const idx = idxFromHandle(handle) orelse return @intFromEnum(ServerState.stopped);
    pool_mutex.lock();
    defer pool_mutex.unlock();
    if (!pool[idx].active) return @intFromEnum(ServerState.stopped);
    return @intFromEnum(pool[idx].state);
}

/// Synchronous health probe.
/// Returns 0 (serving) if the gnosis binary responds, 1 (not_serving) otherwise.
pub export fn uapi_gnosis_health(handle: u64) callconv(.c) u8 {
    const idx = idxFromHandle(handle) orelse return 1;

    pool_mutex.lock();
    const active   = pool[idx].active;
    const state    = pool[idx].state;
    const bin_name = pool[idx].gnosis_bin;
    pool_mutex.unlock();

    if (!active or state != .listening) return 1;

    // Probe the binary directly.
    var arena = std.heap.ArenaAllocator.init(poolAllocator());
    defer arena.deinit();

    var result = process.runProcess(.{
        .exe        = bin_name,
        .args       = &[_][]const u8{"--version"},
        .timeout_ms = 2_000,
        .allocator  = arena.allocator(),
    }) catch return 1;
    defer result.deinit();

    return if (result.exit_code == 0) 0 else 1;
}

// =============================================================================
// Tests
// =============================================================================

test "extract json string present" {
    const json = "{\"template\":\"/tmp/t.scm\",\"scm\":\"/tmp/f.scm\"}";
    const t = extractJsonString(json, "template") orelse return error.Missing;
    try std.testing.expectEqualStrings("/tmp/t.scm", t);
    const s = extractJsonString(json, "scm") orelse return error.Missing;
    try std.testing.expectEqualStrings("/tmp/f.scm", s);
}

test "extract json string absent returns null" {
    const json = "{\"foo\":\"bar\"}";
    try std.testing.expectEqual(@as(?[]const u8, null), extractJsonString(json, "template"));
}

test "handle encoding roundtrip" {
    for (0..MAX_SERVERS) |i| {
        const h = handleFromIdx(i);
        const back = idxFromHandle(h) orelse return error.RoundtripFailed;
        try std.testing.expectEqual(i, back);
    }
    // handle 0 is invalid
    try std.testing.expectEqual(@as(?usize, null), idxFromHandle(0));
    // handle > MAX_SERVERS is invalid
    try std.testing.expectEqual(@as(?usize, null), idxFromHandle(MAX_SERVERS + 1));
}
