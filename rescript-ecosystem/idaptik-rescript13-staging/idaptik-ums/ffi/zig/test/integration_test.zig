// SPDX-License-Identifier: PMPL-1.0-or-later
// integration_test.zig -- Integration tests for the IDApTIK UMS Zig FFI.
// Author: Jonathan D.A. Jewell
//
// Tests the full create -> populate -> validate -> serialise lifecycle
// exercising every exported FFI function.

const std = @import("std");
const types = @import("types");
const validate = @import("validate");
const main = @import("main");

// =========================================================================
// Helpers
// =========================================================================

/// Create a level via the FFI, returning a non-null pointer or failing the test.
fn createTestLevel() *types.LevelData {
    return main.idaptik_ums_create_level() orelse {
        @panic("idaptik_ums_create_level returned null");
    };
}

// =========================================================================
// Test: create and destroy lifecycle
// =========================================================================

test "create_level returns non-null and destroy is safe" {
    const level = createTestLevel();
    // A freshly created level should have all counts at zero.
    try std.testing.expectEqual(@as(u32, 0), level.devices_len);
    try std.testing.expectEqual(@as(u32, 0), level.zones_len);
    try std.testing.expectEqual(@as(u32, 0), level.guards_len);
    try std.testing.expectEqual(@as(u32, 0), level.dogs_len);
    try std.testing.expectEqual(@as(u32, 0), level.drones_len);
    try std.testing.expectEqual(@as(u32, 0), level.assassins_len);
    try std.testing.expectEqual(@as(u32, 0), level.items_len);
    try std.testing.expectEqual(@as(u32, 0), level.wiring_len);
    try std.testing.expectEqual(false, level.has_pbx);
    main.idaptik_ums_destroy_level(level);
}

test "destroy_level with null is a no-op" {
    main.idaptik_ums_destroy_level(null);
}

// =========================================================================
// Test: add_device
// =========================================================================

test "add_device populates the device array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const spec = types.DeviceSpec{
        .kind = .server,
        .ip = types.IpAddress.init(10, 0, 0, 1),
        .name = "core-server",
        .security = .strong,
    };

    const ok = main.idaptik_ums_add_device(level, &spec);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u32, 1), level.devices_len);
    try std.testing.expect(level.devices[0].ip.eql(types.IpAddress.init(10, 0, 0, 1)));
    try std.testing.expectEqual(types.DeviceKind.server, level.devices[0].kind);
}

test "add_device with null level returns false" {
    const spec = types.DeviceSpec{
        .kind = .laptop,
        .ip = types.IpAddress.init(10, 0, 0, 2),
        .name = "test",
        .security = .open,
    };
    try std.testing.expect(!main.idaptik_ums_add_device(null, &spec));
}

// =========================================================================
// Test: add_zone
// =========================================================================

test "add_zone populates the zone array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const zone = types.Zone{
        .name = "lobby",
        .security_tier = 1,
    };
    try std.testing.expect(main.idaptik_ums_add_zone(level, &zone));
    try std.testing.expectEqual(@as(u32, 1), level.zones_len);
}

// =========================================================================
// Test: add_guard
// =========================================================================

test "add_guard populates the guard array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const guard = types.GuardPlacement{
        .world_x = .{ .position = 100.0 },
        .zone = "lobby",
        .rank = .enforcer,
        .patrol_radius = 25.0,
    };
    try std.testing.expect(main.idaptik_ums_add_guard(level, &guard));
    try std.testing.expectEqual(@as(u32, 1), level.guards_len);
    try std.testing.expectEqual(types.GuardRank.enforcer, level.guards[0].rank);
}

// =========================================================================
// Test: add_dog
// =========================================================================

test "add_dog populates the dog array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const dog = types.DogPlacement{
        .world_x = .{ .position = 200.0 },
        .breed = .bloodhound,
        .patrol_radius = 50.0,
    };
    try std.testing.expect(main.idaptik_ums_add_dog(level, &dog));
    try std.testing.expectEqual(@as(u32, 1), level.dogs_len);
}

