# UMS to Game LevelConfig Integration

SPDX-License-Identifier: PMPL-1.0-or-later

## Overview

The IDApTIK UMS (Universal Mission System) generates procedural levels and
exports them as JSON.  The game client reads hardcoded levels from
`src/app/screens/LevelConfig.res` via `getConfig(locationId)`.  This document
describes the bridge that allows UMS-exported levels to be loaded by the game
at runtime, bypassing the hardcoded database.

## Architecture

```
┌──────────────┐     JSON string     ┌──────────────────┐     levelConfig     ┌──────────┐
│  UMS Export   │ ─────────────────> │  UmsLevelLoader   │ ─────────────────> │ GameLoop  │
│  (LevelExport │   (file or IPC)   │  (src/shared/)    │   option<config>   │          │
│   + Codec)    │                    │                    │                    │          │
└──────────────┘                    └──────────────────┘                    └──────────┘
```

1. **UMS side**: `LevelExport.exportToJson(level, topology, power)` produces a
   JSON string via `LevelConfigCodec.toJsonString`.
2. **Game side**: `UmsLevelLoader.loadFromJson(jsonString)` parses that JSON
   into the game's native `LevelConfig.levelConfig` type.
3. **File loading**: `UmsLevelLoader.loadFromFile(path)` reads a JSON file via
   Tauri's `readTextFile` and feeds it through `loadFromJson`.

## JSON Schema

The UMS produces JSON with the following top-level structure.  Field names are
**identical** on both sides (UMS codec and game types share the same spec).

```json
{
  "locationId": "gen_office_42",
  "missionId": "gen_mission_1",
  "worldItems": [ ... ],
  "guardPlacements": [ ... ],
  "deviceDefences": [ ... ],
  "hasPowerSystem": true,
  "hasSecurityCameras": false,
  "numberOfCovertLinks": 2,
  "hasPBX": true,
  "pbxIpAddress": "10.0.1.50",
  "pbxWorldX": 1200.0,
  "zoneTransitions": [ ... ]
}
```

### worldItems

```json
{
  "item": {
    "id": "w_eth1",
    "kind": { "type": "Cable", "subtype": "Ethernet" },
    "name": "Cat5e Cable (3m)",
    "weight": 0.2,
    "condition": "Good",
    "usesRemaining": null,
    "cableLength": 3.0,
    "description": "Found in supply closet"
  },
  "x": 450.0,
  "container": "supply_room",
  "collected": false
}
```

### guardPlacements

```json
{
  "x": 600.0,
  "zone": "downtown_lan",
  "rank": "Enforcer",
  "patrolRadius": 300.0
}
```

### deviceDefences

```json
{
  "ipAddress": "10.0.0.20",
  "flags": {
    "tamperProof": false,
    "decoy": false,
    "canary": true,
    "oneWayMirror": false,
    "killSwitch": false,
    "failoverTarget": null,
    "cascadeTrap": null,
    "instructionWhitelist": null,
    "timeBomb": null,
    "mirrorTarget": null,
    "undoImmunity": null
  }
}
```

### zoneTransitions

```json
{
  "x": 0.0,
  "fromZone": "outside",
  "toZone": "downtown_lan"
}
```

### Item Kind Encoding

| Inventory.itemKind variant | JSON `type` | JSON `subtype` | Extra fields |
|---|---|---|---|
| `Cable(Ethernet)` | `"Cable"` | `"Ethernet"` | — |
| `Cable(FibreLC)` | `"Cable"` | `"FibreLC"` | — |
| `Cable(FibreSC)` | `"Cable"` | `"FibreSC"` | — |
| `Cable(Serial)` | `"Cable"` | `"Serial"` | — |
| `Cable(USB)` | `"Cable"` | `"USB"` | — |
| `Cable(Universal)` | `"Cable"` | `"Universal"` | — |
| `Adapter(USBToSerial)` | `"Adapter"` | `"USBToSerial"` | — |
| `Adapter(MediaConverter)` | `"Adapter"` | `"MediaConverter"` | — |
| `Adapter(GenderChanger)` | `"Adapter"` | `"GenderChanger"` | — |
| `Adapter(RJ45toRJ11)` | `"Adapter"` | `"RJ45toRJ11"` | — |
| `Tool(Crimper)` | `"Tool"` | `"Crimper"` | — |
| `Tool(FibreCleaver)` | `"Tool"` | `"FibreCleaver"` | — |
| `Tool(FibreSplicer)` | `"Tool"` | `"FibreSplicer"` | — |
| `Tool(OTDR)` | `"Tool"` | `"OTDR"` | — |
| `Tool(WireCutters)` | `"Tool"` | `"WireCutters"` | — |
| `Tool(Multimeter)` | `"Tool"` | `"Multimeter"` | — |
| `Module(SFP1G)` | `"Module"` | `"SFP1G"` | — |
| `Module(SFP10G)` | `"Module"` | `"SFP10G"` | — |
| `Module(GBIC)` | `"Module"` | `"GBIC"` | — |
| `Module(RJ45Transceiver)` | `"Module"` | `"RJ45Transceiver"` | — |
| `Storage(USBDrive(n))` | `"Storage"` | `"USBDrive"` | `"capacity": n` |
| `Storage(SDCard(n))` | `"Storage"` | `"SDCard"` | `"capacity": n` |
| `Consumable(CableTie)` | `"Consumable"` | `"CableTie"` | — |
| `Consumable(ElectricalTape)` | `"Consumable"` | `"ElectricalTape"` | — |
| `Consumable(SpliceProtector)` | `"Consumable"` | `"SpliceProtector"` | — |
| `Consumable(HeatShrink)` | `"Consumable"` | `"HeatShrink"` | — |
| `Keycard(level)` | `"Keycard"` | — | `"level": level` |
| `Radio` | `"Radio"` | — | — |

