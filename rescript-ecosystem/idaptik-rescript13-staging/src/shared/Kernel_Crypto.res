// SPDX-License-Identifier: PMPL-1.0-or-later
// Kernel_Crypto.res  Cryptography domain kernel handler.
//
// Wraps Coprocessor_Security.Crypto.Backend with two layers of enforcement before
// dispatching to the backend:
//
//   1. Concurrent rate limit — at most 3 simultaneous crypto operations
//      per device.  Crypto is expensive; flooding the scheduler with
//      crack requests must not freeze other coprocessor domains.
//      Status 429 (Too Many Requests) is returned when the limit is hit.
//
//   2. Quantum gate for high-strength crack — crack commands with
//      strength ≥ 4 are intercepted and routed through the Quantum
//      domain backend instead of the Crypto backend.  This models the
//      game lore that only quantum-capable hardware can break strong
//      ciphers, and forces players to find a quantum node before
//      attempting deep cracks.  Status 402 (Quantum Required) is
//      returned if no Quantum backend is registered.
//
// Accounting (compute, memory, energy) is applied by Kernel.execute
// after this handler returns; this handler only gatekeeps.

open Coprocessor

// ---------------------------------------------------------------------------
// Per-device concurrency tracking
// ---------------------------------------------------------------------------

// Maximum simultaneous crypto operations allowed per device.
let maxConcurrentCrypto = 3

// Active crypto call counts keyed by deviceId.
// Lazily populated; never shrinks (counts reset to 0 rather than removed).
let cryptoActiveCounts: dict<ref<int>> = Dict.make()

// Retrieve (or lazily create) the active-count ref for a device.
let getCount = (deviceId: string): ref<int> =>
  switch Dict.get(cryptoActiveCounts, deviceId) {
  | Some(r) => r
  | None =>
    let r = ref(0)
    Dict.set(cryptoActiveCounts, deviceId, r)
    r
  }

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

// Handle a Crypto domain call for the given device.
//
// Flow:
//   1. Check concurrent rate limit → 429 if at capacity
//   2. For crack with strength ≥ 4 → route to Quantum backend (or 402)
//   3. Otherwise → dispatch to Crypto backend
//   4. Decrement active count when the promise settles
let handleCrypto = (
  deviceId: string,
  cmd:      string,
  data:     array<int>,
): promise<executionResult> => {
  let count = getCount(deviceId)

  // --- Rate limit check ---
  if count.contents >= maxConcurrentCrypto {
    Promise.resolve({
      status:  429,
      data:    [],
      metrics: emptyMetrics,
      message: Some(
        `Crypto kernel: rate limit hit on ${deviceId} ` ++
        `(${Int.toString(maxConcurrentCrypto)} concurrent ops max). ` ++
        `Wait for a crypto op to complete before retrying.`,
      ),
    })
  } else {
    // --- Quantum gate for high-strength crack ---
    // crack strength is encoded in data[1] (default 3 if absent).
    let strength = switch (cmd, Array.get(data, 1)) {
    | ("crack", Some(s)) => s
    | ("crack", None)    => 3
    | _                  => 0
    }

    if cmd == "crack" && strength >= 4 {
      // Intercept: route crack strength ≥ 4 to the Quantum backend.
      let quantumBackends = Coprocessor.listByDomain(Quantum)
      switch Array.get(quantumBackends, 0) {
      | None =>
        Promise.resolve({
          status:  402,
          data:    [],
          metrics: emptyMetrics,
          message: Some(
            `Crypto kernel: crack strength ${Int.toString(strength)} requires a Quantum backend. ` ++
            `Find and hack a quantum-capable node first.`,
          ),
        })
      | Some(qb) =>
        count := count.contents + 1
        qb.execute(cmd, data)->Promise.then(result => {
          count := count.contents - 1
          Promise.resolve(result)
        })
      }
    } else {
      // --- Standard Crypto dispatch ---
      let cryptoBackends = Coprocessor.listByDomain(Crypto)
      switch Array.get(cryptoBackends, 0) {
      | None =>
        Promise.resolve({
          status:  404,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Crypto kernel: no backend registered for device ${deviceId}`),
        })
      | Some(b) =>
        count := count.contents + 1
        b.execute(cmd, data)->Promise.then(result => {
          count := count.contents - 1
          Promise.resolve(result)
        })
      }
    }
  }
}
