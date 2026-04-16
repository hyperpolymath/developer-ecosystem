// SPDX-License-Identifier: PMPL-1.0-or-later
// CoprocessorManager.res  High-level coprocessor API for game code.
//
// This is the primary entry point for all coprocessor invocations from game
// code: device GUIs, terminal command handlers, the VM port bridge, and any
// future scripting system.
//
// All calls route through Kernel.execute, which applies:
//   - Pre-flight resource capacity checks (reject exhausted devices early)
//   - Domain-specific constraints (IO sandboxing, crypto rate limits, etc.)
//   - Post-execution resource accounting (compute/memory/energy tracking)
//   - Power drain reporting to the game's physical power simulation
//
// The `deviceId` parameter is mandatory on all execution calls because
// resources are tracked per-device. A crypto:crack op on a powerful server
// draws from that server's energy pool; the same op on a battery-powered
// IoT sensor will exhaust it far sooner.

open Coprocessor

// --- Single Operation ---

// Execute one coprocessor operation on a specific device.
//
// Parameters:
//   deviceId — the ID of the hacked device providing compute resources
//   domain   — which coprocessor domain to use (Crypto, IO, Maths, etc.)
//   cmd      — the operation to perform (e.g. "hash", "crack", "encrypt")
//   data     — integer input array; encoding is command-specific (see design doc)
//
// Returns a promise resolving to an executionResult:
//   status 0   → success, `data` contains the result
//   status 503 → device resource-exhausted
//   status 404 → domain has no registered backend
//   status 400 → malformed input data
//   status 429 → rate limit exceeded (crypto/quantum)
let call = (
  deviceId: string,
  domain: Domain.t,
  cmd: string,
  data: array<int>,
): promise<executionResult> => {
  Kernel.execute(deviceId, domain, cmd, data)
}

// --- Batch Operation ---

// Execute the same command over multiple input arrays concurrently.
// All operations run in parallel (Promise.all) and draw from the same
// device resource pool — use carefully on resource-constrained devices.
//
// Example use: scanning an entire subnet with `neural:fingerprint` in one call,
// or hashing a batch of files with `crypto:hash`.
let map = (
  deviceId: string,
  domain: Domain.t,
  cmd: string,
  batch: array<array<int>>,
): promise<array<executionResult>> => {
  batch
  ->Array.map(data => Kernel.execute(deviceId, domain, cmd, data))
  ->Promise.all
}

// --- Device Lifecycle ---

// Enrol a device in resource tracking when the player first hacks into it.
// This pre-creates the device's resource state so the KernelMonitor HUD can
// display bars immediately, before any coprocessor ops are invoked.
//
// Servers should call `ResourceAccounting.setQuota` after this to assign
// higher-than-default limits. Cameras/IoT devices may leave defaults.
let setup = (deviceId: string): unit => {
  let _ = ResourceAccounting.getDeviceState(deviceId)
  Console.log(`CoprocessorManager: Device "${deviceId}" enrolled in resource tracking.`)
}

// Reset a device's resource counters to zero.
// Call on device reboot, player disconnect, or puzzle reset.
// Does NOT change the device's quota — only clears usage totals.
let reset = (deviceId: string): unit => {
  ResourceAccounting.resetDevice(deviceId)
  Console.log(`CoprocessorManager: Device "${deviceId}" resource counters reset.`)
}

// --- Resilient Single Operation ---

// Execute one coprocessor operation with automatic retry on transient failures.
//
// Retries on statuses 503 (Resource Exhausted), 504 (Compute Saturated), and
// 429 (Rate Limited) using the supplied `policy` (default: RetryPolicy.defaultPolicy
// — 3 retries, 50 ms base delay, 2× exponential backoff).
//
// Permanent failures (400, 402, 404, 413) propagate without retry — retrying
// a bad command or a missing backend would only waste time.
//
// Use `callWithRetry` instead of `call` whenever:
//   - The target device is expected to be under load (server, shared node)
//   - The operation is part of a long-running puzzle sequence
//   - A 503/504 response would be incorrect from the player's perspective
let callWithRetry = (
  deviceId: string,
  domain: Domain.t,
  cmd: string,
  data: array<int>,
  ~policy: RetryPolicy.policy=RetryPolicy.defaultPolicy,
): promise<executionResult> =>
  RetryPolicy.withRetry(policy, () => Kernel.execute(deviceId, domain, cmd, data))

// --- Bounded-Concurrency Batch Operation ---

// Split `arr` into non-overlapping sub-arrays of at most `size` elements.
// The final chunk may be smaller than `size` if `len % size != 0`.
// Returns [] for an empty input or size ≤ 0.
let chunkArray = (arr: array<'a>, ~size: int): array<array<'a>> => {
  let len = Array.length(arr)
  let chunks = ref([])
  let i = ref(0)
  while i.contents < len && size > 0 {
    let start = i.contents
    let end_ = min(start + size, len)
    let chunk = Array.slice(arr, ~start, ~end=end_)
    chunks := Array.concat(chunks.contents, [chunk])
    i := end_
  }
  chunks.contents
}

// Execute the same command over multiple input arrays with bounded concurrency.
//
// Unlike `map` (which uses Promise.all and dispatches ALL operations at once),
// this function splits `batch` into chunks of at most `chunkSize` elements
// and dispatches each chunk sequentially, using Promise.all only within a
// single chunk.  Results are collected in order and returned as one flat array.
//
// Why bounded concurrency matters:
//   Kernel_Compute enforces maxConcurrentCompute = 10 per device.
//   Kernel_Crypto  enforces maxConcurrentCrypto  =  3 per device.
//   Promise.all dispatches all ops synchronously, meaning a batch of 50 would
//   see activeCalls jump to 50 before any resolve — all ops past the limit
//   return 504 or 429 immediately.  mapBounded stays within the safe window.
//
// Default chunkSize = 9:
//   - Safe for Maths / Vector / Physics / Neural / Audio / Tensor / Graphics
//   - Use chunkSize = 3 (or 2 to leave headroom) for Crypto / Quantum domains
//
// Example:
//   // Hash 100 inputs with the Crypto backend (limit 3 concurrent):
//   CoprocessorManager.mapBounded(deviceId, Crypto, "hash", inputs, ~chunkSize=3)
let mapBounded = (
  deviceId: string,
  domain: Domain.t,
  cmd: string,
  batch: array<array<int>>,
  ~chunkSize: int=9,
): promise<array<executionResult>> => {
  let chunks = chunkArray(batch, ~size=chunkSize)
  // Chain chunks sequentially; within each chunk all ops run in parallel
  chunks->Array.reduce(Promise.resolve([]), (acc, chunk) =>
    acc->Promise.then(soFar =>
      chunk
      ->Array.map(data => Kernel.execute(deviceId, domain, cmd, data))
      ->Promise.all
      ->Promise.then(results => Promise.resolve(Array.concat(soFar, results)))
    )
  )
}

// --- Framework Initialisation ---

// Register all built-in coprocessor backends.
// Must be called ONCE at game startup (from Main.res) before any coprocessor
// operations are attempted. Subsequent calls are harmless but will re-register
// all backends (creating duplicates in the registry), so call only once.
let init = (): unit => {
  Coprocessor_Backends.initAll()
  Console.log("CoprocessorManager: Framework initialised with 10 domains.")
}
