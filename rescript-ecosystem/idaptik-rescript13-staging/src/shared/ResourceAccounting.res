// SPDX-License-Identifier: PMPL-1.0-or-later
// ResourceAccounting.res  Per-device resource tracking for the coprocessor kernel.
//
// Tracks compute units, memory (peak), and energy (cumulative) consumed by each
// game device running coprocessor operations. Resource state is mutable and
// persists for the lifetime of the game session — resets are explicit.
//
// Naming note: the `quota` record type reuses field names `maxCompute`,
// `maxMemory`, `maxEnergy` for BOTH capacity limits (in `available`) and
// running totals (in `used`). When a `quota` is in the `available` field the
// values are the per-session upper limits. When in the `used` field they are
// cumulative consumed amounts. Field names are intentionally kept identical to
// preserve backward compatibility with all downstream references.
//
// Memory tracking semantics: memory uses PEAK rather than cumulative totals.
// We care about the largest single-operation allocation, not the running sum,
// because the game's memory pressure model is based on "can the device hold
// this buffer?" not "how many bytes has it ever touched?"

open Coprocessor

// --- Types ---

// Resource capacity or usage record.
// Context-dependent: `available` = limits, `used` = running totals.
type quota = {
  mutable maxCompute: int,   // Compute units (CPU/GPU cycle equivalents)
  mutable maxMemory: int,    // Memory bytes (peak usage, not cumulative)
  mutable maxEnergy: float,  // Energy in Joules (cumulative drain)
}

// Full resource state for a single device the player has hacked into.
// Lazily created on first access; persists until `resetDevice` is called.
type deviceResourceState = {
  id: string,
  mutable available: quota,  // Capacity limits for this device class
  mutable used: quota,       // Current consumption (compute/energy cumulative, memory peak)
  mutable activeCalls: int,  // Number of concurrently-executing coprocessor ops
}

// --- Global State ---

// Registry of all known device resource states, keyed by device ID.
// Populated lazily via `getDeviceState`; never shrinks during a session.
let deviceStates: dict<deviceResourceState> = Dict.make()

// Default quotas assigned to newly-registered devices.
// Specialised devices (servers, quantum nodes) receive higher limits via
// `setQuota`. IoT devices / cameras may receive lower limits.
let defaultQuota: quota = {
  maxCompute: 10000,
  maxMemory: 1024 * 1024,  // 1 MB peak allocation
  maxEnergy: 100.0,        // 100 Joules per session
}

// --- Device Registration & Reset ---

// Retrieve (or lazily create) the resource state for a device.
// All coprocessor paths call this before touching device accounting.
let getDeviceState = (deviceId: string): deviceResourceState => {
  switch Dict.get(deviceStates, deviceId) {
  | Some(s) => s
  | None => {
      let s = {
        id: deviceId,
        available: {
          maxCompute: defaultQuota.maxCompute,
          maxMemory: defaultQuota.maxMemory,
          maxEnergy: defaultQuota.maxEnergy,
        },
        used: {maxCompute: 0, maxMemory: 0, maxEnergy: 0.0},
        activeCalls: 0,
      }
      Dict.set(deviceStates, deviceId, s)
      s
    }
  }
}

// Reset a device's usage counters to zero without changing its capacity quota.
// Call when the player disconnects from a device, the device reboots, or a
// puzzle resets. Active call count is also zeroed (any in-flight ops are orphaned).
let resetDevice = (deviceId: string): unit => {
  let s = getDeviceState(deviceId)
  s.used.maxCompute = 0
  s.used.maxMemory = 0
  s.used.maxEnergy = 0.0
  s.activeCalls = 0
}

// Set a custom resource quota for a device.
// Servers get higher limits; cameras/IoT nodes get lower limits.
// Call after `getDeviceState` (or it will be lazily created with defaults first).
let setQuota = (
  deviceId: string,
  ~maxCompute: int,
  ~maxMemory: int,
  ~maxEnergy: float,
): unit => {
  let s = getDeviceState(deviceId)
  s.available.maxCompute = maxCompute
  s.available.maxMemory = maxMemory
  s.available.maxEnergy = maxEnergy
}

// --- Quota Checking ---

// Check whether an operation with the given metrics can run without exceeding quota.
// Called BEFORE dispatching an operation so exhausted devices fail fast.
//
// Memory uses peak semantics: the new operation's peak allocation must fit within
// the device's total memory limit (regardless of current peak).
// Compute and energy are cumulative: they add to running totals.
let checkQuota = (state: deviceResourceState, metrics: resourceMetrics): bool => {
  let computeOk = state.used.maxCompute + metrics.computeUnits <= state.available.maxCompute
  let memOk = metrics.memoryBytes <= state.available.maxMemory
  let energyOk = state.used.maxEnergy +. metrics.energyJoules <= state.available.maxEnergy
  computeOk && memOk && energyOk
}

// Fast-path capacity check used before we know exact operation metrics.
// Returns false if ANY resource has reached 95% utilisation, signalling that
// the device is effectively saturated and new operations should be rejected.
//
// This is a conservative early-out; the detailed `checkQuota` is used once
// actual operation metrics are known.
let hasCapacity = (state: deviceResourceState): bool => {
  let safeRatioI = (used: int, avail: int): float =>
    if avail <= 0 {1.0} else {Float.fromInt(used) /. Float.fromInt(avail)}
  let safeRatioF = (used: float, avail: float): float =>
    if avail <= 0.0 {1.0} else {used /. avail}
  let computeRatio = safeRatioI(state.used.maxCompute, state.available.maxCompute)
  let energyRatio = safeRatioF(state.used.maxEnergy, state.available.maxEnergy)
  computeRatio < 0.95 && energyRatio < 0.95
}

// --- HUD Support ---

// Per-resource utilisation expressed as 0.0–100.0 percentages.
// Consumed by KernelMonitor.res to render the resource bars.
type usagePercentage = {
  compute: float,  // Cumulative compute units used vs capacity
  memory: float,   // Peak memory bytes used vs capacity
  energy: float,   // Cumulative Joules drained vs capacity
}

// Return current resource utilisation as percentages for the KernelMonitor HUD.
// Safe against zero-capacity devices: returns 0.0 instead of NaN/infinity.
let getUsagePercentage = (deviceId: string): usagePercentage => {
  let s = getDeviceState(deviceId)
  let pctI = (used: int, avail: int): float =>
    if avail <= 0 {0.0} else {Float.fromInt(used) /. Float.fromInt(avail) *. 100.0}
  let pctF = (used: float, avail: float): float =>
    if avail <= 0.0 {0.0} else {used /. avail *. 100.0}
  {
    compute: pctI(s.used.maxCompute, s.available.maxCompute),
    memory: pctI(s.used.maxMemory, s.available.maxMemory),
    energy: pctF(s.used.maxEnergy, s.available.maxEnergy),
  }
}
