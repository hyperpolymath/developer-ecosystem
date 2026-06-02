// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// zig-groove-bridge — Dodeca-API snap-on/snap-off connector.
//
// Zig replacement for the banned V-lang v-groove-bridge.
// Discovers services via the Groove protocol, presents a unified API surface
// across all 12 API types.  Attach to any Groove-aware service with a single
// call; detach cleanly when done.
//
// Groove protocol reference: hyperpolymath/groove-protocol (GitHub)
//
// Usage:
//   const bridge = @import("zig-groove-bridge");
//
//   // Discover all local Groove services
//   var services = try bridge.discoverAll(allocator);
//   defer services.deinit();
//
//   // Snap on to a named service
//   var att = try bridge.attach(allocator, "verisimdb");
//   defer att.snapOff();
//
//   // Call a REST endpoint through the attachment
//   const body = try att.get(allocator, "/api/v1/health");
//   defer allocator.free(body);

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;

// ═══════════════════════════════════════════════════════════════════════════════
// The Dodeca-API — 12 core API surface types
// ═══════════════════════════════════════════════════════════════════════════════

/// The twelve canonical API surface types that a Groove-aware service may
/// expose.  A service's Groove manifest lists which of these it supports.
pub const ApiType = enum(u8) {
    rest = 0, // HTTP request-response
    grpc = 1, // Protocol Buffers RPC
    graphql = 2, // Query language
    json_rpc = 3, // JSON-based RPC
    websocket = 4, // Bi-directional HTTP upgrade
    mqtt = 5, // Pub-sub messaging
    amqp = 6, // Message broker protocol
    coap = 7, // Constrained Application Protocol
    soap = 8, // XML-based RPC (legacy compat)
    capnproto = 9, // Zero-copy serialization
    sse = 10, // Server-Sent Events (HTTP streaming)
    groove = 11, // Groove native capability negotiation

    /// Human-readable wire name used in Groove manifests.
    pub fn name(self: ApiType) []const u8 {
        return switch (self) {
            .rest => "rest",
            .grpc => "grpc",
            .graphql => "graphql",
            .json_rpc => "json-rpc",
            .websocket => "websocket",
            .mqtt => "mqtt",
            .amqp => "amqp",
            .coap => "coap",
            .soap => "soap",
            .capnproto => "capnproto",
            .sse => "sse",
            .groove => "groove",
        };
    }
};

