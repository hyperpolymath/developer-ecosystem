// SPDX-License-Identifier: PMPL-1.0-or-later
// validate.zig -- Runtime validation checks for IDApTIK UMS level data.
// Author: Jonathan D.A. Jewell
//
// These functions implement the four cross-domain invariants that are
// expressed as erased dependent-type proofs in Validation.idr:
//
//   1. DefenceTargetsValid  -- defence failover/cascade/mirror IPs exist
//   2. GuardsInZones        -- every guard references a real zone
//   3. ZonesOrdered         -- zone transitions are monotonically increasing
//   4. PBXConsistent        -- if PBX enabled, its IP is in the device list
//
// At the Idris2 level these are compile-time proofs with zero runtime cost.
// At the FFI boundary we must materialise them as runtime checks because
// C callers cannot carry dependent-type witnesses.

const types = @import("types");

// =========================================================================
// Helper: check whether an IP exists in the device array
// =========================================================================

/// Search the device list for a device whose IP matches `needle`.
/// Returns true if found.
fn ipExistsInDevices(
    needle: types.IpAddress,
    devices: []const types.DeviceSpec,
) bool {
    for (devices) |dev| {
        if (needle.eql(dev.ip)) return true;
    }
    return false;
}

/// Check an OptionalIpAddress: if it has a value, that IP must exist in
/// the device list.  Returns true if the optional is empty OR the IP exists.
fn optionalIpValid(
    opt: types.OptionalIpAddress,
    devices: []const types.DeviceSpec,
) bool {
    if (!opt.has_value) return true;
    return ipExistsInDevices(opt.ip, devices);
}

// =========================================================================
// Check 1: Defence targets valid
// =========================================================================

/// Verify that every DeviceDefenceConfig:
///   - has its own IP present in the device registry, AND
///   - any failover_target, cascade_trap, or mirror_target that is set
///     also references a device in the registry.
///
/// Mirrors `Validation.DefenceTargetsValid`.
pub fn checkDefenceTargetsValid(level: *const types.LevelData) bool {
    const devices = level.devices[0..level.devices_len];
    const defences = level.device_defences[0..level.device_defences_len];

    for (defences) |def| {
        // The defence config's own IP must reference a real device.
        if (!ipExistsInDevices(def.ip, devices)) return false;

        // Each optional target must either be Nothing or reference a real device.
        if (!optionalIpValid(def.flags.failover_target, devices)) return false;
        if (!optionalIpValid(def.flags.cascade_trap, devices)) return false;
        if (!optionalIpValid(def.flags.mirror_target, devices)) return false;
    }
    return true;
}

// =========================================================================
// Check 2: Guards in zones
// =========================================================================

/// Return true if `zone_name` matches the name of any zone in the list.
fn zoneExists(zone_name: [*:0]const u8, zones: []const types.Zone) bool {
    const needle = std.mem.span(zone_name);
    for (zones) |z| {
        if (z.name) |zn| {
            const zn_span = std.mem.span(zn);
            if (std.mem.eql(u8, needle, zn_span)) return true;
        }
    }
    return false;
}

const std = @import("std");

/// Verify that every guard's `zone` field names a zone present in
/// the level's zone list.
///
/// Mirrors `Validation.GuardsInZones`.
pub fn checkGuardsInZones(level: *const types.LevelData) bool {
    const zones = level.zones[0..level.zones_len];
    const guards = level.guards[0..level.guards_len];

    for (guards) |guard| {
        if (guard.zone) |zone_name| {
            if (!zoneExists(zone_name, zones)) return false;
        } else {
            // A guard with a null zone pointer is always invalid.
            return false;
        }
    }
    return true;
}

// =========================================================================
// Check 3: Zones ordered (monotonically increasing X)
// =========================================================================

/// Verify that zone transitions are sorted by ascending world X position.
///
/// Mirrors `Validation.ZonesOrdered`.
pub fn checkZonesOrdered(level: *const types.LevelData) bool {
    const transitions = level.zone_transitions[0..level.zone_transitions_len];
    if (transitions.len <= 1) return true;

    var prev_x = transitions[0].world_x.position;
    for (transitions[1..]) |t| {
        if (t.world_x.position < prev_x) return false;
        prev_x = t.world_x.position;
    }
    return true;
}

// =========================================================================
// Check 4: PBX consistent
// =========================================================================

/// When `has_pbx` is true, the `pbx_ip` must exist in the device list.
/// When `has_pbx` is false, no constraint is imposed.
///
/// Mirrors `Validation.PBXConsistent`.
pub fn checkPBXConsistent(level: *const types.LevelData) bool {
    if (!level.has_pbx) return true;
    const devices = level.devices[0..level.devices_len];
    return ipExistsInDevices(level.pbx_ip, devices);
}

// =========================================================================
// Aggregate validation
// =========================================================================

/// Run all four validation checks and return a composite result.
/// This is the runtime materialisation of `Validation.ValidatedLevel`
/// where the erased proof fields become boolean flags.
pub fn validateLevel(level: *const types.LevelData) types.ValidationResult {
    const dtv = checkDefenceTargetsValid(level);
    const giz = checkGuardsInZones(level);
    const zo = checkZonesOrdered(level);
    const pbx = checkPBXConsistent(level);

    return .{
        .valid = dtv and giz and zo and pbx,
        .defence_targets_valid = dtv,
        .guards_in_zones = giz,
        .zones_ordered = zo,
        .pbx_consistent = pbx,
    };
}
