// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// connector.zig — Generic service connector pool for unified-zig-api
//
// Manages a 64-slot pool of HTTP connectors, one per hyperpolymath service.
// Each slot stores a base URL and a ConnectorState, plus request statistics.
//
// ServiceId tags (0-10) must match ZigApi.ABI.Connector.serviceIdTag exactly.
// ConnectorState tags (0-5) must match ZigApi.ABI.Connector.connectorStateTag.
//
// The HTTP call implementation is a minimal HTTP/1.1 client built on
// std.http.Client.  No TLS for internal service calls (all intra-cluster);
// TLS would be layered on by the service mesh / Stapeln network policy.

const std = @import("std");
const core = @import("core.zig");

// =============================================================================
// ServiceId  (must match ZigApi.ABI.Connector.serviceIdTag)
// =============================================================================

pub const ServiceId = enum(u8) {
    ambient_ops   = 0,
    boj           = 1,
    burble        = 2,
    echidna       = 3,
    gossamer      = 4,
    groove_bridge = 5,
    hypatia       = 6,
    idaptik       = 7,
    reposystem    = 8,
    stapeln       = 9,
    verisimdb     = 10,
};

/// Returns the canonical listening port for a service.
pub fn defaultPort(sid: ServiceId) u16 {
    return switch (sid) {
        .ambient_ops   => 8080,
        .boj           => 3000,
        .burble        => 4000,
        .echidna       => 8090,
        .gossamer      => 9000,
        .groove_bridge => 7070,
        .hypatia       => 8100,
        .idaptik       => 5000,
        .reposystem    => 8200,
        .stapeln       => 8300,
        .verisimdb     => 9100,
    };
}

/// Returns the Groove discovery manifest path for a service.
pub fn groovePath(sid: ServiceId) []const u8 {
    return switch (sid) {
        .ambient_ops   => "/ambientops",
        .boj           => "/boj",
        .burble        => "/burble",
        .echidna       => "/echidna",
        .gossamer      => "/gossamer",
        .groove_bridge => "/groove-bridge",
        .hypatia       => "/hypatia",
        .idaptik       => "/idaptik",
        .reposystem    => "/reposystem",
        .stapeln       => "/stapeln",
        .verisimdb     => "/verisimdb",
    };
}

// =============================================================================
// ConnectorState  (must match ZigApi.ABI.Connector.connectorStateTag)
// =============================================================================

pub const ConnectorState = enum(u8) {
    disconnected = 0,
    connecting   = 1,
    connected    = 2,
    degraded     = 3,
    failed       = 4,
    draining     = 5,
};

// =============================================================================
// HTTP Method  (must match ZigApi.ABI.Http.methodTag)
// =============================================================================

pub const HttpMethod = enum(u8) {
    get     = 0,
    post    = 1,
    put     = 2,
    delete  = 3,
    head    = 4,
    options = 5,
    patch   = 6,
};

// =============================================================================
// Connector slot
// =============================================================================

const MAX_CONNECTORS: usize = 64;
const MAX_URL_LEN:    usize = 256;

const ConnectorSlot = struct {
    service_id:    ServiceId,
    state:         ConnectorState,
    active:        bool,
    /// Null-terminated base URL, e.g. "http://127.0.0.1:8080".
    base_url:      [MAX_URL_LEN:0]u8,
    base_url_len:  usize,
    /// Monotonic request counters.
    requests_ok:   u64,
    requests_err:  u64,
    /// Round-trip latency of last successful request (microseconds).
    last_latency_us: u64,

    fn empty() ConnectorSlot {
        var slot: ConnectorSlot = undefined;
        slot.service_id       = .ambient_ops;
        slot.state            = .disconnected;
        slot.active           = false;
        slot.base_url         = [_:0]u8{0} ** MAX_URL_LEN;
        slot.base_url_len     = 0;
        slot.requests_ok      = 0;
        slot.requests_err     = 0;
        slot.last_latency_us  = 0;
        return slot;
    }
};

// =============================================================================
// Global pool
// =============================================================================

var pool_mutex: std.Thread.Mutex           = .{};
var pool: [MAX_CONNECTORS]ConnectorSlot    = undefined;
var pool_initialised: bool                 = false;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};