/// All twelve Dodeca-API types in declaration order.
pub const ALL_API_TYPES: []const ApiType = &.{
    .rest, .grpc, .graphql, .json_rpc, .websocket, .mqtt,
    .amqp, .coap, .soap,  .capnproto, .sse,         .groove,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Known service registry (port → name)
// ═══════════════════════════════════════════════════════════════════════════════

/// A statically known service entry.
const KnownService = struct {
    name: []const u8,
    port: u16,
};

/// Services the bridge probes first, before the open Groove discovery range.
/// Derived from the canonical PORT-REGISTRY in hyperpolymath/groove-protocol.
const KNOWN_SERVICES: []const KnownService = &.{
    .{ .name = "hypatia",    .port = 9090 },
    .{ .name = "stapeln",    .port = 4010 },
    .{ .name = "burble",     .port = 4020 },
    .{ .name = "idaptik",    .port = 4030 },
    .{ .name = "gossamer",   .port = 4040 },
    .{ .name = "ambientops", .port = 4050 },
    .{ .name = "reposystem", .port = 4060 },
    .{ .name = "boj-server", .port = 7700 },
    .{ .name = "verisimdb",  .port = 8080 },
    .{ .name = "echidna",    .port = 8081 },
};

/// First port in the open Groove dynamic discovery range.
const GROOVE_RANGE_START: u16 = 6460;
/// Last port in the open Groove dynamic discovery range (inclusive).
const GROOVE_RANGE_END: u16 = 6500;

// ═══════════════════════════════════════════════════════════════════════════════
// DiscoveredService
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum supported API types per discovered service.
const MAX_API_TYPES: usize = 12;
/// Maximum endpoints advertised in a single Groove manifest.
const MAX_ENDPOINTS: usize = 32;
/// Buffer size for name/version strings.
const NAME_BUF: usize = 128;
/// Buffer size for a single endpoint string.
const ENDPOINT_BUF: usize = 256;

/// A Groove-aware service discovered on the local machine.
pub const DiscoveredService = struct {
    name_buf: [NAME_BUF]u8 = [_]u8{0} ** NAME_BUF,
    name_len: usize = 0,
    version_buf: [NAME_BUF]u8 = [_]u8{0} ** NAME_BUF,
    version_len: usize = 0,
    port: u16 = 0,
    api_types: [MAX_API_TYPES]ApiType = undefined,
    api_type_count: usize = 0,
    endpoint_bufs: [MAX_ENDPOINTS][ENDPOINT_BUF]u8 = [_][ENDPOINT_BUF]u8{[_]u8{0} ** ENDPOINT_BUF} ** MAX_ENDPOINTS,
    endpoint_lens: [MAX_ENDPOINTS]usize = [_]usize{0} ** MAX_ENDPOINTS,
    endpoint_count: usize = 0,
    healthy: bool = false,

    /// Service name as a slice.
    pub fn nameSl(self: *const DiscoveredService) []const u8 {
        return self.name_buf[0..self.name_len];
    }

    /// Version string as a slice.
    pub fn versionSl(self: *const DiscoveredService) []const u8 {
        return self.version_buf[0..self.version_len];
    }

    /// Copy `src` into `name_buf`, truncating at NAME_BUF bytes.
    pub fn setName(self: *DiscoveredService, src: []const u8) void {
        const n = @min(src.len, NAME_BUF);
        @memcpy(self.name_buf[0..n], src[0..n]);
        self.name_len = n;
    }

    /// Copy `src` into `version_buf`, truncating at NAME_BUF bytes.
    pub fn setVersion(self: *DiscoveredService, src: []const u8) void {
        const n = @min(src.len, NAME_BUF);
        @memcpy(self.version_buf[0..n], src[0..n]);
        self.version_len = n;
    }

    /// Push an API type (silently drops if MAX_API_TYPES reached).
    pub fn pushApiType(self: *DiscoveredService, t: ApiType) void {
        if (self.api_type_count < MAX_API_TYPES) {
            self.api_types[self.api_type_count] = t;
            self.api_type_count += 1;
        }
    }

    /// Push an endpoint string (silently drops if MAX_ENDPOINTS reached).
    pub fn pushEndpoint(self: *DiscoveredService, ep: []const u8) void {
        if (self.endpoint_count < MAX_ENDPOINTS) {
            const n = @min(ep.len, ENDPOINT_BUF);
            @memcpy(self.endpoint_bufs[self.endpoint_count][0..n], ep[0..n]);
            self.endpoint_lens[self.endpoint_count] = n;
            self.endpoint_count += 1;
        }
    }

    /// Slice of API types for this service.
    pub fn apiTypesSl(self: *const DiscoveredService) []const ApiType {
        return self.api_types[0..self.api_type_count];
    }

    /// Whether this service advertises a given ApiType.
    pub fn hasApiType(self: *const DiscoveredService, t: ApiType) bool {
        for (self.apiTypesSl()) |at| {
            if (at == t) return true;
        }
        return false;
    }
};

/// Heap-owned list of DiscoveredService values.
pub const ServiceList = struct {
    items: []DiscoveredService,
    allocator: Allocator,

    pub fn deinit(self: *ServiceList) void {
        self.allocator.free(self.items);
    }

    /// Number of discovered services.
    pub fn len(self: *const ServiceList) usize {
        return self.items.len;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP helpers (synchronous, no async)
// ═══════════════════════════════════════════════════════════════════════════════

/// Perform a GET request against `url`.  Returns the response body as an
/// owned slice on success, or error on HTTP failure / network error.
fn httpGet(allocator: Allocator, url: []const u8) ![]const u8 {
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var alloc_writer = std.Io.Writer.Allocating.init(allocator);
    errdefer alloc_writer.deinit();

    const result = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = &.{
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "User-Agent", .value = "zig-groove-bridge/0.1.0" },
        },
        .response_writer = &alloc_writer.writer,
    });

    if (result.status != .ok) {
        alloc_writer.deinit();
        return error.HttpError;
    }

    var list = alloc_writer.toArrayList();
    return list.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Groove manifest parsing
// ═══════════════════════════════════════════════════════════════════════════════

/// Parse a minimal Groove manifest JSON body.
///
/// Expected shape (subset we care about):
///   {"service":"verisimdb","version":"1.2.3","api_types":["rest","groove"]}
///
/// No dependency on a JSON library — uses simple substring search so the
/// library stays zero-dependency.
fn parseGrooveManifest(body: []const u8, out: *DiscoveredService) void {
    // Extract "service":"<value>"
    if (extractJsonString(body, "service")) |svc| {
        out.setName(svc);
    }
    // Extract "version":"<value>"
    if (extractJsonString(body, "version")) |ver| {
        out.setVersion(ver);
    }

    // Scan for known api_type strings within the body.
    // Check each wire-format name as a quoted literal — avoids runtime
    // format calls inside a comptime loop.
    if (std.mem.indexOf(u8, body, "\"rest\"")      != null) out.pushApiType(.rest);
    if (std.mem.indexOf(u8, body, "\"grpc\"")      != null) out.pushApiType(.grpc);
    if (std.mem.indexOf(u8, body, "\"graphql\"")   != null) out.pushApiType(.graphql);
    if (std.mem.indexOf(u8, body, "\"json-rpc\"")  != null) out.pushApiType(.json_rpc);
    if (std.mem.indexOf(u8, body, "\"websocket\"") != null) out.pushApiType(.websocket);
    if (std.mem.indexOf(u8, body, "\"mqtt\"")      != null) out.pushApiType(.mqtt);
    if (std.mem.indexOf(u8, body, "\"amqp\"")      != null) out.pushApiType(.amqp);
    if (std.mem.indexOf(u8, body, "\"coap\"")      != null) out.pushApiType(.coap);
    if (std.mem.indexOf(u8, body, "\"soap\"")      != null) out.pushApiType(.soap);
    if (std.mem.indexOf(u8, body, "\"capnproto\"") != null) out.pushApiType(.capnproto);
    if (std.mem.indexOf(u8, body, "\"sse\"")       != null) out.pushApiType(.sse);
    if (std.mem.indexOf(u8, body, "\"groove\"")    != null) out.pushApiType(.groove);

    // Always add 'groove' if we reached here via the manifest endpoint
    if (!out.hasApiType(.groove)) out.pushApiType(.groove);
    if (!out.hasApiType(.rest)) out.pushApiType(.rest);

    out.healthy = true;
}

/// Pull the string value of a JSON key using substring search.
/// Returns a slice pointing into `body`, or null if not found.
/// Only handles the simple case: `"key":"value"` (no escaping).
fn extractJsonString(body: []const u8, key: []const u8) ?[]const u8 {
    // Build needle: `"<key>":"`
    var needle_buf: [64]u8 = undefined;
    const needle = std.fmt.bufPrint(&needle_buf, "\"{s}\":\"", .{key}) catch return null;
    const start_pos = std.mem.indexOf(u8, body, needle) orelse return null;
    const val_start = start_pos + needle.len;
    // Find closing quote
    const val_end = std.mem.indexOfPos(u8, body, val_start, "\"") orelse return null;
    return body[val_start..val_end];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Service discovery
// ═══════════════════════════════════════════════════════════════════════════════

/// Probe a single port for a Groove-aware service.
///
/// Tries `/.well-known/groove` first; falls back to `/health`.
/// Returns null if the port has nothing Groove-aware listening.
pub fn probePort(allocator: Allocator, hint_name: []const u8, port: u16) ?DiscoveredService {
    var svc = DiscoveredService{};
    svc.setName(hint_name);
    svc.port = port;

    // ── Try Groove manifest ───────────────────────────────────────────────────
    var url_buf: [256]u8 = undefined;
    const groove_url = std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/.well-known/groove", .{port}) catch return null;
    if (httpGet(allocator, groove_url)) |body| {
        defer allocator.free(body);
        parseGrooveManifest(body, &svc);
        // Overwrite hint name only when the manifest provided a real name
        if (svc.name_len == 0) svc.setName(hint_name);
        return svc;
    } else |_| {}

    // ── Fallback: /health ─────────────────────────────────────────────────────
    const health_url = std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/health", .{port}) catch return null;
    if (httpGet(allocator, health_url)) |body| {
        allocator.free(body); // only care about reachability
        svc.setVersion("0.0.0");
        svc.pushApiType(.rest);
        svc.pushEndpoint("/health");
        svc.healthy = true;
        return svc;
    } else |_| {}

    return null;
}

/// Discover all Groove-aware services on the local machine.
///
/// Scans the known-service table first, then the dynamic Groove discovery
/// range (ports 6460-6500).  Returns a heap-allocated ServiceList; call
/// `list.deinit()` when done.
pub fn discoverAll(allocator: Allocator) !ServiceList {
    var found: std.ArrayList(DiscoveredService) = .empty;
    try found.ensureTotalCapacityPrecise(allocator, 10);
    errdefer found.deinit(allocator);

    // ── Known services ────────────────────────────────────────────────────────
    for (KNOWN_SERVICES) |ks| {
        if (probePort(allocator, ks.name, ks.port)) |svc| {
            try found.append(allocator, svc);
        }
    }

    // ── Groove dynamic range ──────────────────────────────────────────────────
    var p: u16 = GROOVE_RANGE_START;
    while (p <= GROOVE_RANGE_END) : (p += 1) {
        if (probePort(allocator, "unknown", p)) |svc| {
            try found.append(allocator, svc);
        }
    }

    return ServiceList{
        .items = try found.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Snap-on / Snap-off attachment
// ═══════════════════════════════════════════════════════════════════════════════

/// A live attachment to a discovered service.
///
/// Obtain one via `snapOn` or the `attach` / `attachVerisimdb` helpers.
/// Call `snapOff` (or let the struct drop) when done — it marks the
/// attachment inactive but does not send any network message.
pub const Attachment = struct {
    service: DiscoveredService,
    active: bool = true,
    base_url_buf: [256]u8 = [_]u8{0} ** 256,
    base_url_len: usize = 0,

    /// Base URL slice, e.g. `"http://127.0.0.1:8080"`.
    pub fn baseUrl(self: *const Attachment) []const u8 {
        return self.base_url_buf[0..self.base_url_len];
    }

    /// Mark attachment as inactive.  Safe to call multiple times.
    pub fn snapOff(self: *Attachment) void {
        self.active = false;
    }

    /// Return true if the attachment is still marked active AND the remote
    /// `/health` endpoint responds 200.
    pub fn isLive(self: *const Attachment, allocator: Allocator) bool {
        if (!self.active) return false;
        var url_buf: [256]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "{s}/health", .{self.baseUrl()}) catch return false;
        const body = httpGet(allocator, url) catch return false;
        allocator.free(body);
        return true;
    }

    /// Perform a GET request against `path` through the attachment.
    ///
    /// Returns the response body as an owned slice; caller must free.
    pub fn get(self: *const Attachment, allocator: Allocator, path: []const u8) ![]const u8 {
        if (!self.active) return error.NotAttached;
        var url_buf: [512]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ self.baseUrl(), path });
        return httpGet(allocator, url);
    }

    /// Perform a POST request against `path` with `body` through the attachment.
    ///
    /// Returns the response body as an owned slice; caller must free.
    pub fn post(self: *const Attachment, allocator: Allocator, path: []const u8, body: []const u8) ![]const u8 {
        if (!self.active) return error.NotAttached;

        var url_buf: [512]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "{s}{s}", .{ self.baseUrl(), path });

        var client = http.Client{ .allocator = allocator };
        defer client.deinit();

        var alloc_writer = std.Io.Writer.Allocating.init(allocator);
        errdefer alloc_writer.deinit();

        const result = try client.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = body,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Accept",       .value = "application/json" },
                .{ .name = "User-Agent",   .value = "zig-groove-bridge/0.1.0" },
            },
            .response_writer = &alloc_writer.writer,
        });

        if (result.status != .ok and result.status != .created and result.status != .no_content) {
            alloc_writer.deinit();
            return error.HttpError;
        }

        var list = alloc_writer.toArrayList();
        return list.toOwnedSlice(allocator);
    }
};

