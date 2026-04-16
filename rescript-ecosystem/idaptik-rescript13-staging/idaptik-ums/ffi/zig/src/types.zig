// SPDX-License-Identifier: PMPL-1.0-or-later
// types.zig -- C-compatible type definitions for the IDApTIK UMS FFI.
// Author: Jonathan D.A. Jewell
//
// Every type here is a faithful C-ABI representation of the corresponding
// Idris2 ABI module in `../../src/abi/`.  Enums are backed by `u8` so they
// fit in a single byte; structs use `extern struct` for deterministic layout.
//
// Invariant: the discriminant values and field order MUST stay synchronised
// with the Idris2 definitions.  Any mismatch is an ABI break.

const std = @import("std");

// =========================================================================
// Primitives  (Primitives.idr)
// =========================================================================

/// An IPv4 address stored as four octets.
/// Mirrors `Primitives.IpAddress` where each octet is `Fin 256`.
pub const IpAddress = extern struct {
    octet1: u8,
    octet2: u8,
    octet3: u8,
    octet4: u8,

    /// Convenience: create an IpAddress from four literal octets.
    pub fn init(o1: u8, o2: u8, o3: u8, o4: u8) IpAddress {
        return .{ .octet1 = o1, .octet2 = o2, .octet3 = o3, .octet4 = o4 };
    }

    /// Test two addresses for equality.
    pub fn eql(self: IpAddress, other: IpAddress) bool {
        return self.octet1 == other.octet1 and
            self.octet2 == other.octet2 and
            self.octet3 == other.octet3 and
            self.octet4 == other.octet4;
    }
};

/// A percentage value bounded 0-100.
/// Mirrors `Primitives.Percentage` (`Fin 101`).
/// Values > 100 are rejected by the validation layer.
pub const Percentage = extern struct {
    value: u8,
};

/// World X coordinate for horizontal positions in the level.
/// Mirrors `Primitives.WorldX` which wraps a `Double`.
pub const WorldX = extern struct {
    position: f64,
};

/// Security strength from weakest to strongest.
/// Mirrors `Primitives.SecurityLevel`.
pub const SecurityLevel = enum(u8) {
    open = 0,
    weak = 1,
    medium = 2,
    strong = 3,
};

// =========================================================================
// Core enums  (Types.idr)
// =========================================================================

/// Hardware device categories found in the game world.
/// Mirrors `Types.DeviceKind`.
pub const DeviceKind = enum(u8) {
    laptop = 0,
    desktop = 1,
    server = 2,
    router = 3,
    switch_ = 4,
    firewall = 5,
    camera = 6,
    access_point = 7,
    patch_panel = 8,
    power_supply = 9,
    phone_system = 10,
    fibre_hub = 11,
};

/// Guard ranks ordered from weakest to most dangerous.
/// Mirrors `Types.GuardRank`.
pub const GuardRank = enum(u8) {
    basic_guard = 0,
    enforcer = 1,
    anti_hacker = 2,
    sentinel = 3,
    assassin = 4,
    elite_guard = 5,
    security_chief = 6,
    rival_hacker = 7,
};

/// Security dog breeds.
/// Mirrors `Types.DogBreed`.
pub const DogBreed = enum(u8) {
    patrol = 0,
    bloodhound = 1,
    robo_dog = 2,
};

/// Drone behaviour archetypes.
/// Mirrors `Types.DroneArchetype`.
pub const DroneArchetype = enum(u8) {
    helper = 0,
    hunter = 1,
    killer = 2,
};

/// Facility-wide alert levels.
/// Mirrors `Types.AlertLevel`.
pub const AlertLevel = enum(u8) {
    green = 0,
    yellow = 1,
    orange = 2,
    red = 3,
};

/// Physical condition of inventory items (best to worst).
/// Mirrors `Types.ItemCondition`.
pub const ItemCondition = enum(u8) {
    pristine = 0,
    good = 1,
    worn = 2,
    damaged = 3,
    broken = 4,
};

