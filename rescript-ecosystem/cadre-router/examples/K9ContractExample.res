// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// K9ContractExample.res - Demonstrates client-side K9-SVC contract enforcement
//
// K9 contracts are lightweight, observational performance contracts that sit above
// a2ml attestations. On the client side, they measure actual timing of navigation,
// guard evaluation, and DOM mount operations against declared SLA thresholds and
// execute breach policies when those thresholds are exceeded.
//
// Key principle: client-side K9 contracts NEVER block operations. A breached
// navigation contract logs a warning and optionally fires a callback for telemetry,
// but the navigation still completes. This differs from server-side K9 contracts
// in http-capability-gateway and hybrid-automation-router, which can reject or
// circuit-break on breach.
//
// ## Contract Types
//
//   - navigationContract: SLA for route resolution time (URL parse + match).
//   - guardContract: SLA for guard evaluation (separate sync and async thresholds).
//   - mountContract: SLA for DOM mounting via SafeDOM / rescript-dom-mounter.
//
// ## Breach Policies
//
//   - Log: console.warn only (lightest touch, good for development).
//   - Warn: console.warn + optional onBreach callback (good for telemetry).
//   - Degrade: console.error + callback + marks result as degraded.
//
// ## Architecture
//
//   Contracts are pure records. Enforcement is a timing wrapper using
//   performance.now(). No mutable state, no ETS, no runtime overhead when
//   no contracts are registered. Contract IDs use DJB2 hash (lightweight,
//   client-appropriate; server side uses SHA-256).

open Tea_Url

// ============================================================================
// Example 1: Basic Navigation Contract
// ============================================================================
//
// Wrap a route resolution function with a 20ms SLA. If resolution takes longer
// than 20ms, the breach is logged to console.warn. The resolved route is always
// returned regardless of breach status.

let basicNavigationContract = (): unit => {
  // Create a navigation contract with a 20ms threshold and Log policy.
  let contract = K9Contract.makeNavigationContract(20.0)

  // Simulate route resolution (in reality, this calls your parser).
  let url = Tea_Url.parse("/users/alice/settings")
  let result = K9Contract.enforceNavigation(contract, () => {
    // This is where your actual route parsing logic goes.
    // The K9 wrapper measures how long this function takes.
    url.path
  })

  // The result contains the parsed value, timing, and breach status.
  Js.Console.log(`Route: ${result.value}`)
  Js.Console.log(`Resolution time: ${Belt.Float.toString(result.elapsedMs)}ms`)
  Js.Console.log(`Breached: ${result.breached ? "yes" : "no"}`)
  Js.Console.log(`Contract ID: ${result.contractId}`)
}

// ============================================================================
// Example 2: Navigation Contract with Breach Callback
// ============================================================================
//
// Use the Warn policy with an onBreach callback to send performance metrics
// to a telemetry service when the SLA is breached.

let navigationWithTelemetry = (): unit => {
  // Telemetry callback — fires only when the contract is breached.
  let reportBreach = (contractId: string, elapsedMs: float) => {
    Js.Console.log(
      `[telemetry] Navigation SLA breach: contract=${contractId} ` ++
      `elapsed=${Belt.Float.toString(elapsedMs)}ms`
    )
    // In a real application, you would send this to your metrics backend:
    // Telemetry.recordBreach(~contractId, ~elapsedMs, ~type_="navigation")
  }

  let contract = K9Contract.makeNavigationContract(
    10.0,  // 10ms threshold — tight SLA
    ~breachPolicy=Warn,
    ~onBreach=Some(reportBreach),
  )

  let url = Tea_Url.parse("/dashboard")
  let _result = K9Contract.enforceNavigation(contract, () => {
    url.path
  })
}

// ============================================================================
// Example 3: Guard Contracts — Sync and Async
// ============================================================================
//
// Guard contracts have separate thresholds for synchronous and asynchronous
// guard evaluation. Sync guards (role checks, feature flags) should resolve
// in under 1ms. Async guards (network checks, token refresh) get more room.

