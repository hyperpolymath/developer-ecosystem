// SPDX-License-Identifier: PMPL-1.0-or-later
// Kernel_Quantum.res  Quantum domain kernel handler.
//
// Wraps Coprocessor_Security.Quantum.Backend with three layers of enforcement
// before dispatching to the backend:
//
//   1. Decoherence guard — rejects the op if the device's cumulative
//      energy use has exceeded 50 J.  Quantum hardware is extremely
//      sensitive to thermal noise; an overloaded device cannot maintain
//      qubit coherence.  Status 503 is returned.  The player must reboot
//      the device (CoprocessorManager.reset) to clear the energy counter.
//
//   2. Per-device cooldown — after any successful quantum op, the device
//      needs at least 5 seconds before it can accept another.  This
//      models decoherence recovery time (re-initialising the quantum
//      register) and makes quantum hardware a limited, strategic resource.
//      Status 503 with remaining cooldown time in the message is returned.
//
//   3. Audit logging — every quantum op is logged to the console.  At
//      higher game difficulty levels the game layer may wire this to the
//      `alert` port (PortNames.alert) to trigger IDS detection events.
//
// The energy check uses the device's accumulated `maxEnergy` field from
// ResourceAccounting, which tracks total Joules consumed across all
// coprocessor domains — not just quantum ops.  This intentionally makes
// quantum ops more likely to fail on devices that have been heavily used
// for crypto cracking or neural inference.

open Coprocessor

// ---------------------------------------------------------------------------
// Module state
// ---------------------------------------------------------------------------

// Timestamp (ms since epoch) of the last successful quantum op per device.
// Used to enforce the per-device cooldown.  Lazily populated.
let lastQuantumOp: dict<float> = Dict.make()

// Cooldown period in milliseconds.  Must elapse between quantum ops.
let quantumCooldownMs = 5000.0

// External binding for the current wall-clock timestamp.
// Avoids the deprecated Js.Date API.
@val external dateNow: unit => float = "Date.now"

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

// Handle a Quantum domain call for the given device.
//
// Flow:
//   1. Decoherence guard → 503 if device energy > 50 J
//   2. Cooldown check    → 503 with remaining-time message if too soon
//   3. Audit log the op  → Console.log (future: alert port at high difficulty)
//   4. Dispatch to Quantum backend
//   5. On resolution: record timestamp if successful (status 0)
let handleQuantum = (
  deviceId: string,
  cmd:      string,
  data:     array<int>,
): promise<executionResult> => {
  let state = ResourceAccounting.getDeviceState(deviceId)

  // --- 1. Decoherence guard ---
  // Reject if cumulative device energy exceeds 50 J.
  if state.used.maxEnergy > 50.0 {
    Promise.resolve({
      status:  503,
      data:    [],
      metrics: emptyMetrics,
      message: Some(
        `Quantum kernel: decoherence on ${deviceId} ` ++
        `(energy ${Float.toString(state.used.maxEnergy)} J > 50 J limit). ` ++
        `Reboot the device to reset energy counters.`,
      ),
    })
  } else {
    // --- 2. Cooldown check ---
    let now  = dateNow()
    let last = switch Dict.get(lastQuantumOp, deviceId) { | Some(t) => t | None => 0.0 }
    let elapsed = now -. last
    if elapsed < quantumCooldownMs && last > 0.0 {
      let remaining = Float.toInt(Math.ceil(quantumCooldownMs -. elapsed))
      Promise.resolve({
        status:  503,
        data:    [],
        metrics: emptyMetrics,
        message: Some(
          `Quantum kernel: cooldown active on ${deviceId} — ` ++
          `${Int.toString(remaining)} ms remaining before next quantum op. ` ++
          `Quantum register is re-initialising after decoherence recovery.`,
        ),
      })
    } else {
      // --- 3. Audit log ---
      // Quantum ops are "loud" — at high difficulty the game may wire
      // this to the alert port to trigger IDS events.
      Console.log(
        `[QUANTUM AUDIT] device=${deviceId} cmd=${cmd} ` ++
        `energy=${Float.toString(state.used.maxEnergy)}J`,
      )

      // --- 4. Dispatch ---
      let backends = Coprocessor.listByDomain(Quantum)
      switch Array.get(backends, 0) {
      | None =>
        Promise.resolve({
          status:  404,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Quantum kernel: no QPU backend registered. Device ${deviceId} lacks quantum hardware.`),
        })
      | Some(b) =>
        b.execute(cmd, data)->Promise.then(result => {
          // --- 5. Record timestamp for cooldown (successful ops only) ---
          if result.status == 0 {
            Dict.set(lastQuantumOp, deviceId, dateNow())
          }
          Promise.resolve(result)
        })
      }
    }
  }
}
