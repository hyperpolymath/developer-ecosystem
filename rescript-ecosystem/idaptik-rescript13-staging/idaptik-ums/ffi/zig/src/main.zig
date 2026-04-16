// SPDX-License-Identifier: PMPL-1.0-or-later
// main.zig -- C-compatible FFI exports for the IDApTIK UMS level editor.
// Author: Jonathan D.A. Jewell
//
// This module is the sole entry point for foreign callers (ReScript / Deno /
// Gossamer / Dioxus).  Every exported function uses `callconv(.c)` and operates
// on the C-ABI types defined in types.zig.
//
// Lifecycle:
//   1. `idaptik_ums_create_level`   -- allocate + zero-initialise a LevelData
//   2. `idaptik_ums_add_*`          -- populate the level incrementally
//   3. `idaptik_ums_set_*`          -- set singular config fields
//   4. `idaptik_ums_validate_level` -- run all proof checks at runtime
//   5. `idaptik_ums_serialize_level` / `idaptik_ums_deserialize_level`
//   6. `idaptik_ums_destroy_level`  -- free the LevelData
//
// Memory ownership: the library owns all LevelData allocations.  Callers
// MUST NOT free the pointer themselves; always use `destroy_level`.

const std = @import("std");
const types = @import("types");
const validate = @import("validate");

/// Global general-purpose allocator used for all heap allocations.
/// Using the page allocator keeps us free of libc dependency.
var gpa = std.heap.page_allocator;

// =========================================================================
// Lifecycle: create / destroy
// =========================================================================

/// Allocate and zero-initialise a new LevelData on the heap.
///
/// Returns a pointer to the new level, or null if allocation fails.
/// The caller is responsible for eventually calling `idaptik_ums_destroy_level`.
pub export fn idaptik_ums_create_level() callconv(.c) ?*types.LevelData {
    const level = gpa.create(types.LevelData) catch return null;
    level.* = std.mem.zeroes(types.LevelData);
    return level;
}

/// Free a LevelData previously created by `idaptik_ums_create_level`.
///
/// After this call the pointer is dangling and MUST NOT be used again.
/// Passing null is a safe no-op.
pub export fn idaptik_ums_destroy_level(level: ?*types.LevelData) callconv(.c) void {
    if (level) |lv| {
        gpa.destroy(lv);
    }
}

// =========================================================================
// Add functions: append to dynamic arrays
// =========================================================================

/// Append a device to the level's device list.
///
/// Returns `true` on success, `false` if the device array is at capacity.
pub export fn idaptik_ums_add_device(
    level: ?*types.LevelData,
    spec: ?*const types.DeviceSpec,
) callconv(.c) bool {
    const lv = level orelse return false;
    const s = spec orelse return false;
    if (lv.devices_len >= types.MAX_DEVICES) return false;
    lv.devices[lv.devices_len] = s.*;
    lv.devices_len += 1;
    return true;
}

/// Append a zone to the level's zone list.
///
/// Returns `true` on success, `false` if the zone array is at capacity.
pub export fn idaptik_ums_add_zone(
    level: ?*types.LevelData,
    zone: ?*const types.Zone,
) callconv(.c) bool {
    const lv = level orelse return false;
    const z = zone orelse return false;
    if (lv.zones_len >= types.MAX_ZONES) return false;
    lv.zones[lv.zones_len] = z.*;
    lv.zones_len += 1;
    return true;
}

/// Append a guard to the level's guard list.
///
/// Returns `true` on success, `false` if the guard array is at capacity.
pub export fn idaptik_ums_add_guard(
    level: ?*types.LevelData,
    guard: ?*const types.GuardPlacement,
) callconv(.c) bool {
    const lv = level orelse return false;
    const g = guard orelse return false;
    if (lv.guards_len >= types.MAX_GUARDS) return false;
    lv.guards[lv.guards_len] = g.*;
    lv.guards_len += 1;
    return true;
}

/// Append a dog to the level's dog list.
///
/// Returns `true` on success, `false` if the dog array is at capacity.
pub export fn idaptik_ums_add_dog(
    level: ?*types.LevelData,
    dog: ?*const types.DogPlacement,
) callconv(.c) bool {
    const lv = level orelse return false;
    const d = dog orelse return false;
    if (lv.dogs_len >= types.MAX_DOGS) return false;
    lv.dogs[lv.dogs_len] = d.*;
    lv.dogs_len += 1;
    return true;
}