let guardContracts = (): unit => {
  // Create a guard contract: 1ms sync, 2000ms async, Warn on breach.
  let contract = K9Contract.makeGuardContract(
    1.0,     // maxSyncGuardMs — sync guards should be near-instant
    2000.0,  // maxAsyncGuardMs — network round-trip budget
    ~breachPolicy=Warn,
  )

  // Enforce a synchronous guard (e.g., role check).
  let syncResult = K9Contract.enforceSyncGuard(contract, () => {
    // Simulate a role-based access check.
    let userRole = "admin"
    let requiredRole = "admin"
    userRole == requiredRole
  })

  Js.Console.log(`Guard allowed: ${syncResult.value ? "yes" : "no"}`)
  Js.Console.log(`Guard time: ${Belt.Float.toString(syncResult.elapsedMs)}ms`)
  Js.Console.log(`Guard breached: ${syncResult.breached ? "yes" : "no"}`)

  // Enforce an asynchronous guard (e.g., server-side permission check).
  // enforceAsyncGuard returns a Promise<contractResult<'a>>.
  let _asyncPromise = K9Contract.enforceAsyncGuard(contract, () => {
    // Simulate an async permission check that takes ~100ms.
    Promise.make((resolve, _reject) => {
      ignore(K9Contract.performanceNow()) // reference start time
      resolve(true) // In reality: fetch("/api/auth/check") |> ...
    })
  })
  // _asyncPromise->Promise.then(result => {
  //   Js.Console.log(`Async guard time: ${Belt.Float.toString(result.elapsedMs)}ms`)
  //   Promise.resolve()
  // })->ignore
}

// ============================================================================
// Example 4: Mount Contract — DOM Mounting SLA
// ============================================================================
//
// Mount contracts measure the time from a SafeDOM.mountSafe call to the
// onSuccess callback firing. Since mounting uses callbacks (not return values),
// enforceMount also uses a callback-style API.

let mountContract = (): unit => {
  let contract = K9Contract.makeMountContract(
    100.0,  // 100ms mount budget
    ~breachPolicy=Warn,
    ~onBreach=Some((contractId, elapsed) => {
      Js.Console.log(
        `[perf] Mount SLA breach: ${contractId} took ${Belt.Float.toString(elapsed)}ms`
      )
    }),
  )

  // enforceMount wraps a callback-style mount operation.
  // The first argument (onResult) is a callback that you call from inside
  // your mount operation with Ok(element) or Error(string).
  K9Contract.enforceMount(contract, onResult => {
    // In a real app, this would be:
    // SafeDOM.mountSafe("#app", html,
    //   ~onSuccess=el => onResult(Ok(el)),
    //   ~onError=e => onResult(Error(e)),
    // )
    //
    // For this example, simulate a successful mount:
    Js.Console.log("[mount] Simulating DOM mount...")
    onResult(Error("No DOM in example"))
  }, ~onComplete=result => {
    switch result.value {
    | Ok(_el) =>
      Js.Console.log(`[mount] Mounted in ${Belt.Float.toString(result.elapsedMs)}ms`)
    | Error(err) =>
      Js.Console.log(`[mount] Mount failed: ${err} (${Belt.Float.toString(result.elapsedMs)}ms)`)
    }
    Js.Console.log(`[mount] Breached: ${result.breached ? "yes" : "no"}`)
  })
}

// ============================================================================
// Example 5: Contract Sets — Bundled Contracts for an Application
// ============================================================================
//
// A contractSet bundles navigation, guard, and mount contracts with consistent
// thresholds and policies. Two presets are provided:
//
//   - standardSet: 20ms nav, 1ms sync guard, 2000ms async guard, 100ms mount
//   - strictSet: 5ms nav, 0.5ms sync guard, 1000ms async guard, 50ms mount
//
// You can also build custom sets from individual contracts.

