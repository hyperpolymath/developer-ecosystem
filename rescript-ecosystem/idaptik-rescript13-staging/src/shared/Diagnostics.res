// SPDX-License-Identifier: PMPL-1.0-or-later
// Diagnostics.res  Comprehensive self-diagnostic reporting for the coprocessor subsystem.
//
// Aggregates per-device resource usage and per-backend health statistics into
// structured reports consumed by:
//   - The in-game `diagnose` / `sysinfo` terminal commands
//   - The KernelMonitor HUD real-time resource bars
//   - Test assertions about post-run resource state
//   - Developer debugging when unexpected failures occur
//
// Relationship to other modules
// ──────────────────────────────
//   ResourceAccounting  — provides raw usage numbers (compute, memory, energy)
//   Kernel.getDeviceReport — produces a human-readable per-device summary string
//   Coprocessor         — provides the global backend registry + per-backend stats
//   Diagnostics         — wraps both into richer typed structures and helper queries
//
// Health levels
// ─────────────
//   Healthy   < 70 % utilisation  — device is operating normally
//   Warning   70–89 %             — approaching capacity; plan ahead
//   Critical  ≥ 90 %              — near-exhaustion; new ops are likely to be
//                                   rejected with 503 (≥95% = hard cutoff)

open Coprocessor

// ---------------------------------------------------------------------------
// Health classification
// ---------------------------------------------------------------------------

// Three-band health level for a single resource dimension.
// Maps to green/amber/red in the KernelMonitor HUD.
type healthLevel =
  | Healthy   // < 70 % — normal operation
  | Warning   // 70–89 % — approaching the 95 % rejection threshold
  | Critical  // ≥ 90 % — rejection of new ops imminent

// Classify a utilisation percentage (0.0–100.0) into a health band.
let healthOf = (pct: float): healthLevel =>
  if pct < 70.0 {
    Healthy
  } else if pct < 90.0 {
    Warning
  } else {
    Critical
  }

// Convert a health level to a compact string indicator (for log output / UI).
let healthToString = (h: healthLevel): string =>
  switch h {
  | Healthy  => "OK"
  | Warning  => "WARN"
  | Critical => "CRIT"
  }

// ---------------------------------------------------------------------------
// Device diagnostic snapshot
// ---------------------------------------------------------------------------

// Full diagnostic snapshot for a single hacked device.
// Carries both the raw percentage values and their derived health levels so
// callers need not recompute thresholds.
type deviceDiagnostic = {
  // Canonical device identifier (as used in ResourceAccounting.deviceStates)
  deviceId: string,
  // Utilisation percentages (0.0–100.0) for each resource dimension
  computePct: float,
  memoryPct: float,
  energyPct: float,
  // Number of coprocessor ops currently in-flight on this device
  activeCalls: int,
  // Health classification for compute and energy (the two dimensions that
  // trigger 503 rejection in ResourceAccounting.hasCapacity)
  computeHealth: healthLevel,
  energyHealth: healthLevel,
  // Full human-readable report string (from Kernel.getDeviceReport)
  report: string,
}

// Generate a typed diagnostic snapshot for `deviceId`.
// If the device has never been accessed before this call, it is lazily
// created with default quotas and zero usage (all Healthy).
let diagnoseDevice = (deviceId: string): deviceDiagnostic => {
  let pct = ResourceAccounting.getUsagePercentage(deviceId)
  let s   = ResourceAccounting.getDeviceState(deviceId)
  {
    deviceId,
    computePct:    pct.compute,
    memoryPct:     pct.memory,
    energyPct:     pct.energy,
    activeCalls:   s.activeCalls,
    computeHealth: healthOf(pct.compute),
    energyHealth:  healthOf(pct.energy),
    report:        Kernel.getDeviceReport(deviceId),
  }
}

// Return a compact one-line status summary for a device.
// Suitable for the KernelMonitor HUD status bar and `top`-style terminal output.
// Example: "server-01  compute=42% [OK]  energy=67% [OK]  active=2"
let shortStatus = (deviceId: string): string => {
  let d = diagnoseDevice(deviceId)
  let fmtPct = (f: float): string => Int.toString(Float.toInt(Math.floor(f)))
  `${deviceId}  compute=${fmtPct(d.computePct)}% [${healthToString(d.computeHealth)}]` ++
  `  energy=${fmtPct(d.energyPct)}% [${healthToString(d.energyHealth)}]` ++
  `  active=${Int.toString(d.activeCalls)}`
}

// Returns true if the device is safe to dispatch to (no resource dimension
// is at Warning or Critical).  Useful as a quick pre-check before scheduling
// a large batch.
let isHealthy = (deviceId: string): bool => {
  let d = diagnoseDevice(deviceId)
  d.computeHealth == Healthy && d.energyHealth == Healthy
}

// ---------------------------------------------------------------------------
// Backend health statistics
// ---------------------------------------------------------------------------

// Health snapshot for a single registered coprocessor backend.
// Aggregated from the mutable stats fields in Coprocessor.backend.
type backendDiagnostic = {
  // Backend identifier (e.g. "maths-v1", "crypto-v1")
  id: string,
  // Domain this backend handles (Maths, Crypto, Neural, etc.)
  domain: Domain.t,
  // Lifetime totals accumulated across all calls to this backend
  totalCalls: int,
  totalComputeUnits: int,
  totalEnergyJoules: float,
  // Peak memory allocation seen across all calls (bytes)
  peakMemoryBytes: int,
}

// Collect a typed snapshot from a Coprocessor.backend record.
let diagnoseBackend = (b: backend): backendDiagnostic => {
  {
    id:                 b.id,
    domain:             b.domain,
    totalCalls:         b.stats.totalCalls,
    totalComputeUnits:  b.stats.totalCompute,
    totalEnergyJoules:  b.stats.totalEnergy,
    peakMemoryBytes:    b.stats.totalMemory,
  }
}

// Return diagnostic snapshots for ALL registered backends across ALL domains.
// Order is deterministic: domains are iterated in the order they appear in
// Domain.all (defined in Coprocessor.res).
let allBackendDiagnostics = (): array<backendDiagnostic> => {
  let allDomains = [
    Domain.Crypto, Domain.Maths, Domain.Vector, Domain.IO, Domain.Neural,
    Domain.Physics, Domain.Quantum, Domain.Audio, Domain.Tensor, Domain.Graphics,
  ]
  Array.flatMap(allDomains, domain =>
    Array.map(listByDomain(domain), diagnoseBackend)
  )
}

// ---------------------------------------------------------------------------
// System-wide health summary
// ---------------------------------------------------------------------------

// Return the number of registered backends across all domains.
// Useful as a sanity check that CoprocessorManager.init() was called.
let registeredBackendCount = (): int =>
  Array.length(allBackendDiagnostics())

// Return true if all 10 expected domain backends are registered.
// Each domain should have exactly one backend after a successful init().
let allDomainsRegistered = (): bool =>
  registeredBackendCount() == 10