pub fn init() void {
    pool_mutex.lock();
    defer pool_mutex.unlock();
    if (pool_initialised) return;
    for (&pool) |*s| s.* = ConnectorSlot.empty();
    pool_initialised = true;
}

pub fn teardown() void {
    pool_mutex.lock();
    defer pool_mutex.unlock();
    if (!pool_initialised) return; // idempotent
    for (&pool) |*s| s.* = ConnectorSlot.empty();
    _ = gpa.deinit();
    gpa = .{}; // reset so re-init works
    pool_initialised = false;
}

// =============================================================================
// HTTP client helper
// =============================================================================

/// Perform a synchronous HTTP request and write the response body into `out_buf`.
/// Returns the number of bytes written, or an error.
/// Uses std.http.Client.fetch (Zig 0.15.2 API).
fn httpCall(
    method: HttpMethod,
    url: []const u8,
    path: []const u8,
    body: []const u8,
    out_buf: []u8,
    allocator: std.mem.Allocator,
) !usize {
    // Construct the full URL.
    var url_buf: [512]u8 = undefined;
    const full_url = std.fmt.bufPrint(&url_buf, "{s}{s}", .{ url, path }) catch
        return error.UriTooLong;

    const http_method: std.http.Method = switch (method) {
        .get     => .GET,
        .post    => .POST,
        .put     => .PUT,
        .delete  => .DELETE,
        .head    => .HEAD,
        .options => .OPTIONS,
        .patch   => .PATCH,
    };

    // Use a fixed writer over out_buf to capture the response body.
    var writer = std.Io.Writer.fixed(out_buf);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const result = try client.fetch(.{
        .location         = .{ .url = full_url },
        .method           = http_method,
        .payload          = if (body.len > 0) body else null,
        .response_writer  = &writer,
        .extra_headers    = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    });
    _ = result; // status code not used here; errors surface as fetch errors

    return out_buf.len - writer.unusedCapacityLen();
}

// =============================================================================
// Exported C ABI  (uapi_connector_*)
// =============================================================================

/// Allocate a connector for `service_id` pointing at `base_url`.
/// Returns slot index (0..63), or 255 on failure.
pub export fn uapi_connector_create(service_id: u8, base_url_ptr: [*:0]const u8) callconv(.c) u8 {
    if (service_id > 10) {
        core.setError("connector: unknown service_id {d}", .{service_id});
        return 255;
    }

    const url_raw = std.mem.span(base_url_ptr);
    if (url_raw.len == 0 or url_raw.len >= MAX_URL_LEN) {
        core.setError("connector: base_url length {d} out of range", .{url_raw.len});
        return 255;
    }

    pool_mutex.lock();
    defer pool_mutex.unlock();

    if (!pool_initialised) {
        core.setError("connector: library not initialised", .{});
        return 255;
    }

    for (&pool, 0..) |*slot, i| {
        if (!slot.active) {
            slot.* = ConnectorSlot.empty();
            slot.service_id    = @enumFromInt(service_id);
            slot.active        = true;
            slot.state         = .disconnected;
            slot.base_url_len  = url_raw.len;
            @memcpy(slot.base_url[0..url_raw.len], url_raw);
            slot.base_url[url_raw.len] = 0;
            return @intCast(i);
        }
    }
    core.setError("connector: pool exhausted (max {d})", .{MAX_CONNECTORS});
    return 255;
}

/// Health check the connector at `slot_idx`.  Returns ConnectorState tag.
/// Performs a lightweight GET /health probe.
pub export fn uapi_connector_health(slot_idx: u8) callconv(.c) u8 {
    if (slot_idx >= MAX_CONNECTORS) return @intFromEnum(ConnectorState.failed);

    pool_mutex.lock();
    if (!pool[slot_idx].active) {
        pool_mutex.unlock();
        return @intFromEnum(ConnectorState.failed);
    }
    const url_len = pool[slot_idx].base_url_len;
    var url_copy: [MAX_URL_LEN]u8 = undefined;
    @memcpy(url_copy[0..url_len], pool[slot_idx].base_url[0..url_len]);
    pool_mutex.unlock();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var out_buf: [256]u8 = undefined;
    const n = httpCall(.get, url_copy[0..url_len], "/health", "", &out_buf, arena.allocator()) catch {
        pool_mutex.lock();
        if (pool[slot_idx].active) pool[slot_idx].state = .failed;
        pool_mutex.unlock();
        return @intFromEnum(ConnectorState.failed);
    };
    _ = n;

    pool_mutex.lock();
    if (pool[slot_idx].active) pool[slot_idx].state = .connected;
    pool_mutex.unlock();
    return @intFromEnum(ConnectorState.connected);
}