// =========================================================================
// Inventory enums  (Inventory.idr)
// =========================================================================

/// Cable connector types.
/// Mirrors `Inventory.CableType`.
pub const CableType = enum(u8) {
    ethernet = 0,
    fibre_lc = 1,
    fibre_sc = 2,
    serial = 3,
    usb = 4,
    universal = 5,
};

/// Adapter types for connecting incompatible ports.
/// Mirrors `Inventory.AdapterType`.
pub const AdapterType = enum(u8) {
    ethernet_to_fibre = 0,
    usb_to_serial = 1,
    media_converter = 2,
};

/// Specialised tool types.
/// Mirrors `Inventory.ToolType`.
pub const ToolType = enum(u8) {
    crimper = 0,
    splicer = 1,
    multimeter = 2,
    wire_cutter = 3,
    debugger = 4,
};

/// Pluggable module types (SFP/GBIC etc.).
/// Mirrors `Inventory.ModuleType`.
pub const ModuleType = enum(u8) {
    sfp = 0,
    gbic = 1,
    qsfp = 2,
    transceiver = 3,
};

/// Consumable items.
/// Mirrors `Inventory.ConsumableType`.
pub const ConsumableType = enum(u8) {
    battery_pack = 0,
    emp = 1,
    smoke_grenade = 2,
    decryptor = 3,
};

/// Discriminant for the `ItemKind` sum type.
/// Mirrors `Inventory.ItemKind` constructors.
pub const ItemKindTag = enum(u8) {
    cable = 0,
    adapter = 1,
    tool = 2,
    module_ = 3,
    storage = 4,
    consumable = 5,
    keycard = 6,
    radio = 7,
};

/// Flattened representation of the `ItemKind` sum type.
/// Each variant stores its payload in the matching union field.
/// For `storage`, the `capacity` field holds the byte count (Nat in Idris2).
/// For `keycard`, the `zone_name` field holds the zone access string.
/// For `radio`, no payload is needed.
pub const ItemKind = extern struct {
    tag: ItemKindTag,
    /// Payload for cable/adapter/tool/module/consumable variants.
    /// For storage: interpreted as capacity (cast to u32).
    /// For keycard: zone_name holds the zone string.
    /// For radio: unused (zeroed).
    sub_type: u8,
    /// Storage capacity in bytes (only meaningful when tag == .storage).
    capacity: u32,
    /// Zone name for keycard items (null-terminated, nullable).
    zone_name: ?[*:0]const u8,
};

// =========================================================================
// Wiring enums  (Wiring.idr)
// =========================================================================

/// Types of physical wiring challenge.
/// Mirrors `Wiring.WiringType`.
pub const WiringType = enum(u8) {
    patch_panel = 0,
    switch_backplane = 1,
    server_rack = 2,
    fibre_splicing = 3,
    pbx_comms = 4,
};

// =========================================================================
// Devices  (Devices.idr)
// =========================================================================

/// A device placed in the game world.
/// Mirrors `Devices.DeviceSpec`.
pub const DeviceSpec = extern struct {
    /// Hardware category.
    kind: DeviceKind,
    /// Padding byte (required for C-ABI alignment before IpAddress).
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    /// Network address of this device.
    ip: IpAddress,
    /// Human-readable device name (null-terminated UTF-8).
    name: ?[*:0]const u8,
    /// Security strength of this device.
    security: SecurityLevel,
    /// Padding to align to pointer boundary.
    _pad3: u8 = 0,
    _pad4: u8 = 0,
    _pad5: u8 = 0,
};

/// Optional IP address wrapper for C ABI.
/// `has_value == true` means `ip` is valid; otherwise treat as Nothing.
pub const OptionalIpAddress = extern struct {
    has_value: bool,
    ip: IpAddress,

    /// Construct a None (no value).
    pub fn none() OptionalIpAddress {
        return .{
            .has_value = false,
            .ip = IpAddress.init(0, 0, 0, 0),
        };
    }

    /// Construct a Some (has value).
    pub fn some(ip: IpAddress) OptionalIpAddress {
        return .{ .has_value = true, .ip = ip };
    }
};