// =========================================================================
// Test: add_drone
// =========================================================================

test "add_drone populates the drone array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const drone = types.DronePlacement{
        .world_x = .{ .position = 300.0 },
        .archetype = .hunter,
        .altitude = 15.0,
    };
    try std.testing.expect(main.idaptik_ums_add_drone(level, &drone));
    try std.testing.expectEqual(@as(u32, 1), level.drones_len);
}

// =========================================================================
// Test: set_mission
// =========================================================================

test "set_mission configures the mission" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const mission = types.MissionConfig{
        .mission_id = "m-001",
        .location_id = "data-centre-alpha",
        .objectives = null,
        .objectives_len = 0,
        .has_time_limit = true,
        .time_limit = 600,
    };
    try std.testing.expect(main.idaptik_ums_set_mission(level, &mission));
    try std.testing.expect(level.mission.has_time_limit);
    try std.testing.expectEqual(@as(u32, 600), level.mission.time_limit);
}

// =========================================================================
// Test: set_physical
// =========================================================================

test "set_physical configures physical world" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const physical = types.PhysicalConfig{
        .ground_y = 0.0,
        .world_width = 5000.0,
        .interaction_distance = 2.5,
        .has_power_system = true,
        .has_security_cameras = true,
        .number_of_covert_links = 3,
    };
    try std.testing.expect(main.idaptik_ums_set_physical(level, &physical));
    try std.testing.expectEqual(@as(f64, 5000.0), level.physical.world_width);
    try std.testing.expect(level.physical.has_power_system);
}

// =========================================================================
// Test: validation — empty level passes
// =========================================================================

test "empty level passes validation" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.valid);
    try std.testing.expect(result.defence_targets_valid);
    try std.testing.expect(result.guards_in_zones);
    try std.testing.expect(result.zones_ordered);
    try std.testing.expect(result.pbx_consistent);
}

// =========================================================================
// Test: validation — guard in non-existent zone fails
// =========================================================================

test "guard referencing non-existent zone fails guards_in_zones" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // Add a guard referencing "server-room" but no zones exist.
    const guard = types.GuardPlacement{
        .world_x = .{ .position = 50.0 },
        .zone = "server-room",
        .rank = .basic_guard,
        .patrol_radius = 10.0,
    };
    try std.testing.expect(main.idaptik_ums_add_guard(level, &guard));

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.valid);
    try std.testing.expect(!result.guards_in_zones);
    // Other checks should still pass.
    try std.testing.expect(result.defence_targets_valid);
    try std.testing.expect(result.zones_ordered);
    try std.testing.expect(result.pbx_consistent);
}

// =========================================================================
// Test: validation — guard in valid zone passes
// =========================================================================

test "guard referencing existing zone passes guards_in_zones" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const zone = types.Zone{ .name = "lobby", .security_tier = 1 };
    _ = main.idaptik_ums_add_zone(level, &zone);

    const guard = types.GuardPlacement{
        .world_x = .{ .position = 50.0 },
        .zone = "lobby",
        .rank = .sentinel,
        .patrol_radius = 15.0,
    };
    _ = main.idaptik_ums_add_guard(level, &guard);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.guards_in_zones);
}

// =========================================================================
// Test: validation — unordered zone transitions fail
// =========================================================================

test "unordered zone transitions fail zones_ordered" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // Manually insert transitions out of order.
    level.zone_transitions[0] = .{
        .world_x = .{ .position = 500.0 },
        .from_zone = "a",
        .to_zone = "b",
    };
    level.zone_transitions[1] = .{
        .world_x = .{ .position = 100.0 },
        .from_zone = "b",
        .to_zone = "c",
    };
    level.zone_transitions_len = 2;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.zones_ordered);
}

// =========================================================================
// Test: validation — ordered zone transitions pass
// =========================================================================

