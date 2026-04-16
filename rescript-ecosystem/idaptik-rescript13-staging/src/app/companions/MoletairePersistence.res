// SPDX-License-Identifier: PMPL-1.0-or-later
// MoletairePersistence  localStorage-based save/load for Moletaire
//
// Persists:
//   - Unlock state (player has discovered/obtained Moletaire)
//   - Alive state (permadeath  once dead, stays dead)
//   - Equipment loadout (head + body slot)
//   - Deployed locations (set of location IDs where Frogger minigame completed)
//
// All keys prefixed "moletaire-" to namespace in localStorage.
// Pattern mirrors FeaturePacks.res (cached refs + localStorage).

//  LocalStorage Keys 

let keyUnlocked = "moletaire-unlocked"
let keyAlive = "moletaire-alive"
let keyEquipmentHead = "moletaire-equipment-head"
let keyEquipmentBody = "moletaire-equipment-body"
let keyDeployedLocations = "moletaire-deployed-locations"

//  Head Equipment Serialisation 

let headToString = (head: Moletaire.headEquipment): string => {
  switch head {
  | Flash => "flash"
  | BatteringRam => "battering-ram"
  | Camera => "camera"
  | Miniglider => "miniglider"
  }
}

let headFromString = (str: string): option<Moletaire.headEquipment> => {
  switch str {
  | "flash" => Some(Flash)
  | "battering-ram" => Some(BatteringRam)
  | "camera" => Some(Camera)
  | "miniglider" => Some(Miniglider)
  | _ => None
  }
}

//  Body Equipment Serialisation 

let bodyToString = (body: Moletaire.bodyEquipment): string => {
  switch body {
  | Skateboard => "skateboard"
  | Rucksack => "rucksack"
  | NoBody => "none"
  }
}

let bodyFromString = (str: string): Moletaire.bodyEquipment => {
  switch str {
  | "skateboard" => Skateboard
  | "rucksack" => Rucksack
  | _ => NoBody
  }
}

//  Core Queries 

// Has the player unlocked Moletaire as a companion?
let isUnlocked = (): bool => {
  Storage.getBool(keyUnlocked)->Option.getOr(false)
}

// Is Moletaire currently alive? (permadeath: once false, stays false)
let isAlive = (): bool => {
  Storage.getBool(keyAlive)->Option.getOr(true) // Default alive if never set
}

//  State Mutation 

// Mark Moletaire as unlocked (first discovery)
let unlock = (): unit => {
  Storage.setBool(keyUnlocked, true)
  // Newly unlocked mole starts alive
  Storage.setBool(keyAlive, true)
}

// Mark Moletaire as dead (permadeath  irreversible in normal play)
let markDead = (): unit => {
  Storage.setBool(keyAlive, false)
}

// Reset Moletaire to alive (used in training mode only)
let resetAlive = (): unit => {
  Storage.setBool(keyAlive, true)
}

//  Equipment 

// Get the currently equipped head equipment
let getHeadEquipment = (): option<Moletaire.headEquipment> => {
  switch Storage.getString(keyEquipmentHead) {
  | Some(str) => headFromString(str)
  | None => None
  }
}

// Get the currently equipped body equipment
let getBodyEquipment = (): Moletaire.bodyEquipment => {
  switch Storage.getString(keyEquipmentBody) {
  | Some(str) => bodyFromString(str)
  | None => NoBody
  }
}

// Get the full equipment loadout
let getEquipment = (): Moletaire.equipmentLoadout => {
  {
    head: getHeadEquipment(),
    body: getBodyEquipment(),
  }
}

// Set head equipment
let setHeadEquipment = (head: option<Moletaire.headEquipment>): unit => {
  switch head {
  | Some(h) => Storage.setString(keyEquipmentHead, headToString(h))
  | None => Storage.setString(keyEquipmentHead, "none")
  }
}

// Set body equipment
let setBodyEquipment = (body: Moletaire.bodyEquipment): unit => {
  Storage.setString(keyEquipmentBody, bodyToString(body))
}

// Set full equipment loadout
let setEquipment = (loadout: Moletaire.equipmentLoadout): unit => {
  setHeadEquipment(loadout.head)
  setBodyEquipment(loadout.body)
}

//  Deployed Locations 
//
// Tracks which locations have had the Frogger minigame completed.
// Stored as comma-separated location IDs.

// Parse deployed locations from comma-separated string
let getDeployedLocations = (): array<string> => {
  switch Storage.getString(keyDeployedLocations) {
  | Some(str) if str != "" => String.split(str, ",")
  | _ => []
  }
}

// Check if Moletaire has been deployed to a specific location
let isDeployedAt = (locationId: string): bool => {
  getDeployedLocations()->Array.some(id => id == locationId)
}

// Mark a location as deployed (Frogger minigame completed)
let markDeployed = (locationId: string): unit => {
  if !isDeployedAt(locationId) {
    let current = getDeployedLocations()
    let updated = Array.concat(current, [locationId])
    Storage.setString(keyDeployedLocations, Array.join(updated, ","))
  }
}

//  Initialization 
//
// Call on game boot to ensure localStorage state is consistent.
// Does NOT overwrite existing state  only sets defaults if absent.

let init = (): unit => {
  // If never set, default to locked and alive
  if Storage.getString(keyUnlocked) == None {
    Storage.setBool(keyUnlocked, false)
  }
  if Storage.getString(keyAlive) == None {
    Storage.setBool(keyAlive, true)
  }
}
