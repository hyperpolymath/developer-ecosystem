// SPDX-License-Identifier: PMPL-1.0-or-later
// UmsLevelLoader  Bridge between UMS-exported JSON and the game's LevelConfig
//
// The IDApTIK UMS (Universal Mission System) exports level definitions as JSON
// using LevelConfigCodec.  This module parses that JSON on the game side and
// produces a native LevelConfig.levelConfig value that GameLoop can consume.
//
// Design constraints:
//   - No unsafe operations: getExn, Obj.magic, etc. are banned.
//   - Parse failures return None — never crash.
//   - Field names in the UMS JSON match the game format 1:1 (both sides share
//     the same codec spec), so no field renaming is needed.
//   - The module is self-contained: it re-implements just enough JSON decoding
//     to avoid a build-time dependency on the idaptik-ums package.
//
// See also: idaptik-ums/docs/design/GAME-INTEGRATION.md

open Inventory

// ─────────────────────────────────────────────────────────────────────────────
//  JSON Helpers
//
// Minimal safe extraction functions for JSON values.  Every function returns
// option so callers can short-circuit on missing/mistyped data.
// ─────────────────────────────────────────────────────────────────────────────

// Extract a string value from a JSON object dict by key.
// Returns None if the key is missing or the value is not a string.
let getString = (dict: Dict.t<JSON.t>, key: string): option<string> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | String(s) => Some(s)
    | _ => None
    }
  | None => None
  }
}

// Extract a float value from a JSON object dict by key.
// Returns None if the key is missing or the value is not a number.
let getFloat = (dict: Dict.t<JSON.t>, key: string): option<float> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | Number(n) => Some(n)
    | _ => None
    }
  | None => None
  }
}

// Extract an integer value from a JSON object dict by key.
// Truncates the float via bitwise OR (standard JS int coercion).
// Returns None if the key is missing or the value is not a number.
let getInt = (dict: Dict.t<JSON.t>, key: string): option<int> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | Number(n) => Some(Float.toInt(n))
    | _ => None
    }
  | None => None
  }
}

// Extract a boolean value from a JSON object dict by key.
// Returns None if the key is missing or the value is not a boolean.
let getBool = (dict: Dict.t<JSON.t>, key: string): option<bool> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | Bool(b) => Some(b)
    | _ => None
    }
  | None => None
  }
}

// Extract a JSON array from a dict by key.
// Returns None if the key is missing or the value is not an array.
let getArray = (dict: Dict.t<JSON.t>, key: string): option<array<JSON.t>> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | Array(arr) => Some(arr)
    | _ => None
    }
  | None => None
  }
}

// Classify a JSON value as an Object dict, or None.
let asObject = (json: JSON.t): option<Dict.t<JSON.t>> => {
  switch JSON.Classify.classify(json) {
  | Object(d) => Some(d)
  | _ => None
  }
}

// Extract an optional string (returns None for missing, null, or empty "").
let getOptionalString = (dict: Dict.t<JSON.t>, key: string): option<string> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | String(s) if s != "" => Some(s)
    | _ => None
    }
  | None => None
  }
}

// Extract an optional int (returns None for missing or null).
let getOptionalInt = (dict: Dict.t<JSON.t>, key: string): option<int> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | Number(n) => Some(Float.toInt(n))
    | _ => None
    }
  | None => None
  }
}

