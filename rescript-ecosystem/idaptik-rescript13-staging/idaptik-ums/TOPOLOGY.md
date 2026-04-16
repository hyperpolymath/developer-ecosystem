# IDApTIK UMS — Module Topology

<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->

## Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│                    Editor UI (ReScript)              │
│  App.res → Editor.res → Canvas/Toolbar/Properties   │
├─────────────────────────────────────────────────────┤
│               Gossamer Shell (Rust)                  │
│  main.rs (6 IPC commands via gossamer-rs)            │
├─────────────────────────────────────────────────────┤
│              ReScript Generators (26 modules)        │
│  LevelGen → NetworkGen → LevelExport → LevelRender  │
│  LevelConfigCodec ↔ LevelConfigTypes                │
├─────────────────────────────────────────────────────┤
│                   Zig FFI (12 exports)              │
│  types.zig → main.zig → validate.zig               │
│  → libidaptik_ums.so / libidaptik_ums.a             │
├─────────────────────────────────────────────────────┤
│               Idris2 ABI (15 modules)               │
│  Primitives → Types → Devices → Zones → ...         │
│  → Level → Validation → ProvenBridge                │
├─────────────────────────────────────────────────────┤
│                 Generated Artifacts                  │
│  generated/abi/idaptik_ums.h (C header)             │
└─────────────────────────────────────────────────────┘
```

## Directory Map

```
idaptik-ums/
├── src/
│   ├── abi/                    # Idris2 ABI definitions (15 modules)
│   │   ├── Primitives.idr      # IpAddress, Percentage, WorldX, SecurityLevel
│   │   ├── Types.idr           # DeviceKind, GuardRank, DogBreed, etc.
│   │   ├── Devices.idr         # DeviceSpec, DefenceFlags
│   │   ├── Zones.idr           # Zone, ZoneTransition
│   │   ├── Inventory.idr       # Item types
│   │   ├── Guards.idr          # GuardPlacement
│   │   ├── Dogs.idr            # DogPlacement
│   │   ├── Drones.idr          # DronePlacement
│   │   ├── Assassin.idr        # AssassinConfig
│   │   ├── Mission.idr         # MissionConfig
│   │   ├── Wiring.idr          # WiringChallenge
│   │   ├── Physical.idr        # PhysicalConfig
│   │   ├── Level.idr           # LevelData (composite)
│   │   ├── Validation.idr      # 5 cross-domain proofs + ValidatedLevel
│   │   └── ProvenBridge.idr    # SafeJson integration scaffold
│   ├── editor/                 # Visual editor modules (8 files)
│   │   ├── EditorModel.res     # Types and state
│   │   ├── EditorEngine.res    # Pure computation, entity CRUD, undo/redo
│   │   ├── EditorCanvas.res    # Canvas 2D rendering (4 layers)
│   │   ├── EditorToolbar.res   # Tool palette sidebar
│   │   ├── EditorProperties.res # Property inspector
│   │   ├── EditorValidation.res # ABI proof badges
│   │   ├── EditorCmd.res       # Gossamer IPC wrappers
│   │   └── Editor.res          # Main TEA compositor
│   ├── generator/              # Procedural level generation (16 modules)
│   │   ├── LevelGen.res.mjs    # Grid-based generation
│   │   ├── LevelRender.res.mjs # Canvas rendering
│   │   ├── NetworkGen.res.mjs  # Network topology
│   │   ├── LevelExport.res.mjs # Export to LevelConfig
│   │   └── ...
│   ├── App.res                 # Main application entry point
│   ├── Model.res.mjs           # Level data model
│   ├── LevelConfigTypes.res.mjs # Defence flags
│   └── LevelConfigCodec.res.mjs # JSON codec
├── ffi/zig/                    # Zig FFI implementation
│   ├── src/
│   │   ├── types.zig           # C-compatible type definitions
│   │   ├── main.zig            # 12 exported functions
│   │   └── validate.zig        # Runtime proof materialisation
│   ├── test/
│   │   └── integration_test.zig # 20 integration tests
│   ├── build.zig               # Build configuration
│   └── build.zig.zon           # Package manifest
├── generated/abi/
│   └── idaptik_ums.h           # C header (auto-generated from ABI)
├── src-gossamer/               # Gossamer desktop shell
│   └── main.rs                 # App entry + 6 IPC commands + tests
├── Cargo.toml                  # Rust dependencies (gossamer-rs)
├── gossamer.conf.json          # Window config, CSP, capabilities
├── test-data/
│   ├── sample-level.json       # Valid level (exercises all 5 proofs)
│   └── invalid-level.json      # Invalid level (fails all 5 proofs)
├── docs/design/
│   ├── PROVEN-INTEGRATION.md   # SafeJson integration plan
│   └── GAME-INTEGRATION.md     # Game ↔ UMS field mapping
├── idaptik-ums.ipkg            # Idris2 package config
├── rescript.json               # ReScript build config
├── deno.json                   # Deno tasks
├── ABI-FFI-README.md           # ABI/FFI architecture docs
└── TOPOLOGY.md                 # This file
```

## Data Flow

```
User (canvas click) → EditorEngine (entity CRUD)
    → EditorCanvas (render) + EditorProperties (inspect)
    → EditorCmd.saveLevel → Gossamer IPC
    → main.rs validate_level_abi → 5 proof checks
    → EditorValidation (display results)
    → EditorCmd.exportLevelConfig → ReScript LevelConfig
    → game/src/shared/UmsLevelLoader.res → LevelConfig.levelConfig
    → GameLoop.startMission
```

## Verification Pipeline

| Stage | Language | What it checks | When |
|-------|----------|---------------|------|
| Compile-time | Idris2 | Dependent type proofs (erased) | `idris2 --check` |
| Build-time | Zig | Type safety, memory safety | `zig build test` |
| Runtime | Rust | 5 ABI proofs (mirrors Idris2) | Gossamer command |
| Runtime | Zig FFI | 5 ABI proofs (via libidaptik_ums) | FFI call |
| Cross-panel | TypeLL | Level data type checking | PanLL validation |
| Cross-panel | BoJ | UMS cartridge routing | ums-mcp |

## Test Coverage

| Layer | Tests | Runner |
|-------|-------|--------|
| Idris2 ABI | type-checks | `idris2 --check` |
| Zig FFI | 20 | `zig build test` |
| Rust shell | 17 | `cargo test` |
| Test data | 2 fixtures | used by Rust tests |
