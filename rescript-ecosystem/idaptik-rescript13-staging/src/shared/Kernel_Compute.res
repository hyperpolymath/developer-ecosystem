// SPDX-License-Identifier: PMPL-1.0-or-later
// Kernel_Compute.res  General-purpose compute domain scheduler.
//
// Handles all compute-bound coprocessor domains that do not have a
// domain-specific kernel handler:
//   Vector | Tensor | Physics | Maths | Neural | Audio
//
// (IO routes through Kernel_IO, Crypto through Kernel_Crypto,
//  Quantum through Kernel_Quantum, Graphics directly through the
//  backend — see Kernel.res.)
//
// Responsibilities:
//   1. Data length safety cap — reject oversized input arrays before
//      they can cause runaway computation.  Domain-specific limits:
//        Vector / Neural / Audio  → 513 elements  (n + 256 + 256 for binary ops)
//        Maths / Physics           →  16 elements  (all ops are small)
//        Tensor                    → 259 elements  (rows + cols + inner + 16×16 = 256)
//        (Graphics is not routed through this handler)
//   2. Concurrency safety cap — reject if device has ≥ 10 active calls.
//      This prevents scheduler flooding when a VM program loops tightly.
//   3. Backend dispatch — look up the registered backend for the domain
//      and forward (cmd, data) to it.  Returns 404 if no backend is found.
//
// Resource accounting (compute, memory, energy) is applied by Kernel.execute
// after this handler returns; this handler only gatekeeps.

open Coprocessor

// ---------------------------------------------------------------------------
// Data length limits (elements in the input array)
// ---------------------------------------------------------------------------

// Maximum concurrent compute-domain calls per device before we return 504.
// Chosen to give some headroom for parallelism while preventing abuse.
let maxConcurrentCompute = 10

// Per-domain data array length caps.
// Inputs exceeding these limits return status 413 (payload too large).
let dataLimitForDomain = (domain: Domain.t): int =>
  switch domain {
  | Vector | Neural | Audio => 513   // n header + two 256-element vectors
  | Maths  | Physics        => 16    // all commands take ≤ 4 small ints
  | Tensor                  => 259   // 3 dimension ints + 16×16 matrix
  | _                       => 1024  // catch-all fallback
  }

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

// Handle a compute-domain call for the given device.
//
// Flow:
//   1. Check active call count → 504 if saturated
//   2. Check data array length → 413 if too large for this domain
//   3. Look up first registered backend for the domain → 404 if absent
//   4. Dispatch to backend.execute(cmd, data)
let handleCompute = (
  deviceId: string,
  domain:   Domain.t,
  cmd:      string,
  data:     array<int>,
): promise<executionResult> => {
  let state = ResourceAccounting.getDeviceState(deviceId)

  // --- Concurrency guard ---
  if state.activeCalls >= maxConcurrentCompute {
    Promise.resolve({
      status:  504,
      data:    [],
      metrics: emptyMetrics,
      message: Some(
        `Compute kernel: ${Domain.toString(domain)} call rejected — ` ++
        `${Int.toString(maxConcurrentCompute)} concurrent ops already active on ${deviceId}. ` ++
        `Wait for earlier tasks to complete.`,
      ),
    })
  } else {
    // --- Data length guard ---
    let limit   = dataLimitForDomain(domain)
    let dataLen = Array.length(data)
    if dataLen > limit {
      Promise.resolve({
        status:  413,
        data:    [],
        metrics: emptyMetrics,
        message: Some(
          `Compute kernel: ${Domain.toString(domain)}:${cmd} payload ${Int.toString(dataLen)} elements ` ++
          `exceeds limit of ${Int.toString(limit)} for this domain.`,
        ),
      })
    } else {
      // --- Backend dispatch ---
      let backends = Coprocessor.listByDomain(domain)
      switch Array.get(backends, 0) {
      | None =>
        Promise.resolve({
          status:  404,
          data:    [],
          metrics: emptyMetrics,
          message: Some(
            `Compute kernel: no backend registered for ${Domain.toString(domain)} on ${deviceId}. ` ++
            `This domain requires hardware you have not yet hacked.`,
          ),
        })
      | Some(b) =>
        b.execute(cmd, data)
      }
    }
  }
}