/// Defence flags that can be applied to any device.
/// Mirrors `Devices.DefenceFlags`.
///
/// Boolean fields map to Idris2 `Bool`.
/// Optional IP fields map to `Maybe IpAddress` via `OptionalIpAddress`.
/// `instruction_whitelist` maps to `Maybe (List String)` — represented as
/// a nullable pointer to a null-terminated array of C strings.
/// `time_bomb` and `undo_immunity` map to `Maybe Nat` — represented as
/// optional u32 with a separate `has_*` flag.
pub const DefenceFlags = extern struct {
    tamper_proof: bool,
    decoy: bool,
    canary: bool,
    one_way_mirror: bool,
    kill_switch: bool,
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    failover_target: OptionalIpAddress,
    cascade_trap: OptionalIpAddress,
    mirror_target: OptionalIpAddress,
    /// Nullable pointer to a null-terminated array of null-terminated strings.
    /// Mirrors `Maybe (List String)`.  `null` means Nothing.
    instruction_whitelist: ?[*:null]const ?[*:0]const u8,
    has_time_bomb: bool,
    _pad3: u8 = 0,
    _pad4: u8 = 0,
    _pad5: u8 = 0,
    time_bomb: u32,
    has_undo_immunity: bool,
    _pad6: u8 = 0,
    _pad7: u8 = 0,
    _pad8: u8 = 0,
    undo_immunity: u32,
};

/// Associates defence flags with a specific device by IP.
/// Mirrors `Devices.DeviceDefenceConfig`.
pub const DeviceDefenceConfig = extern struct {
    ip: IpAddress,
    flags: DefenceFlags,
};

// =========================================================================
// Zones  (Zones.idr)
// =========================================================================

/// A named security zone with a tier indicating clearance required.
/// Mirrors `Zones.Zone`.
pub const Zone = extern struct {
    /// Zone display name (null-terminated UTF-8).
    name: ?[*:0]const u8,
    /// Security clearance tier (higher = more restricted).
    security_tier: u32,
};

/// A transition point between two zones at a world X coordinate.
/// Mirrors `Zones.ZoneTransition`.
pub const ZoneTransition = extern struct {
    /// Horizontal position of the transition boundary.
    world_x: WorldX,
    /// Name of the zone the player is leaving.
    from_zone: ?[*:0]const u8,
    /// Name of the zone the player is entering.
    to_zone: ?[*:0]const u8,
};

// =========================================================================
// Inventory structs  (Inventory.idr)
// =========================================================================

/// An inventory item with full metadata.
/// Mirrors `Inventory.Item`.
pub const Item = extern struct {
    /// Unique identifier for this item instance.
    id: ?[*:0]const u8,
    /// What kind of item this is.
    kind: ItemKind,
    /// Human-readable name.
    name: ?[*:0]const u8,
    /// Weight in abstract units.
    weight: u32,
    /// Physical condition.
    condition: ItemCondition,
    /// Whether this item has limited uses.
    has_uses_remaining: bool,
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    /// Number of uses left (only valid when has_uses_remaining == true).
    uses_remaining: u32,
};

/// An item placed in the game world inside a container device.
/// Mirrors `Inventory.WorldItem`.
pub const WorldItem = extern struct {
    /// The item itself.
    item: Item,
    /// Horizontal position in the world.
    world_x: WorldX,
    /// Name of the container device holding this item.
    container: ?[*:0]const u8,
};

// =========================================================================
// Guards  (Guards.idr)
// =========================================================================

/// A guard placed in the game world.
/// Mirrors `Guards.GuardPlacement`.
pub const GuardPlacement = extern struct {
    /// Horizontal position.
    world_x: WorldX,
    /// Zone this guard patrols in.
    zone: ?[*:0]const u8,
    /// Combat rank / difficulty tier.
    rank: GuardRank,
    /// Padding for alignment before f64.
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    _pad3: u8 = 0,
    _pad4: u8 = 0,
    _pad5: u8 = 0,
    _pad6: u8 = 0,
    /// How far the guard roams from world_x.
    patrol_radius: f64,
};