// Extract an optional array of strings (returns None for missing or null).
let getOptionalStringArray = (
  dict: Dict.t<JSON.t>,
  key: string,
): option<array<string>> => {
  switch dict->Dict.get(key) {
  | Some(json) =>
    switch JSON.Classify.classify(json) {
    | Array(arr) =>
      Some(
        arr->Array.filterMap(j => {
          switch JSON.Classify.classify(j) {
          | String(s) => Some(s)
          | _ => None
          }
        }),
      )
    | _ => None
    }
  | None => None
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Item Kind Decoder
//
// Reconstructs Inventory.itemKind from the UMS JSON encoding.
// The UMS codec uses { "type": "Cable", "subtype": "Ethernet" } etc.
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON object into an Inventory.itemKind variant.
// Returns None if the type/subtype combination is unrecognised.
let decodeItemKind = (json: JSON.t): option<Inventory.itemKind> => {
  switch asObject(json) {
  | None => None
  | Some(dict) =>
    switch getString(dict, "type") {
    | None => None
    | Some("Cable") =>
      switch getString(dict, "subtype") {
      | Some("Ethernet") => Some(Cable(Ethernet))
      | Some("FibreLC") => Some(Cable(FibreLC))
      | Some("FibreSC") => Some(Cable(FibreSC))
      | Some("Serial") => Some(Cable(Serial))
      | Some("USB") => Some(Cable(USB))
      | Some("Universal") => Some(Cable(Universal))
      | _ => None
      }
    | Some("Adapter") =>
      switch getString(dict, "subtype") {
      | Some("USBToSerial") => Some(Adapter(USBToSerial))
      | Some("MediaConverter") => Some(Adapter(MediaConverter))
      | Some("GenderChanger") => Some(Adapter(GenderChanger))
      | Some("RJ45toRJ11") => Some(Adapter(RJ45toRJ11))
      | _ => None
      }
    | Some("Tool") =>
      switch getString(dict, "subtype") {
      | Some("Crimper") => Some(Tool(Crimper))
      | Some("FibreCleaver") => Some(Tool(FibreCleaver))
      | Some("FibreSplicer") => Some(Tool(FibreSplicer))
      | Some("OTDR") => Some(Tool(OTDR))
      | Some("WireCutters") => Some(Tool(WireCutters))
      | Some("Multimeter") => Some(Tool(Multimeter))
      | _ => None
      }
    | Some("Module") =>
      switch getString(dict, "subtype") {
      | Some("SFP1G") => Some(Module(SFP1G))
      | Some("SFP10G") => Some(Module(SFP10G))
      | Some("GBIC") => Some(Module(GBIC))
      | Some("RJ45Transceiver") => Some(Module(RJ45Transceiver))
      | _ => None
      }
    | Some("Storage") =>
      switch (getString(dict, "subtype"), getInt(dict, "capacity")) {
      | (Some("USBDrive"), Some(cap)) => Some(Storage(USBDrive(cap)))
      | (Some("SDCard"), Some(cap)) => Some(Storage(SDCard(cap)))
      | _ => None
      }
    | Some("Consumable") =>
      switch getString(dict, "subtype") {
      | Some("CableTie") => Some(Consumable(CableTie))
      | Some("ElectricalTape") => Some(Consumable(ElectricalTape))
      | Some("SpliceProtector") => Some(Consumable(SpliceProtector))
      | Some("HeatShrink") => Some(Consumable(HeatShrink))
      | _ => None
      }
    | Some("Keycard") =>
      switch getString(dict, "level") {
      | Some(level) => Some(Keycard(level))
      | None => None
      }
    | Some("Radio") => Some(Radio)
    | _ => None
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Condition Decoder
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON string into an Inventory.itemCondition variant.
// Returns None if the string is not a recognised condition.
let decodeCondition = (json: JSON.t): option<Inventory.itemCondition> => {
  switch JSON.Classify.classify(json) {
  | String("Pristine") => Some(Pristine)
  | String("Good") => Some(Good)
  | String("Worn") => Some(Worn)
  | String("Damaged") => Some(Damaged)
  | String("Broken") => Some(Broken)
  | _ => None
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Item Decoder
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON object into an Inventory.item record.
// Required fields: id, name, kind.  Everything else has safe defaults.
let decodeItem = (json: JSON.t): option<Inventory.item> => {
  switch asObject(json) {
  | None => None
  | Some(dict) =>
    switch (getString(dict, "id"), getString(dict, "name")) {
    | (Some(id), Some(name)) =>
      // kind is required — bail if missing or unrecognised
      switch dict->Dict.get("kind") {
      | None => None
      | Some(kindJson) =>
        switch decodeItemKind(kindJson) {
        | None => None
        | Some(kind) =>
          let condition = switch dict->Dict.get("condition") {
          | Some(condJson) => decodeCondition(condJson)->Option.getOr(Good)
          | None => Good
          }
          let cableLength = switch getFloat(dict, "cableLength") {
          | Some(0.0) => None
          | other => other
          }
          Some({
            id,
            kind,
            name,
            weight: getFloat(dict, "weight")->Option.getOr(0.0),
            condition,
            usesRemaining: getOptionalInt(dict, "usesRemaining"),
            cableLength,
            description: getString(dict, "description")->Option.getOr(""),
          })
        }
      }
    | _ => None
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  World Item Decoder
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON object into a LevelConfig.worldItem record.
// The item sub-object is required; position and container have defaults.
// The `collected` field is always initialised to false (fresh level load).
let decodeWorldItem = (json: JSON.t): option<LevelConfig.worldItem> => {
  switch asObject(json) {
  | None => None
  | Some(dict) =>
    switch dict->Dict.get("item") {
    | None => None
    | Some(itemJson) =>
      switch decodeItem(itemJson) {
      | None => None
      | Some(item) =>
        Some({
          item,
          x: getFloat(dict, "x")->Option.getOr(0.0),
          container: getString(dict, "container")->Option.getOr("supply_room"),
          collected: false,
        })
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Guard Placement Decoder
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON object into a LevelConfig.guardPlacement record.
// All three of x, zone, and rank are required.
let decodeGuardPlacement = (json: JSON.t): option<LevelConfig.guardPlacement> => {
  switch asObject(json) {
  | None => None
  | Some(dict) =>
    switch (getFloat(dict, "x"), getString(dict, "zone"), getString(dict, "rank")) {
    | (Some(x), Some(zone), Some(rank)) =>
      Some({
        x,
        zone,
        rank,
        patrolRadius: getFloat(dict, "patrolRadius")->Option.getOr(200.0),
      })
    | _ => None
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Defence Flags Decoder
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON object into a DeviceType.defenceFlags record.
// Missing boolean fields default to false; missing option fields default to None.
let decodeDefenceFlags = (json: JSON.t): DeviceType.defenceFlags => {
  switch asObject(json) {
  | None => DeviceType.defaultDefenceFlags
  | Some(dict) => {
      tamperProof: getBool(dict, "tamperProof")->Option.getOr(false),
      decoy: getBool(dict, "decoy")->Option.getOr(false),
      canary: getBool(dict, "canary")->Option.getOr(false),
      oneWayMirror: getBool(dict, "oneWayMirror")->Option.getOr(false),
      killSwitch: getBool(dict, "killSwitch")->Option.getOr(false),
      failoverTarget: getOptionalString(dict, "failoverTarget"),
      cascadeTrap: getOptionalString(dict, "cascadeTrap"),
      instructionWhitelist: getOptionalStringArray(dict, "instructionWhitelist"),
      timeBomb: getOptionalInt(dict, "timeBomb"),
      mirrorTarget: getOptionalString(dict, "mirrorTarget"),
      undoImmunity: getOptionalInt(dict, "undoImmunity"),
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Device Defence Config Decoder
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON object into a LevelConfig.deviceDefenceConfig record.
// ipAddress is required; flags fall back to defaultDefenceFlags.
let decodeDeviceDefenceConfig = (
  json: JSON.t,
): option<LevelConfig.deviceDefenceConfig> => {
  switch asObject(json) {
  | None => None
  | Some(dict) =>
    switch getString(dict, "ipAddress") {
    | None => None
    | Some(ipAddress) =>
      let flags = switch dict->Dict.get("flags") {
      | Some(flagsJson) => decodeDefenceFlags(flagsJson)
      | None => DeviceType.defaultDefenceFlags
      }
      Some({ipAddress, flags})
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Zone Transition Decoder
// ─────────────────────────────────────────────────────────────────────────────

// Decode a JSON object into a LevelConfig.zoneTransition record.
// All three fields (x, fromZone, toZone) are required.
let decodeZoneTransition = (json: JSON.t): option<LevelConfig.zoneTransition> => {
  switch asObject(json) {
  | None => None
  | Some(dict) =>
    switch (getFloat(dict, "x"), getString(dict, "fromZone"), getString(dict, "toZone")) {
    | (Some(x), Some(fromZone), Some(toZone)) => Some({x, fromZone, toZone})
    | _ => None
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top-Level Decode
// ─────────────────────────────────────────────────────────────────────────────

// Decode a parsed JSON value into a LevelConfig.levelConfig.
// Returns None if the JSON is not a valid level config object.
// Individual array elements that fail to decode are silently dropped
// (filterMap) so one bad worldItem does not invalidate the whole level.
let decodeConfig = (json: JSON.t): option<LevelConfig.levelConfig> => {
  switch asObject(json) {
  | None => None
  | Some(dict) =>
    switch (getString(dict, "locationId"), getString(dict, "missionId")) {
    | (Some(locationId), Some(missionId)) =>
      let worldItems =
        getArray(dict, "worldItems")
        ->Option.getOr([])
        ->Array.filterMap(decodeWorldItem)
      let guardPlacements =
        getArray(dict, "guardPlacements")
        ->Option.getOr([])
        ->Array.filterMap(decodeGuardPlacement)
      let deviceDefences =
        getArray(dict, "deviceDefences")
        ->Option.getOr([])
        ->Array.filterMap(decodeDeviceDefenceConfig)
      let zoneTransitions =
        getArray(dict, "zoneTransitions")
        ->Option.getOr([])
        ->Array.filterMap(decodeZoneTransition)
      Some({
        locationId,
        missionId,
        worldItems,
        guardPlacements,
        deviceDefences,
        hasPowerSystem: getBool(dict, "hasPowerSystem")->Option.getOr(false),
        hasSecurityCameras: getBool(dict, "hasSecurityCameras")->Option.getOr(false),
        numberOfCovertLinks: getInt(dict, "numberOfCovertLinks")->Option.getOr(0),
        hasPBX: getBool(dict, "hasPBX")->Option.getOr(false),
        pbxIpAddress: getString(dict, "pbxIpAddress")->Option.getOr(""),
        pbxWorldX: getFloat(dict, "pbxWorldX")->Option.getOr(0.0),
        zoneTransitions,
      })
    | _ => None
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Public API
// ─────────────────────────────────────────────────────────────────────────────

// Parse a UMS-exported JSON string into the game's LevelConfig.levelConfig.
//
// Returns Some(config) on success, None on any parse or decode failure.
// This is the primary entry point for loading UMS levels in the game client.
//
// Example:
//   let json = `{"locationId":"gen_office_42","missionId":"gen_mission_1",...}`
//   switch UmsLevelLoader.loadFromJson(json) {
//   | Some(config) => GameLoop.startMission(config)
//   | None => Console.error("Failed to load UMS level")
//   }
let loadFromJson = (jsonString: string): option<LevelConfig.levelConfig> => {
  try {
    let json = JSON.parseExn(jsonString)
    decodeConfig(json)
  } catch {
  | _ => None
  }
}

// Load a UMS-exported level from a file path (for Tauri integration).
//
// Uses the Tauri fs API to read the file, then parses the contents.
// Returns a promise resolving to Some(config) on success, None on failure.
//
// The @module binding targets @tauri-apps/plugin-fs which provides readTextFile.
// If running outside Tauri (e.g. in a browser test), this will reject and
// the catch handler returns None.
//
// Example (in an async context):
//   let config = await UmsLevelLoader.loadFromFile("levels/gen_office_42.json")
//   switch config {
//   | Some(c) => GameLoop.startMission(c)
//   | None => Console.error("Could not load level file")
//   }
@module("@tauri-apps/plugin-fs")
external readTextFile: string => promise<string> = "readTextFile"

let loadFromFile = (path: string): promise<option<LevelConfig.levelConfig>> => {
  readTextFile(path)
  ->Promise.then(contents => {
    Promise.resolve(loadFromJson(contents))
  })
  ->Promise.catch(_ => {
    Promise.resolve(None)
  })
}

// Load a UMS-exported level from a file, with an error message on failure.
//
// Like loadFromFile but returns result<levelConfig, string> for better
// error reporting in the level editor and debug UI.
let loadFromFileWithError = (
  path: string,
): promise<result<LevelConfig.levelConfig, string>> => {
  readTextFile(path)
  ->Promise.then(contents => {
    switch loadFromJson(contents) {
    | Some(config) => Promise.resolve(Ok(config))
    | None => Promise.resolve(Error("Failed to decode level JSON from " ++ path))
    }
  })
  ->Promise.catch(_ => {
    Promise.resolve(Error("Failed to read file: " ++ path))
  })
}
