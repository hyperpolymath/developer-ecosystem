// SPDX-License-Identifier: PMPL-1.0-or-later
// RetryPolicy.res  Configurable retry-with-backoff for coprocessor calls.
//
// Provides a reusable retry primitive consumed by the resilient CoprocessorManager
// APIs (callWithRetry, mapBounded) and any future coprocessor-adjacent code.
//
// Design rationale
// ─────────────────
// Coprocessor failures come in two categories that require different treatment:
//
//   Transient — the device will recover as in-flight ops complete; retrying
//   after a short delay will usually succeed:
//     503  Resource Exhausted     (≥95% compute or energy utilisation)
//     504  Compute Saturated      (Kernel_Compute concurrency limit hit)
//     429  Crypto/Quantum Rate    (Kernel_Crypto / Kernel_Quantum rate limit)
//
//   Permanent — no amount of retrying will change the outcome; propagate
//   immediately so the caller can surface the error to the player:
//     400  Bad Command            (unknown or malformed command)
//     402  Quantum Required       (crack strength ≥4 without a quantum node)
//     404  No Backend             (domain not registered — hardware not hacked)
//     413  Payload Too Large      (input array exceeds domain data limit)
//
// Backoff schedule
// ────────────────
// Retry n uses delay: baseDelayMs × backoffFactor^(n−1).
//
//   With defaultPolicy (base = 50 ms, factor = 2.0, maxRetries = 3):
//     After 1st failure → wait   50 ms → 2nd attempt
//     After 2nd failure → wait  100 ms → 3rd attempt
//     After 3rd failure → wait  200 ms → 4th (final) attempt
//     Total worst-case wait ≤ 350 ms before surfacing the error.
//
// This prevents busy-looping a saturated device and gives in-flight ops time
// to complete and decrement the concurrency counters.

// External timer binding — available in Deno, Node, and all evergreen browsers.
@val external setTimeout: (unit => unit, int) => float = "setTimeout"

// ---------------------------------------------------------------------------
// Policy type
// ---------------------------------------------------------------------------

// Immutable configuration for a single retry session.
// Construct once; share across many calls.
type policy = {
  // Maximum number of re-attempts after the first failure.
  // 0 = fail-fast; 1 = one retry; 3 = three retries (four attempts total).
  maxRetries: int,
  // Base delay in milliseconds before the first retry.
  // Subsequent retries multiply this by backoffFactor.
  baseDelayMs: int,
  // Exponential multiplier applied per retry.
  // 2.0 = classic binary exponential backoff (doubles each time).
  // 1.0 = constant delay.
  backoffFactor: float,
}

// ---------------------------------------------------------------------------
// Built-in policies
// ---------------------------------------------------------------------------

// Standard policy: 3 retries, 50 ms base, 2× exponential backoff.
// Suitable for interactive game code — worst-case 350 ms additional wait
// before surfacing an error (imperceptible at game speed).
let defaultPolicy: policy = {
  maxRetries: 3,
  baseDelayMs: 50,
  backoffFactor: 2.0,
}

// Fast policy: 1 retry, 10 ms flat delay.
// Use for HUD-critical paths where latency matters more than reliability.
let fastPolicy: policy = {
  maxRetries: 1,
  baseDelayMs: 10,
  backoffFactor: 1.0,
}

// Patient policy: 5 retries, 200 ms base, 1.5× backoff.
// Use for background batch-scanning operations; worst-case ≈ 3.2 s wait.
let patientPolicy: policy = {
  maxRetries: 5,
  baseDelayMs: 200,
  backoffFactor: 1.5,
}

// ---------------------------------------------------------------------------
// Transient status classification
// ---------------------------------------------------------------------------

// Returns true iff `status` is a transient failure that may clear on retry.
// All other statuses (0 = success, 400/402/404/413 = permanent) propagate
// without retry.
let isTransient = (status: int): bool =>
  status == 503 || status == 504 || status == 429

// ---------------------------------------------------------------------------
// Timer-based delay
// ---------------------------------------------------------------------------

// Resolve a unit promise after `ms` milliseconds.
let delay = (ms: int): promise<unit> =>
  Promise.make((resolve, _reject) => {
    let _ = setTimeout(() => resolve(()), ms)
  })

// ---------------------------------------------------------------------------
// Core retry primitive
// ---------------------------------------------------------------------------

// Execute `action` up to `policy.maxRetries + 1` times total.
//
// On transient failure: wait `currentDelayMs` ms, multiply by backoffFactor,
// then retry.  On permanent failure or success: return immediately.
// If the final retry still returns a transient status, that result propagates.
//
// Flow (maxRetries = 3, base = 50 ms, factor = 2.0):
//   attempt 1 (immediate)
//     → transient → wait 50 ms
//   attempt 2
//     → transient → wait 100 ms
//   attempt 3
//     → transient → wait 200 ms
//   attempt 4 (final — retriesLeft = 0, result always propagates)
let withRetry = (
  policy: policy,
  action: unit => promise<Coprocessor.executionResult>,
): promise<Coprocessor.executionResult> => {
  // `retriesLeft`    — remaining re-attempt budget after this call
  // `currentDelayMs` — delay to apply if THIS attempt fails transiently
  let rec attempt = (
    retriesLeft: int,
    currentDelayMs: float,
  ): promise<Coprocessor.executionResult> => {
    action()->Promise.then(result => {
      if isTransient(result.status) && retriesLeft > 0 {
        // Transient failure and budget remains: apply backoff then retry
        delay(Float.toInt(currentDelayMs))
        ->Promise.then(_ =>
          attempt(retriesLeft - 1, currentDelayMs *. policy.backoffFactor)
        )
      } else {
        // Success, permanent failure, or budget exhausted: done
        Promise.resolve(result)
      }
    })
  }
  attempt(policy.maxRetries, Float.fromInt(policy.baseDelayMs))
}