test "ordered zone transitions pass zones_ordered" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.zone_transitions[0] = .{
        .world_x = .{ .position = 100.0 },
        .from_zone = "a",
        .to_zone = "b",
    };
    level.zone_transitions[1] = .{
        .world_x = .{ .position = 500.0 },
        .from_zone = "b",
        .to_zone = "c",
    };
    level.zone_transitions_len = 2;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.zones_ordered);
}

// =========================================================================
// Test: validation — PBX consistency
// =========================================================================

test "PBX enabled without matching device fails pbx_consistent" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.has_pbx = true;
    level.pbx_ip = types.IpAddress.init(10, 0, 0, 99);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.pbx_consistent);
    try std.testing.expect(!result.valid);
}

test "PBX enabled with matching device passes pbx_consistent" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const pbx_device = types.DeviceSpec{
        .kind = .phone_system,
        .ip = types.IpAddress.init(10, 0, 0, 99),
        .name = "pbx-main",
        .security = .medium,
    };
    _ = main.idaptik_ums_add_device(level, &pbx_device);
    level.has_pbx = true;
    level.pbx_ip = types.IpAddress.init(10, 0, 0, 99);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.pbx_consistent);
}

test "PBX disabled always passes pbx_consistent" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.has_pbx = false;
    level.pbx_ip = types.IpAddress.init(10, 0, 0, 99); // No device, but PBX off.

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.pbx_consistent);
}

// =========================================================================
// Test: validation — defence targets
// =========================================================================

test "defence config referencing non-existent device fails" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.device_defences[0] = .{
        .ip = types.IpAddress.init(10, 0, 0, 50),
        .flags = std.mem.zeroes(types.DefenceFlags),
    };
    level.device_defences_len = 1;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.defence_targets_valid);
}

test "defence config referencing existing device passes" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const dev = types.DeviceSpec{
        .kind = .firewall,
        .ip = types.IpAddress.init(10, 0, 0, 50),
        .name = "fw-1",
        .security = .strong,
    };
    _ = main.idaptik_ums_add_device(level, &dev);

    level.device_defences[0] = .{
        .ip = types.IpAddress.init(10, 0, 0, 50),
        .flags = std.mem.zeroes(types.DefenceFlags),
    };
    level.device_defences_len = 1;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.defence_targets_valid);
}

// =========================================================================
// Test: serialisation round-trip
// =========================================================================

test "serialize produces non-empty JSON" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // Add a device so there is something to serialise.
    const dev = types.DeviceSpec{
        .kind = .router,
        .ip = types.IpAddress.init(192, 168, 1, 1),
        .name = "gateway",
        .security = .medium,
    };
    _ = main.idaptik_ums_add_device(level, &dev);

    var buf: [8192]u8 = undefined;
    const written = main.idaptik_ums_serialize_level(level, &buf, buf.len);
    try std.testing.expect(written > 0);

    // Check that it starts with '{' and ends with '}'.
    try std.testing.expectEqual(@as(u8, '{'), buf[0]);
    try std.testing.expectEqual(@as(u8, '}'), buf[written - 1]);
}

test "serialize with null level returns 0" {
    var buf: [64]u8 = undefined;
    const written = main.idaptik_ums_serialize_level(null, &buf, buf.len);
    try std.testing.expectEqual(@as(usize, 0), written);
}

// =========================================================================
// Test: full lifecycle — create, populate, validate, serialise
// =========================================================================