## Field-by-Field Mapping

The UMS JSON and the game's `LevelConfig.levelConfig` record use **identical
field names**.  No renaming or transformation is needed.

| JSON Key | Game Type | ReScript Type | Default on Missing |
|---|---|---|---|
| `locationId` | `levelConfig.locationId` | `string` | **required** |
| `missionId` | `levelConfig.missionId` | `string` | **required** |
| `worldItems` | `levelConfig.worldItems` | `array<worldItem>` | `[]` |
| `guardPlacements` | `levelConfig.guardPlacements` | `array<guardPlacement>` | `[]` |
| `deviceDefences` | `levelConfig.deviceDefences` | `array<deviceDefenceConfig>` | `[]` |
| `hasPowerSystem` | `levelConfig.hasPowerSystem` | `bool` | `false` |
| `hasSecurityCameras` | `levelConfig.hasSecurityCameras` | `bool` | `false` |
| `numberOfCovertLinks` | `levelConfig.numberOfCovertLinks` | `int` | `0` |
| `hasPBX` | `levelConfig.hasPBX` | `bool` | `false` |
| `pbxIpAddress` | `levelConfig.pbxIpAddress` | `string` | `""` |
| `pbxWorldX` | `levelConfig.pbxWorldX` | `float` | `0.0` |
| `zoneTransitions` | `levelConfig.zoneTransitions` | `array<zoneTransition>` | `[]` |

### Defence Flags Sub-Object

| JSON Key | ReScript Field | Type | Default |
|---|---|---|---|
| `tamperProof` | `defenceFlags.tamperProof` | `bool` | `false` |
| `decoy` | `defenceFlags.decoy` | `bool` | `false` |
| `canary` | `defenceFlags.canary` | `bool` | `false` |
| `oneWayMirror` | `defenceFlags.oneWayMirror` | `bool` | `false` |
| `killSwitch` | `defenceFlags.killSwitch` | `bool` | `false` |
| `failoverTarget` | `defenceFlags.failoverTarget` | `option<string>` | `None` |
| `cascadeTrap` | `defenceFlags.cascadeTrap` | `option<string>` | `None` |
| `instructionWhitelist` | `defenceFlags.instructionWhitelist` | `option<array<string>>` | `None` |
| `timeBomb` | `defenceFlags.timeBomb` | `option<int>` | `None` |
| `mirrorTarget` | `defenceFlags.mirrorTarget` | `option<string>` | `None` |
| `undoImmunity` | `defenceFlags.undoImmunity` | `option<int>` | `None` |

## How to Load UMS Levels in the Game

### From a JSON string (e.g. received via IPC)

```rescript
// In GameLoop or a level selection screen:
let jsonFromUms = /* received from UMS via IPC, clipboard, etc. */
switch UmsLevelLoader.loadFromJson(jsonFromUms) {
| Some(config) => startMission(config)
| None => showError("Invalid level data")
}
```

### From a file (Tauri desktop/mobile)

```rescript
// Loading a .json file exported by the UMS level editor:
let _ = UmsLevelLoader.loadFromFile("levels/gen_office_42.json")
  ->Promise.then(result => {
    switch result {
    | Some(config) => startMission(config)->Promise.resolve
    | None => {
        showError("Could not load level file")
        Promise.resolve()
      }
    }
  })
```

### Fallback to hardcoded levels

The game's existing `LevelConfig.getConfig(locationId)` remains the primary
source for campaign levels.  UMS-loaded levels are an **additive** path:

```rescript
// Try UMS first, fall back to hardcoded
let getLevel = (locationId, umsJson) => {
  switch umsJson {
  | Some(json) => UmsLevelLoader.loadFromJson(json)
  | None => LevelConfig.getConfig(locationId)
  }
}
```

## Error Handling

- `loadFromJson` returns `None` on any failure (malformed JSON, missing required
  fields, type mismatches).  It never throws.
- `loadFromFile` returns a promise resolving to `None` if the file cannot be
  read or the contents cannot be decoded.
- `loadFromFileWithError` returns `result<levelConfig, string>` for cases where
  the caller wants to display a specific error message.
- Individual array elements (worldItems, guards, etc.) that fail to decode are
  silently dropped via `Array.filterMap`.  A level with one malformed guard
  placement will still load; only that guard is omitted.

## Notes

- The `collected` field on worldItems is always set to `false` on load,
  regardless of what the JSON says.  Levels start fresh.
- The UMS currently exports `worldItems: []` (empty) because item placement
  is done by a separate post-processing step.  The loader handles this
  gracefully; the game will simply have no world items to pick up.
- Zone transition coordinates from UMS use pixel positions calculated from
  `LevelGen.slotWidth`.  The game renders these as-is.
