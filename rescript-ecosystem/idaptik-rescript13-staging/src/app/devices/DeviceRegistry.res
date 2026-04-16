// SPDX-License-Identifier: PMPL-1.0-or-later
// DeviceRegistry  Singleton IP-to-device map + defence flags for the active network
//
// Two backing stores, both keyed by IP address:
//   registry        ipAddress → device instance
//   defenceRegistry ipAddress → defenceFlags (ADR-0013)
//
// Devices are registered on creation (via DeviceFactory / NetworkManager)
// and looked up by NetworkManager, SSH handlers, and the covert-link system.
//
// Defence flags are applied by NetworkManager.applyLevelDefences when a
// mission starts and are cleared (reset to defaultDefenceFlags) on level
// unload via `clear()`.  Any game code — including device modules that
// lack a reference to gameState — can call `getDefenceFlags(ipAddress)`
// to read the active flags for a device.
//
// Design notes:
//   - Intentionally flat and simple: no per-zone indices or type sets.
//     Callers that need filtered views (e.g. "all cameras") iterate the
//     full dict — the number of devices in a level (<50) makes this fine.
//   - The registry is reset when a level unloads (see `clear`).
//   - Device info (name, type, securityLevel) is fetched lazily via
//     device.getInfo() rather than stored redundantly here.
//   - All mutation is single-threaded (no concurrent write hazard in Deno).

// The singleton backing store: ipAddress -> device
let registry: dict<DeviceTypes.device> = Dict.make()

// Defence flags backing store: ipAddress -> defenceFlags (ADR-0013).
// Populated by NetworkManager.applyLevelDefences; cleared on level unload.
let defenceRegistry: dict<DeviceType.defenceFlags> = Dict.make()

// Register a device under its IP address.
// If a device is already registered at this IP it will be overwritten —
// this is intentional for hot-reload during development.
let register = (ipAddress: string, device: DeviceTypes.device): unit => {
  Dict.set(registry, ipAddress, device)
}

// Look up a device by IP address. Returns None if not registered.
let lookup = (ipAddress: string): option<DeviceTypes.device> => {
  Dict.get(registry, ipAddress)
}

// Look up a device and call f with it. Returns None if not registered.
let withDevice = (
  ipAddress: string,
  f: DeviceTypes.device => 'a,
): option<'a> => {
  switch Dict.get(registry, ipAddress) {
  | Some(device) => Some(f(device))
  | None => None
  }
}

// Unregister a device by IP address. No-op if not registered.
let unregister = (ipAddress: string): unit => {
  // In practice, callers use `clear()` between levels rather than
  // individual unregister calls.  Level transitions are the correct
  // lifecycle boundary for bulk removal.
  Dict.delete(registry, ipAddress)
  Dict.delete(defenceRegistry, ipAddress)
}

// Return all registered IP addresses.
let allIps = (): array<string> => {
  Dict.keysToArray(registry)
}

// Return all registered devices as (ipAddress, device) pairs.
let allEntries = (): array<(string, DeviceTypes.device)> => {
  Dict.toArray(registry)
}

// Return all devices whose deviceType matches the given type.
let byType = (targetType: DeviceTypes.deviceType): array<DeviceTypes.device> => {
  Dict.valuesToArray(registry)->Array.filter(device => {
    let info = device.getInfo()
    info.deviceType == targetType
  })
}

// Return all devices at or above the given security level.
// Useful for the SecurityAI to find high-value targets.
let byMinSecurityLevel = (
  minLevel: DeviceType.securityLevel,
): array<DeviceTypes.device> => {
  // Ordered: Open < Weak < Medium < Strong
  let rank = level =>
    switch level {
    | DeviceType.Open => 0
    | DeviceType.Weak => 1
    | DeviceType.Medium => 2
    | DeviceType.Strong => 3
    }
  Dict.valuesToArray(registry)->Array.filter(device => {
    let info = device.getInfo()
    rank((info.securityLevel :> DeviceType.securityLevel)) >= rank(minLevel)
  })
}

// Return the number of currently registered devices.
let count = (): int => {
  Dict.keysToArray(registry)->Array.length
}

// --- Defence flags (ADR-0013) ---
//
// setDefenceFlags / getDefenceFlags are called by NetworkManager.applyLevelDefences
// when a mission starts.  Game systems (canary monitors, timeBomb tickers,
// VM kernel handlers) call getDefenceFlags to read the active flags without
// needing a reference to gameState.

// Store defence flags for a device.
// Overwrites any previously stored flags for the same IP (safe — missions
// always reset flags before the level starts).
let setDefenceFlags = (ipAddress: string, flags: DeviceType.defenceFlags): unit => {
  Dict.set(defenceRegistry, ipAddress, flags)
}

// Read defence flags for a device.
// Returns DeviceType.defaultDefenceFlags (all inactive) if no override
// has been registered for this IP — i.e. the device has stock behaviour.
let getDefenceFlags = (ipAddress: string): DeviceType.defenceFlags => {
  Dict.get(defenceRegistry, ipAddress)->Option.getOr(DeviceType.defaultDefenceFlags)
}

// Remove all registered devices and defence flag overrides.
// Called on level unload / game reset to prevent stale state leaking
// between missions.
let clear = (): unit => {
  // Delete all device entries
  let deviceKeys = Dict.keysToArray(registry)
  Array.forEach(deviceKeys, k => Dict.delete(registry, k))
  // Delete all defence flag overrides
  let defenceKeys = Dict.keysToArray(defenceRegistry)
  Array.forEach(defenceKeys, k => Dict.delete(defenceRegistry, k))
}