test "full lifecycle: build a valid level" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // 1. Add devices.
    const server = types.DeviceSpec{
        .kind = .server,
        .ip = types.IpAddress.init(10, 0, 1, 1),
        .name = "db-server",
        .security = .strong,
    };
    const router = types.DeviceSpec{
        .kind = .router,
        .ip = types.IpAddress.init(10, 0, 1, 254),
        .name = "core-router",
        .security = .medium,
    };
    const pbx = types.DeviceSpec{
        .kind = .phone_system,
        .ip = types.IpAddress.init(10, 0, 1, 10),
        .name = "pbx-main",
        .security = .weak,
    };
    try std.testing.expect(main.idaptik_ums_add_device(level, &server));
    try std.testing.expect(main.idaptik_ums_add_device(level, &router));
    try std.testing.expect(main.idaptik_ums_add_device(level, &pbx));

    // 2. Add zones.
    const lobby = types.Zone{ .name = "lobby", .security_tier = 1 };
    const server_room = types.Zone{ .name = "server-room", .security_tier = 3 };
    try std.testing.expect(main.idaptik_ums_add_zone(level, &lobby));
    try std.testing.expect(main.idaptik_ums_add_zone(level, &server_room));

    // 3. Add guards in valid zones.
    const g1 = types.GuardPlacement{
        .world_x = .{ .position = 100.0 },
        .zone = "lobby",
        .rank = .basic_guard,
        .patrol_radius = 20.0,
    };
    const g2 = types.GuardPlacement{
        .world_x = .{ .position = 400.0 },
        .zone = "server-room",
        .rank = .elite_guard,
        .patrol_radius = 10.0,
    };
    try std.testing.expect(main.idaptik_ums_add_guard(level, &g1));
    try std.testing.expect(main.idaptik_ums_add_guard(level, &g2));

    // 4. Add a dog and a drone.
    const dog = types.DogPlacement{
        .world_x = .{ .position = 150.0 },
        .breed = .patrol,
        .patrol_radius = 30.0,
    };
    const drone = types.DronePlacement{
        .world_x = .{ .position = 250.0 },
        .archetype = .helper,
        .altitude = 5.0,
    };
    try std.testing.expect(main.idaptik_ums_add_dog(level, &dog));
    try std.testing.expect(main.idaptik_ums_add_drone(level, &drone));

    // 5. Set mission.
    const mission = types.MissionConfig{
        .mission_id = "m-alpha",
        .location_id = "data-centre-alpha",
        .objectives = null,
        .objectives_len = 0,
        .has_time_limit = true,
        .time_limit = 900,
    };
    try std.testing.expect(main.idaptik_ums_set_mission(level, &mission));

    // 6. Set physical.
    const physical = types.PhysicalConfig{
        .ground_y = 0.0,
        .world_width = 5000.0,
        .interaction_distance = 2.5,
        .has_power_system = true,
        .has_security_cameras = true,
        .number_of_covert_links = 2,
    };
    try std.testing.expect(main.idaptik_ums_set_physical(level, &physical));

    // 7. Set ordered zone transitions.
    level.zone_transitions[0] = .{
        .world_x = .{ .position = 300.0 },
        .from_zone = "lobby",
        .to_zone = "server-room",
    };
    level.zone_transitions_len = 1;

    // 8. Enable PBX with a matching device.
    level.has_pbx = true;
    level.pbx_ip = types.IpAddress.init(10, 0, 1, 10);
    level.pbx_world_x = .{ .position = 200.0 };

    // 9. Add a defence config referencing a real device.
    level.device_defences[0] = .{
        .ip = types.IpAddress.init(10, 0, 1, 1),
        .flags = std.mem.zeroes(types.DefenceFlags),
    };
    level.device_defences_len = 1;

    // 10. Validate — should pass all checks.
    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.valid);
    try std.testing.expect(result.defence_targets_valid);
    try std.testing.expect(result.guards_in_zones);
    try std.testing.expect(result.zones_ordered);
    try std.testing.expect(result.pbx_consistent);

    // 11. Serialise.
    var buf: [16384]u8 = undefined;
    const written = main.idaptik_ums_serialize_level(level, &buf, buf.len);
    try std.testing.expect(written > 0);
}

// =========================================================================
// Test: validate_level with null returns all-false
// =========================================================================

test "validate_level with null returns all-false" {
    const result = main.idaptik_ums_validate_level(null);
    try std.testing.expect(!result.valid);
    try std.testing.expect(!result.defence_targets_valid);
    try std.testing.expect(!result.guards_in_zones);
    try std.testing.expect(!result.zones_ordered);
    try std.testing.expect(!result.pbx_consistent);
}