/// Append a drone to the level's drone list.
///
/// Returns `true` on success, `false` if the drone array is at capacity.
pub export fn idaptik_ums_add_drone(
    level: ?*types.LevelData,
    drone: ?*const types.DronePlacement,
) callconv(.c) bool {
    const lv = level orelse return false;
    const dr = drone orelse return false;
    if (lv.drones_len >= types.MAX_DRONES) return false;
    lv.drones[lv.drones_len] = dr.*;
    lv.drones_len += 1;
    return true;
}

// =========================================================================
// Set functions: singular config fields
// =========================================================================

/// Set the mission configuration for the level.
///
/// Returns `true` on success, `false` if either pointer is null.
pub export fn idaptik_ums_set_mission(
    level: ?*types.LevelData,
    mission: ?*const types.MissionConfig,
) callconv(.c) bool {
    const lv = level orelse return false;
    const m = mission orelse return false;
    lv.mission = m.*;
    return true;
}

/// Set the physical world configuration for the level.
///
/// Returns `true` on success, `false` if either pointer is null.
pub export fn idaptik_ums_set_physical(
    level: ?*types.LevelData,
    physical: ?*const types.PhysicalConfig,
) callconv(.c) bool {
    const lv = level orelse return false;
    const p = physical orelse return false;
    lv.physical = p.*;
    return true;
}

// =========================================================================
// Validation
// =========================================================================

/// Run all four cross-domain validation checks on the level.
///
/// This is the runtime materialisation of the erased proof fields in
/// `Validation.ValidatedLevel`.  The checks are:
///   1. Defence targets reference real devices.
///   2. Every guard's zone exists in the zone list.
///   3. Zone transitions are monotonically ordered by X.
///   4. If PBX is enabled, its IP is in the device registry.
///
/// Returns a `ValidationResult` with per-check booleans and an overall flag.
pub export fn idaptik_ums_validate_level(
    level: ?*const types.LevelData,
) callconv(.c) types.ValidationResult {
    const lv = level orelse return .{
        .valid = false,
        .defence_targets_valid = false,
        .guards_in_zones = false,
        .zones_ordered = false,
        .pbx_consistent = false,
    };
    return validate.validateLevel(lv);
}

// =========================================================================
// Serialisation (JSON)
// =========================================================================

/// Serialise a LevelData to JSON, writing into a caller-provided buffer.
///
/// Parameters:
///   - `level`: pointer to the LevelData to serialise.
///   - `buf`:   pointer to the output buffer.
///   - `buf_len`: size of the output buffer in bytes.
///
/// Returns the number of bytes written on success.
/// Returns 0 if the buffer is too small or any pointer is null.
///
/// The output is valid UTF-8 JSON without a trailing null terminator.
pub export fn idaptik_ums_serialize_level(
    level: ?*const types.LevelData,
    buf: ?[*]u8,
    buf_len: usize,
) callconv(.c) usize {
    const lv = level orelse return 0;
    const buffer = buf orelse return 0;

    var fbs = std.io.fixedBufferStream(buffer[0..buf_len]);
    const writer = fbs.writer();

    serializeLevelJson(lv, writer) catch return 0;

    return fbs.pos;
}

/// Deserialise a LevelData from a JSON buffer.
///
/// Parameters:
///   - `data`: pointer to the JSON input (need not be null-terminated).
///   - `data_len`: length of the JSON input in bytes.
///
/// Returns a heap-allocated LevelData on success, or null on failure.
/// The caller is responsible for freeing via `idaptik_ums_destroy_level`.
pub export fn idaptik_ums_deserialize_level(
    data: ?[*]const u8,
    data_len: usize,
) callconv(.c) ?*types.LevelData {
    const input = data orelse return null;
    if (data_len == 0) return null;

    const level = gpa.create(types.LevelData) catch return null;
    level.* = std.mem.zeroes(types.LevelData);

    deserializeLevelJson(input[0..data_len], level) catch {
        gpa.destroy(level);
        return null;
    };

    return level;
}

// =========================================================================
// Internal: JSON serialisation helpers
// =========================================================================