// =========================================================================
// Dogs  (Dogs.idr)
// =========================================================================

/// A security dog placed in the game world.
/// Mirrors `Dogs.DogPlacement`.
pub const DogPlacement = extern struct {
    /// Horizontal position.
    world_x: WorldX,
    /// Dog breed / behaviour type.
    breed: DogBreed,
    /// Padding for alignment before f64.
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    _pad3: u8 = 0,
    _pad4: u8 = 0,
    _pad5: u8 = 0,
    _pad6: u8 = 0,
    /// How far the dog roams from world_x.
    patrol_radius: f64,
};

// =========================================================================
// Drones  (Drones.idr)
// =========================================================================

/// A drone placed in the game world.
/// Mirrors `Drones.DronePlacement`.
pub const DronePlacement = extern struct {
    /// Horizontal position.
    world_x: WorldX,
    /// Behaviour archetype.
    archetype: DroneArchetype,
    /// Padding for alignment before f64.
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    _pad3: u8 = 0,
    _pad4: u8 = 0,
    _pad5: u8 = 0,
    _pad6: u8 = 0,
    /// Flying altitude above ground_y.
    altitude: f64,
};

// =========================================================================
// Assassin  (Assassin.idr)
// =========================================================================

/// Assassin encounter configuration.
/// Mirrors `Assassin.AssassinConfig`.
pub const AssassinConfig = extern struct {
    /// Horizontal spawn position.
    spawn_x: WorldX,
    /// Number of ambush waves.
    ambush_count: u32,
    /// Health threshold (percentage) at which the assassin retreats.
    retreat_threshold: u32,
};

// =========================================================================
// Mission  (Mission.idr)
// =========================================================================

/// A single mission objective.
/// Mirrors `Mission.MissionObjective`.
pub const MissionObjective = extern struct {
    /// Unique objective identifier.
    id: ?[*:0]const u8,
    /// Human-readable description.
    description: ?[*:0]const u8,
    /// Whether completing this objective is mandatory for mission success.
    required: bool,
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    _pad3: u8 = 0,
    _pad4: u8 = 0,
    _pad5: u8 = 0,
    _pad6: u8 = 0,
};

/// Top-level mission configuration for a level.
/// Mirrors `Mission.MissionConfig`.
pub const MissionConfig = extern struct {
    /// Unique mission identifier.
    mission_id: ?[*:0]const u8,
    /// Location / facility identifier.
    location_id: ?[*:0]const u8,
    /// Dynamic array of objectives.  `objectives_len` gives the count.
    objectives: ?[*]const MissionObjective,
    objectives_len: u32,
    /// Whether the mission has a time limit.
    has_time_limit: bool,
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    /// Time limit in seconds (only valid when has_time_limit == true).
    time_limit: u32,
};

// =========================================================================
// Wiring  (Wiring.idr)
// =========================================================================

/// A wiring challenge attached to a specific device.
/// Mirrors `Wiring.WiringChallenge`.
pub const WiringChallenge = extern struct {
    /// Type of wiring puzzle.
    kind: WiringType,
    /// Padding for alignment.
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    /// IP of the device this challenge is attached to.
    device_ip: IpAddress,
    /// Difficulty rating (higher = harder).
    difficulty: u32,
};

// =========================================================================
// Physical  (Physical.idr)
// =========================================================================

/// Physical properties of the game world.
/// Mirrors `Physical.PhysicalConfig`.
pub const PhysicalConfig = extern struct {
    /// Vertical position of the ground plane.
    ground_y: f64,
    /// Total horizontal extent of the level.
    world_width: f64,
    /// Maximum distance at which the player can interact with objects.
    interaction_distance: f64,
    /// Whether the level has an active power distribution system.
    has_power_system: bool,
    /// Whether the level has security camera infrastructure.
    has_security_cameras: bool,
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    /// Number of hidden covert network links in the level.
    number_of_covert_links: u32,
};

