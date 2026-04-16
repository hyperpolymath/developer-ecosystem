/* SPDX-License-Identifier: PMPL-1.0-or-later */
/* Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> */
/*
 * idaptik_ums.h — C header for the IDApTIK UMS level architect FFI.
 *
 * AUTO-GENERATED from Idris2 ABI definitions (src/abi/*.idr) via Zig FFI
 * (ffi/zig/src/types.zig). Do NOT edit by hand; regenerate from source.
 *
 * This header provides the C-compatible interface for creating, populating,
 * validating, and serialising game levels. The validation functions materialise
 * the 5 erased Idris2 proofs at runtime:
 *
 *   1. GuardsInZones     — all guards reference valid zones
 *   2. DefenceTargetsValid — failover/cascade/mirror IPs exist in registry
 *   3. ZonesOrdered       — zone transitions monotonically increase in X
 *   4. PBXConsistent      — when hasPBX=true, pbxAddr exists in registry
 *   5. DevicesExist       — all defence config IPs exist in device registry
 */

#ifndef IDAPTIK_UMS_H
#define IDAPTIK_UMS_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ════════════════════════════════════════════════════════════════════════
 * Enumerations (mirroring Idris2 Types.idr)
 * ════════════════════════════════════════════════════════════════════════ */

/** Hardware device categories in the game world. */
typedef enum {
    DEVICE_LAPTOP = 0,
    DEVICE_DESKTOP,
    DEVICE_SERVER,
    DEVICE_ROUTER,
    DEVICE_SWITCH,
    DEVICE_FIREWALL,
    DEVICE_CAMERA,
    DEVICE_ACCESS_POINT,
    DEVICE_PATCH_PANEL,
    DEVICE_POWER_SUPPLY,
    DEVICE_PHONE_SYSTEM,
    DEVICE_FIBRE_HUB,
} DeviceKind;

/** Security levels from weakest to strongest. */
typedef enum {
    SECURITY_OPEN = 0,
    SECURITY_WEAK,
    SECURITY_MEDIUM,
    SECURITY_STRONG,
} SecurityLevel;

/** Guard ranks from weakest to most dangerous. */
typedef enum {
    GUARD_BASIC = 0,
    GUARD_ENFORCER,
    GUARD_ANTI_HACKER,
    GUARD_SENTINEL,
    GUARD_ASSASSIN,
    GUARD_ELITE,
    GUARD_SECURITY_CHIEF,
    GUARD_RIVAL_HACKER,
} GuardRank;

/** Security dog breeds. */
typedef enum {
    DOG_PATROL = 0,
    DOG_BLOODHOUND,
    DOG_ROBO_DOG,
} DogBreed;

/** Drone behaviour archetypes. */
typedef enum {
    DRONE_HELPER = 0,
    DRONE_HUNTER,
    DRONE_KILLER,
} DroneArchetype;

/** Facility-wide alert levels. */
typedef enum {
    ALERT_GREEN = 0,
    ALERT_YELLOW,
    ALERT_ORANGE,
    ALERT_RED,
} AlertLevel;

/** Physical condition of inventory items. */
typedef enum {
    CONDITION_PRISTINE = 0,
    CONDITION_GOOD,
    CONDITION_WORN,
    CONDITION_DAMAGED,
    CONDITION_BROKEN,
} ItemCondition;

/* ════════════════════════════════════════════════════════════════════════
 * Structures (mirroring Idris2 records)
 * ════════════════════════════════════════════════════════════════════════ */

/** An IPv4 address as four bounded octets. */
typedef struct {
    uint8_t octet1;
    uint8_t octet2;
    uint8_t octet3;
    uint8_t octet4;
} IpAddress;

/** A device placed in the game world (Devices.idr: DeviceSpec). */
typedef struct {
    DeviceKind kind;
    IpAddress ip;
    const char* name;
    SecurityLevel security;
} DeviceSpec;

/** A named security zone with a tier (Zones.idr: Zone). */
typedef struct {
    const char* name;
    uint32_t security_tier;
} Zone;

/** A guard placement in the world (Guards.idr). */
typedef struct {
    GuardRank rank;
    const char* zone;
    double world_x;
    double patrol_radius;
} GuardPlacement;

/** A security dog placement (Dogs.idr). */
typedef struct {
    DogBreed breed;
    double world_x;
    double patrol_radius;
} DogPlacement;

/** A drone placement (Drones.idr). */
typedef struct {
    DroneArchetype archetype;
    double world_x;
    double altitude;
} DronePlacement;

/** Validation result for a level (maps to Validation.idr proofs). */
typedef struct {
    bool guards_in_zones;
    bool defence_targets_valid;
    bool zones_ordered;
    bool pbx_consistent;
    bool devices_exist;
    bool all_passed;
} ValidationResult;

/* ════════════════════════════════════════════════════════════════════════
 * Opaque handle
 * ════════════════════════════════════════════════════════════════════════ */

/** Opaque handle to a LevelData structure managed by the Zig FFI. */
typedef struct LevelData LevelData;

/* ════════════════════════════════════════════════════════════════════════
 * FFI Functions (12 exports from ffi/zig/src/main.zig)
 * ════════════════════════════════════════════════════════════════════════ */

/** Create a new empty level. Caller must call idaptik_ums_destroy_level. */
LevelData* idaptik_ums_create_level(void);

/** Destroy a level and free all associated memory. */
void idaptik_ums_destroy_level(LevelData* level);

/** Add a device to the level. Returns true on success. */
bool idaptik_ums_add_device(LevelData* level, const DeviceSpec* device);

/** Add a security zone to the level. Returns true on success. */
bool idaptik_ums_add_zone(LevelData* level, const Zone* zone);

/** Add a guard placement. Returns true on success. */
bool idaptik_ums_add_guard(LevelData* level, const GuardPlacement* guard);

/** Add a security dog placement. Returns true on success. */
bool idaptik_ums_add_dog(LevelData* level, const DogPlacement* dog);

/** Add a drone placement. Returns true on success. */
bool idaptik_ums_add_drone(LevelData* level, const DronePlacement* drone);

/** Set the mission configuration. Returns true on success. */
bool idaptik_ums_set_mission(LevelData* level, const void* mission);

/** Set the physical world configuration. Returns true on success. */
bool idaptik_ums_set_physical(LevelData* level, const void* physical);

/** Validate the level against all 5 Idris2 ABI proofs. */
ValidationResult idaptik_ums_validate_level(const LevelData* level);

/** Serialise the level to JSON. Returns bytes written, 0 on failure. */
size_t idaptik_ums_serialize_level(const LevelData* level, uint8_t* buf, size_t buf_len);

/** Deserialise a level from JSON. Returns NULL on failure. */
LevelData* idaptik_ums_deserialize_level(const uint8_t* data, size_t data_len);

#ifdef __cplusplus
}
#endif

#endif /* IDAPTIK_UMS_H */