/// Write a complete LevelData as JSON to the given writer.
fn serializeLevelJson(level: *const types.LevelData, writer: anytype) !void {
    try writer.writeAll("{");

    // -- devices --
    try writer.writeAll("\"devices\":[");
    for (level.devices[0..level.devices_len], 0..) |dev, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeDeviceSpec(&dev, writer);
    }
    try writer.writeAll("],");

    // -- zones --
    try writer.writeAll("\"zones\":[");
    for (level.zones[0..level.zones_len], 0..) |z, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeZone(&z, writer);
    }
    try writer.writeAll("],");

    // -- guards --
    try writer.writeAll("\"guards\":[");
    for (level.guards[0..level.guards_len], 0..) |g, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeGuard(&g, writer);
    }
    try writer.writeAll("],");

    // -- dogs --
    try writer.writeAll("\"dogs\":[");
    for (level.dogs[0..level.dogs_len], 0..) |d, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeDog(&d, writer);
    }
    try writer.writeAll("],");

    // -- drones --
    try writer.writeAll("\"drones\":[");
    for (level.drones[0..level.drones_len], 0..) |d, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeDrone(&d, writer);
    }
    try writer.writeAll("],");

    // -- assassins --
    try writer.writeAll("\"assassins\":[");
    for (level.assassins[0..level.assassins_len], 0..) |a, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeAssassin(&a, writer);
    }
    try writer.writeAll("],");

    // -- wiring --
    try writer.writeAll("\"wiring\":[");
    for (level.wiring[0..level.wiring_len], 0..) |w, i| {
        if (i > 0) try writer.writeAll(",");
        try serializeWiring(&w, writer);
    }
    try writer.writeAll("],");

    // -- physical --
    try writer.writeAll("\"physical\":");
    try serializePhysical(&level.physical, writer);
    try writer.writeAll(",");

    // -- PBX --
    try writer.print("\"has_pbx\":{},", .{level.has_pbx});
    try writer.writeAll("\"pbx_ip\":");
    try serializeIp(&level.pbx_ip, writer);
    try writer.print(",\"pbx_world_x\":{d}", .{level.pbx_world_x.position});

    try writer.writeAll("}");
}

/// Write an IpAddress as a JSON string "a.b.c.d".
fn serializeIp(ip: *const types.IpAddress, writer: anytype) !void {
    try writer.print("\"{d}.{d}.{d}.{d}\"", .{ ip.octet1, ip.octet2, ip.octet3, ip.octet4 });
}

/// Write a null-terminated C string as a JSON string, or "null" if null.
fn serializeCStr(s: ?[*:0]const u8, writer: anytype) !void {
    if (s) |ptr| {
        const span = std.mem.span(ptr);
        try writer.writeByte('"');
        for (span) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => try writer.writeByte(c),
            }
        }
        try writer.writeByte('"');
    } else {
        try writer.writeAll("null");
    }
}

fn serializeDeviceSpec(dev: *const types.DeviceSpec, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"kind\":{d},", .{@intFromEnum(dev.kind)});
    try writer.writeAll("\"ip\":");
    try serializeIp(&dev.ip, writer);
    try writer.writeAll(",\"name\":");
    try serializeCStr(dev.name, writer);
    try writer.print(",\"security\":{d}", .{@intFromEnum(dev.security)});
    try writer.writeAll("}");
}

fn serializeZone(z: *const types.Zone, writer: anytype) !void {
    try writer.writeAll("{\"name\":");
    try serializeCStr(z.name, writer);
    try writer.print(",\"security_tier\":{d}", .{z.security_tier});
    try writer.writeAll("}");
}

fn serializeGuard(g: *const types.GuardPlacement, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"world_x\":{d},", .{g.world_x.position});
    try writer.writeAll("\"zone\":");
    try serializeCStr(g.zone, writer);
    try writer.print(",\"rank\":{d},\"patrol_radius\":{d}", .{ @intFromEnum(g.rank), g.patrol_radius });
    try writer.writeAll("}");
}

fn serializeDog(d: *const types.DogPlacement, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"world_x\":{d},\"breed\":{d},\"patrol_radius\":{d}", .{
        d.world_x.position,
        @intFromEnum(d.breed),
        d.patrol_radius,
    });
    try writer.writeAll("}");
}

fn serializeDrone(d: *const types.DronePlacement, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"world_x\":{d},\"archetype\":{d},\"altitude\":{d}", .{
        d.world_x.position,
        @intFromEnum(d.archetype),
        d.altitude,
    });
    try writer.writeAll("}");
}

fn serializeAssassin(a: *const types.AssassinConfig, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"spawn_x\":{d},\"ambush_count\":{d},\"retreat_threshold\":{d}", .{
        a.spawn_x.position,
        a.ambush_count,
        a.retreat_threshold,
    });
    try writer.writeAll("}");
}

fn serializeWiring(w: *const types.WiringChallenge, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"kind\":{d},", .{@intFromEnum(w.kind)});
    try writer.writeAll("\"device_ip\":");
    try serializeIp(&w.device_ip, writer);
    try writer.print(",\"difficulty\":{d}", .{w.difficulty});
    try writer.writeAll("}");
}