/// Create an Attachment from a DiscoveredService.
pub fn snapOn(svc: DiscoveredService) Attachment {
    var att = Attachment{ .service = svc };
    const url = std.fmt.bufPrint(&att.base_url_buf, "http://127.0.0.1:{d}", .{svc.port}) catch {
        att.active = false;
        return att;
    };
    att.base_url_len = url.len;
    return att;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Convenience helpers
// ═══════════════════════════════════════════════════════════════════════════════

/// Discover all local services, find `service_name`, and snap on.
/// Returns an error if no service with that name is found.
pub fn attach(allocator: Allocator, service_name: []const u8) !Attachment {
    var list = try discoverAll(allocator);
    defer list.deinit();
    for (list.items) |svc| {
        if (std.mem.eql(u8, svc.nameSl(), service_name)) {
            return snapOn(svc);
        }
    }
    return error.ServiceNotFound;
}

/// Attach to a VeriSimDB instance on one of its known ports (8080, 8093-8095).
/// Returns an error if no instance is reachable.
pub fn attachVerisimdb(allocator: Allocator) !Attachment {
    const ports: []const u16 = &.{ 8080, 8093, 8094, 8095 };
    for (ports) |p| {
        if (probePort(allocator, "verisimdb", p)) |svc| {
            return snapOn(svc);
        }
    }
    return error.ServiceNotFound;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Unit tests
// ═══════════════════════════════════════════════════════════════════════════════

test "ApiType.name returns correct wire strings" {
    try std.testing.expectEqualStrings("rest",       ApiType.rest.name());
    try std.testing.expectEqualStrings("grpc",       ApiType.grpc.name());
    try std.testing.expectEqualStrings("graphql",    ApiType.graphql.name());
    try std.testing.expectEqualStrings("json-rpc",   ApiType.json_rpc.name());
    try std.testing.expectEqualStrings("websocket",  ApiType.websocket.name());
    try std.testing.expectEqualStrings("mqtt",       ApiType.mqtt.name());
    try std.testing.expectEqualStrings("amqp",       ApiType.amqp.name());
    try std.testing.expectEqualStrings("coap",       ApiType.coap.name());
    try std.testing.expectEqualStrings("soap",       ApiType.soap.name());
    try std.testing.expectEqualStrings("capnproto",  ApiType.capnproto.name());
    try std.testing.expectEqualStrings("sse",        ApiType.sse.name());
    try std.testing.expectEqualStrings("groove",     ApiType.groove.name());
}

test "ALL_API_TYPES contains all twelve variants" {
    try std.testing.expectEqual(@as(usize, 12), ALL_API_TYPES.len);
}

test "DiscoveredService.setName truncates at NAME_BUF" {
    var svc = DiscoveredService{};
    // Exactly NAME_BUF characters should store without overflow
    const long_name = "A" ** (NAME_BUF + 10);
    svc.setName(long_name);
    try std.testing.expectEqual(NAME_BUF, svc.name_len);
}

test "DiscoveredService.pushApiType respects MAX_API_TYPES" {
    var svc = DiscoveredService{};
    var i: usize = 0;
    while (i < MAX_API_TYPES + 5) : (i += 1) {
        svc.pushApiType(.rest); // push same type repeatedly
    }
    try std.testing.expectEqual(MAX_API_TYPES, svc.api_type_count);
}

test "DiscoveredService.hasApiType" {
    var svc = DiscoveredService{};
    svc.pushApiType(.groove);
    svc.pushApiType(.rest);
    try std.testing.expect(svc.hasApiType(.groove));
    try std.testing.expect(svc.hasApiType(.rest));
    try std.testing.expect(!svc.hasApiType(.grpc));
}

test "DiscoveredService.pushEndpoint respects MAX_ENDPOINTS and truncation" {
    var svc = DiscoveredService{};
    var i: usize = 0;
    while (i < MAX_ENDPOINTS + 2) : (i += 1) {
        svc.pushEndpoint("/health");
    }
    try std.testing.expectEqual(MAX_ENDPOINTS, svc.endpoint_count);

    // Oversized endpoint is truncated to ENDPOINT_BUF
    var svc2 = DiscoveredService{};
    const long_ep = "/" ++ ("x" ** (ENDPOINT_BUF + 10));
    svc2.pushEndpoint(long_ep);
    try std.testing.expectEqual(ENDPOINT_BUF, svc2.endpoint_lens[0]);
}

test "extractJsonString handles simple key-value" {
    const body =
        \\{"service":"verisimdb","version":"1.2.3","api_types":["rest","groove"]}
    ;
    const svc = extractJsonString(body, "service");
    const ver = extractJsonString(body, "version");
    const missing = extractJsonString(body, "nonexistent");

    try std.testing.expect(svc != null);
    try std.testing.expectEqualStrings("verisimdb", svc.?);
    try std.testing.expect(ver != null);
    try std.testing.expectEqualStrings("1.2.3", ver.?);
    try std.testing.expect(missing == null);
}

test "parseGrooveManifest populates service and api_types" {
    const body =
        \\{"service":"burble","version":"0.9.1","api_types":["rest","groove","websocket"]}
    ;
    var svc = DiscoveredService{};
    parseGrooveManifest(body, &svc);
    try std.testing.expectEqualStrings("burble", svc.nameSl());
    try std.testing.expectEqualStrings("0.9.1", svc.versionSl());
    try std.testing.expect(svc.hasApiType(.rest));
    try std.testing.expect(svc.hasApiType(.groove));
    try std.testing.expect(svc.hasApiType(.websocket));
    try std.testing.expect(!svc.hasApiType(.grpc));
    try std.testing.expect(svc.healthy);
}

test "snapOn builds correct base_url" {
    var svc = DiscoveredService{};
    svc.setName("verisimdb");
    svc.port = 8080;

    const att = snapOn(svc);
    try std.testing.expect(att.active);
    try std.testing.expectEqualStrings("http://127.0.0.1:8080", att.baseUrl());
}

test "snapOn + snapOff deactivates attachment" {
    var svc = DiscoveredService{};
    svc.setName("test-svc");
    svc.port = 9999;

    var att = snapOn(svc);
    try std.testing.expect(att.active);
    att.snapOff();
    try std.testing.expect(!att.active);
}

test "Attachment.get returns NotAttached when inactive" {
    var svc = DiscoveredService{};
    svc.port = 9999;
    var att = snapOn(svc);
    att.snapOff();

    const result = att.get(std.testing.allocator, "/health");
    try std.testing.expectError(error.NotAttached, result);
}

test "KNOWN_SERVICES table has correct entries" {
    // Verify a sampling of entries are correct
    var found_verisimdb = false;
    var found_hypatia = false;
    for (KNOWN_SERVICES) |ks| {
        if (std.mem.eql(u8, ks.name, "verisimdb") and ks.port == 8080) found_verisimdb = true;
        if (std.mem.eql(u8, ks.name, "hypatia") and ks.port == 9090) found_hypatia = true;
    }
    try std.testing.expect(found_verisimdb);
    try std.testing.expect(found_hypatia);
}