/// Send a JSON-body request.
/// `method_tag` is an HttpMethod tag.  `path_ptr` is a null-terminated sub-path.
/// `body_ptr` is a null-terminated JSON string (empty for GET).
/// Writes response JSON into `out_buf` (max `out_len` bytes).
/// Returns Result tag.
pub export fn uapi_connector_call(
    slot_idx:   u8,
    method_tag: u8,
    path_ptr:   [*:0]const u8,
    body_ptr:   [*:0]const u8,
    out_buf:    [*]u8,
    out_len:    u32,
) callconv(.c) u8 {
    if (slot_idx >= MAX_CONNECTORS or method_tag > 6) {
        core.setError("connector: invalid slot or method", .{});
        return core.Result.invalid_param.toU8();
    }

    pool_mutex.lock();
    if (!pool[slot_idx].active) {
        pool_mutex.unlock();
        core.setError("connector: slot {d} not active", .{slot_idx});
        return core.Result.invalid_param.toU8();
    }
    const url_len = pool[slot_idx].base_url_len;
    var url_copy: [MAX_URL_LEN]u8 = undefined;
    @memcpy(url_copy[0..url_len], pool[slot_idx].base_url[0..url_len]);
    pool_mutex.unlock();

    const path = std.mem.span(path_ptr);
    const body = std.mem.span(body_ptr);
    const method: HttpMethod = @enumFromInt(method_tag);
    const response_buf = out_buf[0..out_len];

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const t_start = std.time.microTimestamp();
    const n = httpCall(method, url_copy[0..url_len], path, body, response_buf, arena.allocator()) catch |err| {
        core.setError("connector call error: {}", .{err});
        pool_mutex.lock();
        if (pool[slot_idx].active) {
            pool[slot_idx].state = .failed;
            pool[slot_idx].requests_err += 1;
        }
        pool_mutex.unlock();
        return core.Result.process_failed.toU8();
    };
    const latency_us: u64 = @intCast(@max(0, std.time.microTimestamp() - t_start));
    _ = n;

    pool_mutex.lock();
    if (pool[slot_idx].active) {
        pool[slot_idx].state          = .connected;
        pool[slot_idx].requests_ok   += 1;
        pool[slot_idx].last_latency_us = latency_us;
    }
    pool_mutex.unlock();

    return core.Result.ok.toU8();
}

/// Release the connector at `slot_idx` and return it to the pool.
pub export fn uapi_connector_destroy(slot_idx: u8) callconv(.c) void {
    if (slot_idx >= MAX_CONNECTORS) return;
    pool_mutex.lock();
    defer pool_mutex.unlock();
    pool[slot_idx] = ConnectorSlot.empty();
}

/// Get current ConnectorState tag for `slot_idx`.
pub export fn uapi_connector_state(slot_idx: u8) callconv(.c) u8 {
    if (slot_idx >= MAX_CONNECTORS) return @intFromEnum(ConnectorState.failed);
    pool_mutex.lock();
    defer pool_mutex.unlock();
    if (!pool[slot_idx].active) return @intFromEnum(ConnectorState.disconnected);
    return @intFromEnum(pool[slot_idx].state);
}

// =============================================================================
// Tests
// =============================================================================

test "service id default ports" {
    try std.testing.expectEqual(@as(u16, 8080), defaultPort(.ambient_ops));
    try std.testing.expectEqual(@as(u16, 3000), defaultPort(.boj));
    try std.testing.expectEqual(@as(u16, 9100), defaultPort(.verisimdb));
}

test "connector state enum tags" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(ConnectorState.disconnected));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(ConnectorState.connected));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(ConnectorState.draining));
}

test "http method enum tags" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(HttpMethod.get));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(HttpMethod.post));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(HttpMethod.patch));
}