fn serializePhysical(p: *const types.PhysicalConfig, writer: anytype) !void {
    try writer.writeAll("{");
    try writer.print("\"ground_y\":{d},\"world_width\":{d},\"interaction_distance\":{d},\"has_power_system\":{},\"has_security_cameras\":{},\"number_of_covert_links\":{d}", .{
        p.ground_y,
        p.world_width,
        p.interaction_distance,
        p.has_power_system,
        p.has_security_cameras,
        p.number_of_covert_links,
    });
    try writer.writeAll("}");
}

// =========================================================================
// Internal: JSON deserialisation (minimal — enough for round-trip)
// =========================================================================

/// Parse a JSON buffer and populate a LevelData struct.
/// This is a minimal parser sufficient for round-tripping data produced
/// by `serializeLevelJson`.  It does NOT handle arbitrary JSON.
fn deserializeLevelJson(input: []const u8, level: *types.LevelData) !void {
    // Use the standard library JSON parser for robust handling.
    const parsed = std.json.parseFromSlice(
        JsonLevelData,
        gpa,
        input,
        .{ .allocate = .alloc_always },
    ) catch return error.JsonParseError;
    defer parsed.deinit();

    const jld = parsed.value;

    // Populate physical config.
    level.physical = .{
        .ground_y = jld.physical.ground_y,
        .world_width = jld.physical.world_width,
        .interaction_distance = jld.physical.interaction_distance,
        .has_power_system = jld.physical.has_power_system,
        .has_security_cameras = jld.physical.has_security_cameras,
        .number_of_covert_links = @intCast(jld.physical.number_of_covert_links),
    };

    level.has_pbx = jld.has_pbx;
    if (jld.pbx_world_x) |wx| {
        level.pbx_world_x = .{ .position = wx };
    }

    // Parse pbx_ip from "a.b.c.d" string.
    if (jld.pbx_ip) |ip_str| {
        level.pbx_ip = parseIpString(ip_str) catch types.IpAddress.init(0, 0, 0, 0);
    }

    // Populate devices.
    if (jld.devices) |devs| {
        for (devs) |jdev| {
            if (level.devices_len >= types.MAX_DEVICES) break;
            level.devices[level.devices_len] = .{
                .kind = @enumFromInt(jdev.kind),
                .ip = parseIpString(jdev.ip orelse "0.0.0.0") catch types.IpAddress.init(0, 0, 0, 0),
                .name = null, // String ownership: callers must set names after deserialisation.
                .security = @enumFromInt(jdev.security),
            };
            level.devices_len += 1;
        }
    }

    // Populate zones.
    if (jld.zones) |zones| {
        for (zones) |jz| {
            if (level.zones_len >= types.MAX_ZONES) break;
            level.zones[level.zones_len] = .{
                .name = null, // String ownership: callers must set names.
                .security_tier = @intCast(jz.security_tier),
            };
            level.zones_len += 1;
        }
    }
}

/// Parse an IP address string "a.b.c.d" into an IpAddress.
fn parseIpString(s: []const u8) !types.IpAddress {
    var octets: [4]u8 = .{ 0, 0, 0, 0 };
    var octet_idx: usize = 0;
    var current: u16 = 0;

    for (s) |c| {
        if (c == '.') {
            if (octet_idx >= 3) return error.InvalidIp;
            if (current > 255) return error.InvalidIp;
            octets[octet_idx] = @intCast(current);
            octet_idx += 1;
            current = 0;
        } else if (c >= '0' and c <= '9') {
            current = current * 10 + (c - '0');
        } else {
            return error.InvalidIp;
        }
    }
    if (octet_idx != 3) return error.InvalidIp;
    if (current > 255) return error.InvalidIp;
    octets[3] = @intCast(current);

    return types.IpAddress.init(octets[0], octets[1], octets[2], octets[3]);
}

// =========================================================================
// JSON intermediate types for std.json parsing
// =========================================================================

const JsonLevelData = struct {
    devices: ?[]const JsonDevice = null,
    zones: ?[]const JsonZone = null,
    has_pbx: bool = false,
    pbx_ip: ?[]const u8 = null,
    pbx_world_x: ?f64 = null,
    physical: JsonPhysical = .{},
};

const JsonDevice = struct {
    kind: u8 = 0,
    ip: ?[]const u8 = null,
    name: ?[]const u8 = null,
    security: u8 = 0,
};

const JsonZone = struct {
    name: ?[]const u8 = null,
    security_tier: u32 = 0,
};

const JsonPhysical = struct {
    ground_y: f64 = 0,
    world_width: f64 = 0,
    interaction_distance: f64 = 0,
    has_power_system: bool = false,
    has_security_cameras: bool = false,
    number_of_covert_links: u32 = 0,
};
