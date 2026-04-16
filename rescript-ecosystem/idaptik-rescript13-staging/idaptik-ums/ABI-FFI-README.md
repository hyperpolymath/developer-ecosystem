# IDApTIK UMS — ABI/FFI Architecture

<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->

## Overview

The Universal Modding Studio uses the hyperpolymath standard ABI/FFI/API architecture:

| Layer | Language | Purpose | Location |
|-------|----------|---------|----------|
| **ABI** | Idris2 | Level data model with dependent type proofs | `src/abi/` |
| **FFI** | Zig | C-compatible shared library | `ffi/zig/` |
| **Headers** | C (generated) | Bridge between ABI and FFI consumers | `generated/abi/` |
| **Shell** | Rust (Gossamer) | Desktop app with IPC commands | `src-gossamer/` |
| **Frontend** | ReScript | Editor UI and generators | `src/` |

## ABI Layer (Idris2)

14 modules defining the game level data model with formal proofs:

| Module | Purpose |
|--------|---------|
| Primitives | IpAddress, Percentage, WorldX, SecurityLevel |
| Types | DeviceKind, GuardRank, DogBreed, DroneArchetype, AlertLevel, ItemCondition |
| Devices | DeviceSpec, DefenceFlags, DeviceDefenceConfig |
| Zones | Zone, ZoneTransition |
| Inventory | CableType, AdapterType, ToolType, ModuleType, ConsumableType, WorldItem |
| Guards | GuardPlacement |
| Dogs | DogPlacement |
| Drones | DronePlacement |
| Assassin | AssassinConfig |
| Mission | MissionObjective, MissionConfig |
| Wiring | WiringChallenge |
| Physical | PhysicalConfig |
| Level | LevelData (composite of all above) |
| Validation | 5 cross-domain proofs + ValidatedLevel record |

### Formal Proofs (Validation.idr)

All proofs are erased at compile time (0-quantity fields) — zero runtime cost:

1. **InRegistry** — Device IP exists in the device registry
2. **GuardsInZones** — All guards reference valid zones
3. **DefenceTargetsValid** — Failover/cascade/mirror targets reference real devices
4. **ZonesOrdered** — Zone transitions monotonically increase in X
5. **PBXConsistent** — When hasPBX=True, pbxAddr exists in registry

No `believe_me`, `assert_total`, or `sorry` used anywhere.

## FFI Layer (Zig)

12 exported C-ABI functions in `libidaptik_ums.so`:

```
idaptik_ums_create_level      → *LevelData
idaptik_ums_destroy_level     → void
idaptik_ums_add_device        → bool
idaptik_ums_add_zone          → bool
idaptik_ums_add_guard         → bool
idaptik_ums_add_dog           → bool
idaptik_ums_add_drone         → bool
idaptik_ums_set_mission       → bool
idaptik_ums_set_physical      → bool
idaptik_ums_validate_level    → ValidationResult
idaptik_ums_serialize_level   → usize
idaptik_ums_deserialize_level → ?*LevelData
```

The validation function materialises the 5 erased Idris2 proofs at runtime.

## Building

```bash
# Build Zig FFI
cd ffi/zig && zig build

# Run Zig tests (20 integration tests)
cd ffi/zig && zig build test

# Build Gossamer desktop app
cargo build

# Run Rust tests
cargo test
```

## Data Flow

```
User interaction (Canvas UI)
    ↓ ReScript editor state
JSON serialisation (LevelConfigCodec)
    ↓ Gossamer IPC
Rust validation (mirrors Idris2 proofs)
    ↓ or alternatively
Zig FFI validation (libidaptik_ums.so)
    ↓
Validated level data → export to game
```
