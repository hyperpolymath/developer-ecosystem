// SPDX-License-Identifier: PMPL-1.0-or-later
// Kernel.res  Resource-aware Coprocessor Scheduler
//
// Orchestrates coprocessor execution for a specific game device.
// Responsibilities (in order):
//   1. Pre-flight capacity check — reject immediately if device is nearly exhausted
//   2. Domain routing — dispatch to the appropriate specialised kernel handler
//   3. Post-execution accounting — update compute/memory/energy totals
//   4. Power reporting — notify the game's physical power system of energy drain
//
// All coprocessor calls must go through `execute`. Calling backend.execute
// directly bypasses resource accounting and domain-specific constraints.

open Coprocessor

// --- Internal Accounting ---

// Update device state and backend statistics after a completed operation.
//
// Compute and energy are cumulative (added to running totals on each call).
// Memory uses peak semantics — we only update if this operation's allocation
// exceeds the current recorded peak, because the game models memory as
// "maximum live allocation" rather than total historical bytes.
//
// Only called on status-0 (successful) results to avoid charging the device
// for failed or rejected operations.
let updateAccounting = (
  state: ResourceAccounting.deviceResourceState,
  b: backend,
  result: executionResult,
): unit => {
  // Cumulative resource drain
  state.used.maxCompute = state.used.maxCompute + result.metrics.computeUnits
  state.used.maxEnergy = state.used.maxEnergy +. result.metrics.energyJoules

  // Peak memory — only update if this operation exceeded the current peak
  if result.metrics.memoryBytes > state.used.maxMemory {
    state.used.maxMemory = result.metrics.memoryBytes
  }

  // Report energy drain to the game's physical power / UPS simulation system
  Coprocessor.reportPowerUsage(state.id, result.metrics.energyJoules)

  // Accumulate per-backend lifetime statistics (used by diagnostics / ADR-0013 enforcement)
  b.stats.totalCompute = b.stats.totalCompute + result.metrics.computeUnits
  b.stats.totalEnergy = b.stats.totalEnergy +. result.metrics.energyJoules
  b.stats.totalCalls = b.stats.totalCalls + 1
  if result.metrics.memoryBytes > b.stats.totalMemory {
    b.stats.totalMemory = result.metrics.memoryBytes
  }
}

// --- Execution ---

// Execute a coprocessor operation on behalf of a hacked device.
//
// Flow:
//   1. Retrieve device resource state (lazy-created on first access)
//   2. Pre-flight: reject with 503 if device capacity is ≥95% on any resource
//   3. Look up the first registered backend for the requested domain (404 if none)
//   4. Increment active-call counter; route to domain kernel handler
//   5. On completion: decrement counter; update accounting for successful ops
//
// Returns a Promise — callers must await results; the game loop must not block.
let execute = (
  deviceId: string,
  domain: Domain.t,
  cmd: string,
  data: array<int>,
): promise<executionResult> => {
  let state = ResourceAccounting.getDeviceState(deviceId)

  // --- Pre-flight capacity check ---
  // Reject before dispatching if the device is near exhaustion (≥95% on
  // compute or energy). This is a fast-path guard; the per-operation
  // `checkQuota` is applied inside each kernel handler where precise metrics
  // are available.
  if !ResourceAccounting.hasCapacity(state) {
    Promise.resolve({
      status: 503,
      data: [],
      metrics: emptyMetrics,
      message: Some(
        `Kernel: Device ${deviceId} is resource-exhausted (≥95% utilisation). ` ++
        `Reboot the device or wait for energy to recover.`,
      ),
    })
  } else {
    // --- Backend resolution ---
    let backends = Coprocessor.listByDomain(domain)
    switch Array.get(backends, 0) {
    | None =>
      Promise.resolve({
        status: 404,
        data: [],
        metrics: emptyMetrics,
        message: Some(
          `Kernel: No backend registered for domain ${Domain.toString(domain)}. ` ++
          `Find a device that has this coprocessor installed.`,
        ),
      })

    | Some(b) =>
      state.activeCalls = state.activeCalls + 1

      // --- Domain routing ---
      // Each domain has a specialised handler that applies additional constraints
      // (IO sandboxing, crypto rate limiting, quantum energy/cooldown checks, etc.)
      // before calling the underlying backend.execute.
      let task = switch domain {
      | IO => Kernel_IO.handleIO(deviceId, cmd, data)
      | Crypto => Kernel_Crypto.handleCrypto(deviceId, cmd, data)
      | Quantum => Kernel_Quantum.handleQuantum(deviceId, cmd, data)
      | Vector | Tensor | Physics | Maths | Neural | Audio =>
        Kernel_Compute.handleCompute(deviceId, domain, cmd, data)
      | Graphics =>
        // Graphics backend has no special kernel handler — route directly.
        // It still goes through accounting below.
        b.execute(cmd, data)
      }

      // --- Post-execution accounting ---
      task->Promise.then(result => {
        state.activeCalls = state.activeCalls - 1
        // Only charge the device for successful operations
        if result.status == 0 {
          updateAccounting(state, b, result)
        }
        Promise.resolve(result)
      })
    }
  }
}

// --- Diagnostics ---

// Generate a human-readable resource usage report for a device.
// Exposed to the player via the game's `sysinfo` / `top` terminal commands
// and to the KernelMonitor HUD via ResourceAccounting.getUsagePercentage.
let getDeviceReport = (deviceId: string): string => {
  let pct = ResourceAccounting.getUsagePercentage(deviceId)
  let s = ResourceAccounting.getDeviceState(deviceId)
  // Format a float percentage as an integer string (e.g. 82.4 → "82%")
  let fmtPct = (f: float): string => {
    let clamped = if f < 0.0 {0.0} else if f > 100.0 {100.0} else {f}
    Int.toString(Float.toInt(Math.floor(clamped))) ++ "%"
  }
  `Device ${deviceId} Resource Report:
  - Compute : ${Int.toString(s.used.maxCompute)} / ${Int.toString(s.available.maxCompute)} units (${fmtPct(pct.compute)})
  - Memory  : ${Int.toString(s.used.maxMemory)} B / ${Int.toString(s.available.maxMemory)} B (${fmtPct(pct.memory)})
  - Energy  : ${Float.toString(s.used.maxEnergy)} J / ${Float.toString(s.available.maxEnergy)} J (${fmtPct(pct.energy)})
  - Active  : ${Int.toString(s.activeCalls)} task(s)`
}