let contractSets = (): unit => {
  // Standard set — suitable for most applications.
  let _standard = K9Contract.standardSet(
    ~breachPolicy=Warn,
    ~onBreach=Some((id, ms) => {
      Js.Console.log(`[standard] Breach: ${id} at ${Belt.Float.toString(ms)}ms`)
    }),
  )

  // Strict set — for performance-critical apps. Uses Degrade policy,
  // meaning breaches are logged as errors and marked as degraded.
  let strict = K9Contract.strictSet(
    ~onBreach=Some((id, ms) => {
      Js.Console.log(`[strict] Breach: ${id} at ${Belt.Float.toString(ms)}ms`)
    }),
  )

  // Use individual contracts from the set.
  switch strict.navigation {
  | Some(navContract) =>
    let url = Tea_Url.parse("/")
    let result = K9Contract.enforceNavigation(navContract, () => url.path)
    Js.Console.log(`Strict nav: ${Belt.Float.toString(result.elapsedMs)}ms`)
  | None => ()
  }

  // Empty set — no enforcement at all. Useful for testing or gradual rollout.
  let _noEnforcement = K9Contract.emptySet
  ignore(_noEnforcement)
}

// ============================================================================
// Example 6: React Hook Integration — useContractBreaches
// ============================================================================
//
// The K9Contract.ReactHook module provides a React hook that tracks breach
// events in component state. This is useful for developer tools panels,
// performance dashboards, or degraded-experience indicators.
//
// The hook returns:
//   - breachCount: total number of breaches since mount
//   - breachLog: array of recent breach entries (most recent first, capped)
//   - onBreach: callback to pass to contract constructors
//
// Note: This is a React component and requires @rescript/react.

module PerformanceDashboard = {
  @react.component
  let make = () => {
    // The hook tracks breaches in component state.
    // Pass ~maxEntries to limit the log size (default: 20).
    let (breachCount, breachLog, onBreach) =
      K9Contract.ReactHook.useContractBreaches(~maxEntries=50)

    // Create contracts that report breaches to the hook.
    let navContract = K9Contract.makeNavigationContract(
      15.0,
      ~breachPolicy=Warn,
      ~onBreach=Some(onBreach),
    )

    // Use the contract in navigation...
    ignore(navContract)

    // Render breach information in a developer tools panel.
    <div style={ReactDOM.Style.make(~padding="16px", ~fontFamily="monospace", ())}>
      <h3>
        {React.string("K9 Contract Performance")}
      </h3>
      <p>
        {React.string(`Total breaches: ${Belt.Int.toString(breachCount)}`)}
      </p>
      <h4> {React.string("Recent Breaches")} </h4>
      {if Array.length(breachLog) == 0 {
        <p style={ReactDOM.Style.make(~color="green", ())}>
          {React.string("No breaches recorded. All contracts within SLA.")}
        </p>
      } else {
        <ul>
          {breachLog
          ->Array.mapWithIndex((entry, index) => {
            <li key={Belt.Int.toString(index)}>
              {React.string(
                `[${entry.contractId}] ${Belt.Float.toString(entry.elapsedMs)}ms ` ++
                `at t=${Belt.Float.toString(entry.timestamp)}ms`
              )}
            </li>
          })
          ->React.array}
        </ul>
      }}
    </div>
  }
}

// ============================================================================
// Example 7: Custom Contract with computeContractId
// ============================================================================
//
// If the preset constructors do not fit your needs, you can build contracts
// manually. computeContractId generates a deterministic hex ID from a content
// string (DJB2 hash — fast, good distribution, deterministic).

let customContract = (): unit => {
  // Generate a custom contract ID.
  let id = K9Contract.computeContractId("custom|my-special-route|10ms")
  Js.Console.log(`Custom contract ID: ${id}`)

  // Build a navigation contract manually using the computed ID.
  // In practice you would use makeNavigationContract, but this shows
  // the underlying record structure.
  let _contract: K9Contract.navigationContract = {
    contractId: id,
    maxResolutionMs: 10.0,
    breachPolicy: Degrade,
    onBreach: Some((cid, elapsed) => {
      Js.Console.error(
        `[custom] Contract ${cid} breached at ${Belt.Float.toString(elapsed)}ms — ` ++
        "degrading experience"
      )
    }),
  }
}