// =========================================================================
// Level  (Level.idr)
// =========================================================================

/// Maximum number of elements in each dynamic list inside `LevelData`.
/// These caps prevent unbounded allocation and make the struct fixed-size
/// for C-ABI consumers that cannot handle heap-allocated dynamic arrays.
pub const MAX_DEVICES: usize = 256;
pub const MAX_ZONES: usize = 64;
pub const MAX_GUARDS: usize = 128;
pub const MAX_DOGS: usize = 64;
pub const MAX_DRONES: usize = 64;
pub const MAX_ASSASSINS: usize = 16;
pub const MAX_ITEMS: usize = 512;
pub const MAX_WIRING: usize = 128;
pub const MAX_ZONE_TRANSITIONS: usize = 64;
pub const MAX_DEVICE_DEFENCES: usize = 256;
pub const MAX_OBJECTIVES: usize = 32;

/// Complete level data composed from all sub-domain records.
/// Mirrors `Level.LevelData`.
///
/// Each list field from the Idris2 record is represented as a fixed-capacity
/// array plus a count.  This keeps the struct C-ABI compatible while allowing
/// dynamic population through the `add_*` FFI functions.
pub const LevelData = extern struct {
    // -- Devices --
    devices: [MAX_DEVICES]DeviceSpec,
    devices_len: u32,

    // -- Zones --
    zones: [MAX_ZONES]Zone,
    zones_len: u32,

    // -- Guards --
    guards: [MAX_GUARDS]GuardPlacement,
    guards_len: u32,

    // -- Dogs --
    dogs: [MAX_DOGS]DogPlacement,
    dogs_len: u32,

    // -- Drones --
    drones: [MAX_DRONES]DronePlacement,
    drones_len: u32,

    // -- Assassins --
    assassins: [MAX_ASSASSINS]AssassinConfig,
    assassins_len: u32,

    // -- World items --
    items: [MAX_ITEMS]WorldItem,
    items_len: u32,

    // -- Wiring challenges --
    wiring: [MAX_WIRING]WiringChallenge,
    wiring_len: u32,

    // -- Mission --
    mission: MissionConfig,

    // -- Physical config --
    physical: PhysicalConfig,

    // -- Zone transitions --
    zone_transitions: [MAX_ZONE_TRANSITIONS]ZoneTransition,
    zone_transitions_len: u32,

    // -- Device defences --
    device_defences: [MAX_DEVICE_DEFENCES]DeviceDefenceConfig,
    device_defences_len: u32,

    // -- PBX fields --
    /// Whether this level has a PBX phone system.
    has_pbx: bool,
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
    /// IP of the PBX device (only meaningful when has_pbx == true).
    pbx_ip: IpAddress,
    /// World X position of the PBX device.
    pbx_world_x: WorldX,
};

// =========================================================================
// Validation  (Validation.idr)
// =========================================================================

/// Individual validation check identifiers.
/// These correspond to the four erased proof fields in
/// `Validation.ValidatedLevel`.
pub const ValidationCheck = enum(u8) {
    /// All defence config IPs and targets reference real devices.
    defence_targets_valid = 0,
    /// Every guard's zone field names a zone that exists.
    guards_in_zones = 1,
    /// Zone transitions are monotonically increasing in X.
    zones_ordered = 2,
    /// If PBX is enabled, its IP exists in the device registry.
    pbx_consistent = 3,
};

/// Result of running all validation checks on a LevelData.
/// Mirrors the erased proof fields of `Validation.ValidatedLevel`,
/// materialised as runtime booleans for the FFI boundary.
pub const ValidationResult = extern struct {
    /// Overall pass/fail — true only when ALL checks pass.
    valid: bool,
    /// Per-check results (true = passed).
    defence_targets_valid: bool,
    guards_in_zones: bool,
    zones_ordered: bool,
    pbx_consistent: bool,
    _pad0: u8 = 0,
    _pad1: u8 = 0,
    _pad2: u8 = 0,
};
