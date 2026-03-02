// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// K9Contract_test.res - Tests for K9-SVC service contract enforcement.
//
// K9 contracts provide client-side SLA enforcement for cadre-router operations.
// They measure actual timing against declared thresholds and execute breach
// policies (Log, Warn, Degrade). Contracts are observational — they never
// block navigation, only log/measure.
//
// This file tests:
//
//   1. Contract construction — makeNavigationContract, makeGuardContract,
//      makeMountContract with default and custom parameters.
//
//   2. Contract ID generation — computeContractId produces deterministic
//      DJB2 hex strings from content strings.
//
//   3. Navigation enforcement — enforceNavigation wraps synchronous route
//      resolution with timing measurement.
//
//   4. Guard enforcement — enforceSyncGuard for synchronous guards,
//      enforceAsyncGuard for Promise-based async guards.
//
//   5. Contract sets — emptySet, standardSet, strictSet presets.
//
//   6. Breach handling — handleBreach dispatches to the correct policy.

// ============================================================================
// Test Harness
// ============================================================================

let passed = ref(0)
let failed = ref(0)

let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

let assertTrue = (name: string, condition: bool): unit => {
  if condition {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected true`)
  }
}

let assertFalse = (name: string, condition: bool): unit => {
  if !condition {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected false`)
  }
}

let summary = () => {
  let total = passed.contents + failed.contents
  Js.Console.log("")
  Js.Console.log(`=== Summary: ${Belt.Int.toString(passed.contents)}/${Belt.Int.toString(total)} passed ===`)
  if failed.contents > 0 {
    Js.Console.error(`${Belt.Int.toString(failed.contents)} tests FAILED`)
  }
}

// ============================================================================
// SECTION 1: Contract ID Generation (computeContractId)
// ============================================================================
//
// computeContractId uses a DJB2-style hash to produce deterministic hex
// strings from content strings. These IDs are used for correlation and
// logging, not security.

let testComputeContractIdDeterministic = () => {
  Js.Console.log("\n-- computeContractId: Deterministic --")

  // Same input should always produce the same ID
  let id1 = K9Contract.computeContractId("nav|20|log")
  let id2 = K9Contract.computeContractId("nav|20|log")
  assertEq("contractId: deterministic", id1, id2)

  // Calling 10 times should all produce the same value
  let ids = Belt.Array.make(10, ())->Belt.Array.map(_ => K9Contract.computeContractId("test-input"))
  let allSame = ids->Belt.Array.every(id => id == ids[0]->Belt.Option.getWithDefault(""))
  assertTrue("contractId: deterministic over 10 calls", allSame)
}

let testComputeContractIdDistinct = () => {
  Js.Console.log("\n-- computeContractId: Distinct Inputs --")

  // Different inputs should produce different IDs (collision is theoretically
  // possible with any hash but practically very unlikely for these strings)
  let id1 = K9Contract.computeContractId("nav|20|log")
  let id2 = K9Contract.computeContractId("nav|20|warn")
  let id3 = K9Contract.computeContractId("guard|1|2000")
  let id4 = K9Contract.computeContractId("mount|100")

  assertTrue("contractId: nav|log != nav|warn", id1 != id2)
  assertTrue("contractId: nav != guard", id1 != id3)
  assertTrue("contractId: guard != mount", id3 != id4)
}

let testComputeContractIdNonEmpty = () => {
  Js.Console.log("\n-- computeContractId: Non-Empty Output --")

  // IDs should always be non-empty strings
  let id = K9Contract.computeContractId("anything")
  assertTrue("contractId: non-empty", Js.String2.length(id) > 0)

  // Even for empty input, should produce a valid hex string
  let emptyId = K9Contract.computeContractId("")
  assertTrue("contractId: non-empty for empty input", Js.String2.length(emptyId) > 0)
}

let testComputeContractIdHexFormat = () => {
  Js.Console.log("\n-- computeContractId: Hex Format --")

  // ID should be a hex string (only characters 0-9, a-f)
  let id = K9Contract.computeContractId("test-content")
  let isHex = Js.Re.test_(%re("/^[0-9a-f]+$/"), id)
  assertTrue("contractId: hex format", isHex)
}

// ============================================================================
// SECTION 2: Contract Constructors
// ============================================================================
//
// makeNavigationContract, makeGuardContract, makeMountContract create
// fully populated contract records with computed IDs.

let testMakeNavigationContract = () => {
  Js.Console.log("\n-- makeNavigationContract --")

  // Default breach policy is Log
  let contract = K9Contract.makeNavigationContract(20.0)
  assertEq("navContract: maxResolutionMs", contract.maxResolutionMs, 20.0)
  assertEq("navContract: default breachPolicy", contract.breachPolicy, K9Contract.Log)
  assertEq("navContract: default onBreach is None", contract.onBreach, None)
  assertTrue("navContract: has contractId", Js.String2.length(contract.contractId) > 0)

  // Custom breach policy
  let warnContract = K9Contract.makeNavigationContract(5.0, ~breachPolicy=K9Contract.Warn)
  assertEq("navContract: custom breachPolicy", warnContract.breachPolicy, K9Contract.Warn)
  assertEq("navContract: custom maxResolutionMs", warnContract.maxResolutionMs, 5.0)

  // Custom onBreach callback
  let callbackCalled = ref(false)
  let cbContract = K9Contract.makeNavigationContract(
    10.0,
    ~breachPolicy=K9Contract.Degrade,
    ~onBreach=Some((_, _) => callbackCalled := true),
  )
  assertEq("navContract: Degrade policy", cbContract.breachPolicy, K9Contract.Degrade)
  assertTrue("navContract: has onBreach callback", cbContract.onBreach != None)
}

let testMakeGuardContract = () => {
  Js.Console.log("\n-- makeGuardContract --")

  // Default breach policy for guard contracts is Warn
  let contract = K9Contract.makeGuardContract(1.0, 2000.0)
  assertEq("guardContract: maxSyncGuardMs", contract.maxSyncGuardMs, 1.0)
  assertEq("guardContract: maxAsyncGuardMs", contract.maxAsyncGuardMs, 2000.0)
  assertEq("guardContract: default breachPolicy", contract.breachPolicy, K9Contract.Warn)
  assertTrue("guardContract: has contractId", Js.String2.length(contract.contractId) > 0)
}

let testMakeMountContract = () => {
  Js.Console.log("\n-- makeMountContract --")

  // Default breach policy for mount contracts is Warn
  let contract = K9Contract.makeMountContract(100.0)
  assertEq("mountContract: maxMountMs", contract.maxMountMs, 100.0)
  assertEq("mountContract: default breachPolicy", contract.breachPolicy, K9Contract.Warn)
  assertTrue("mountContract: has contractId", Js.String2.length(contract.contractId) > 0)
}

let testContractIdsAreDeterministic = () => {
  Js.Console.log("\n-- Contract IDs: Deterministic --")

  // Two contracts with the same parameters should have the same ID
  let c1 = K9Contract.makeNavigationContract(20.0)
  let c2 = K9Contract.makeNavigationContract(20.0)
  assertEq("contractId: same nav params -> same ID", c1.contractId, c2.contractId)

  // Different parameters should produce different IDs
  let c3 = K9Contract.makeNavigationContract(5.0)
  assertTrue("contractId: different params -> different ID", c1.contractId != c3.contractId)
}

// ============================================================================
// SECTION 3: Contract Sets
// ============================================================================
//
// Contract sets bundle navigation, guard, and mount contracts for convenient
// setup. Three presets exist: emptySet, standardSet, strictSet.

let testEmptySet = () => {
  Js.Console.log("\n-- Contract Sets: Empty --")

  let set = K9Contract.emptySet
  assertEq("emptySet: no navigation", set.navigation, None)
  assertEq("emptySet: no guard", set.guard, None)
  assertEq("emptySet: no mount", set.mount, None)
}

let testStandardSet = () => {
  Js.Console.log("\n-- Contract Sets: Standard --")

  let set = K9Contract.standardSet()

  // Standard set should have all three contracts
  assertTrue("standardSet: has navigation", set.navigation != None)
  assertTrue("standardSet: has guard", set.guard != None)
  assertTrue("standardSet: has mount", set.mount != None)

  // Verify standard thresholds
  switch set.navigation {
  | Some(nav) =>
    assertEq("standardSet: nav threshold 20ms", nav.maxResolutionMs, 20.0)
    assertEq("standardSet: nav policy Warn", nav.breachPolicy, K9Contract.Warn)
  | None =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] standardSet: navigation should exist")
  }

  switch set.guard {
  | Some(guard) =>
    assertEq("standardSet: sync guard 1ms", guard.maxSyncGuardMs, 1.0)
    assertEq("standardSet: async guard 2000ms", guard.maxAsyncGuardMs, 2000.0)
    assertEq("standardSet: guard policy Warn", guard.breachPolicy, K9Contract.Warn)
  | None =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] standardSet: guard should exist")
  }

  switch set.mount {
  | Some(mount) =>
    assertEq("standardSet: mount threshold 100ms", mount.maxMountMs, 100.0)
    assertEq("standardSet: mount policy Warn", mount.breachPolicy, K9Contract.Warn)
  | None =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] standardSet: mount should exist")
  }
}

let testStrictSet = () => {
  Js.Console.log("\n-- Contract Sets: Strict --")

  let set = K9Contract.strictSet()

  // Strict set should have tighter thresholds and Degrade policy
  switch set.navigation {
  | Some(nav) =>
    assertEq("strictSet: nav threshold 5ms", nav.maxResolutionMs, 5.0)
    assertEq("strictSet: nav policy Degrade", nav.breachPolicy, K9Contract.Degrade)
  | None =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] strictSet: navigation should exist")
  }

  switch set.guard {
  | Some(guard) =>
    assertEq("strictSet: sync guard 0.5ms", guard.maxSyncGuardMs, 0.5)
    assertEq("strictSet: async guard 1000ms", guard.maxAsyncGuardMs, 1000.0)
    assertEq("strictSet: guard policy Degrade", guard.breachPolicy, K9Contract.Degrade)
  | None =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] strictSet: guard should exist")
  }

  switch set.mount {
  | Some(mount) =>
    assertEq("strictSet: mount threshold 50ms", mount.maxMountMs, 50.0)
    assertEq("strictSet: mount policy Degrade", mount.breachPolicy, K9Contract.Degrade)
  | None =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] strictSet: mount should exist")
  }
}

let testStandardSetWithCustomBreach = () => {
  Js.Console.log("\n-- Contract Sets: Standard with Custom Breach --")

  let breachCount = ref(0)
  let onBreach = Some(((_id: string, _elapsed: float)) => {
    breachCount := breachCount.contents + 1
  })

  let set = K9Contract.standardSet(~breachPolicy=K9Contract.Degrade, ~onBreach)

  // Verify custom breach policy propagated
  switch set.navigation {
  | Some(nav) =>
    assertEq("customSet: nav policy Degrade", nav.breachPolicy, K9Contract.Degrade)
    assertTrue("customSet: nav has onBreach", nav.onBreach != None)
  | None =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] customSet: navigation should exist")
  }
}

// ============================================================================
// SECTION 4: Navigation Enforcement (enforceNavigation)
// ============================================================================
//
// enforceNavigation wraps a synchronous route resolution function with
// performance.now() timing. The contractResult contains the operation's
// return value, elapsed time, breach status, and contract ID.

let testEnforceNavigationFastResolution = () => {
  Js.Console.log("\n-- enforceNavigation: Fast Resolution --")

  // Use a generous threshold (1000ms) to ensure no breach
  let contract = K9Contract.makeNavigationContract(1000.0)

  // A near-instant resolution (just return a value)
  let result = K9Contract.enforceNavigation(contract, () => Some("home"))

  assertEq("enforceNav: value", result.value, Some("home"))
  assertFalse("enforceNav: not breached", result.breached)
  assertTrue("enforceNav: elapsed >= 0", result.elapsedMs >= 0.0)
  assertEq("enforceNav: contractId matches", result.contractId, contract.contractId)
}

let testEnforceNavigationReturnsValue = () => {
  Js.Console.log("\n-- enforceNavigation: Returns Operation Value --")

  let contract = K9Contract.makeNavigationContract(1000.0)

  // The value can be any type — test with None
  let result1 = K9Contract.enforceNavigation(contract, () => None)
  assertEq("enforceNav: None value", result1.value, None)

  // Test with an integer
  let result2 = K9Contract.enforceNavigation(contract, () => 42)
  assertEq("enforceNav: integer value", result2.value, 42)

  // Test with a string
  let result3 = K9Contract.enforceNavigation(contract, () => "route-match")
  assertEq("enforceNav: string value", result3.value, "route-match")
}

let testEnforceNavigationTimingMeasurement = () => {
  Js.Console.log("\n-- enforceNavigation: Timing Measurement --")

  let contract = K9Contract.makeNavigationContract(1000.0)

  let result = K9Contract.enforceNavigation(contract, () => {
    // Do some trivial work to register a non-zero elapsed time
    let _ = Belt.Array.make(100, 0)->Belt.Array.map(x => x + 1)
    "done"
  })

  // Elapsed should be a non-negative number
  assertTrue("enforceNav: elapsed is non-negative", result.elapsedMs >= 0.0)

  // Elapsed should be reasonable (under 1 second for trivial work)
  assertTrue("enforceNav: elapsed under 1000ms", result.elapsedMs < 1000.0)
}

// ============================================================================
// SECTION 5: Sync Guard Enforcement (enforceSyncGuard)
// ============================================================================

let testEnforceSyncGuardFastEvaluation = () => {
  Js.Console.log("\n-- enforceSyncGuard: Fast Evaluation --")

  let contract = K9Contract.makeGuardContract(1000.0, 2000.0)

  let result = K9Contract.enforceSyncGuard(contract, () => true)

  assertEq("syncGuard: value", result.value, true)
  assertFalse("syncGuard: not breached", result.breached)
  assertTrue("syncGuard: elapsed >= 0", result.elapsedMs >= 0.0)
  assertEq("syncGuard: contractId", result.contractId, contract.contractId)
}

let testEnforceSyncGuardReturnsGuardResult = () => {
  Js.Console.log("\n-- enforceSyncGuard: Returns Guard Result --")

  let contract = K9Contract.makeGuardContract(1000.0, 2000.0)

  // Test with different return values to verify the value is passed through
  let result1 = K9Contract.enforceSyncGuard(contract, () => "allow")
  assertEq("syncGuard: string value", result1.value, "allow")

  let result2 = K9Contract.enforceSyncGuard(contract, () => false)
  assertEq("syncGuard: bool value", result2.value, false)
}

// ============================================================================
// SECTION 6: Async Guard Enforcement (enforceAsyncGuard)
// ============================================================================

let testEnforceAsyncGuardFastEvaluation = async () => {
  Js.Console.log("\n-- enforceAsyncGuard: Fast Evaluation --")

  let contract = K9Contract.makeGuardContract(1000.0, 5000.0)

  // Async guard that resolves immediately
  let result = await K9Contract.enforceAsyncGuard(contract, () => Promise.resolve("allowed"))

  assertEq("asyncGuard: value", result.value, "allowed")
  assertFalse("asyncGuard: not breached", result.breached)
  assertTrue("asyncGuard: elapsed >= 0", result.elapsedMs >= 0.0)
  assertEq("asyncGuard: contractId", result.contractId, contract.contractId)
}

let testEnforceAsyncGuardTimingMeasurement = async () => {
  Js.Console.log("\n-- enforceAsyncGuard: Timing Measurement --")

  let contract = K9Contract.makeGuardContract(1.0, 5000.0)

  // Async guard that resolves immediately — should be fast enough for 5000ms
  let result = await K9Contract.enforceAsyncGuard(contract, () => Promise.resolve(42))

  assertTrue("asyncGuard: elapsed is non-negative", result.elapsedMs >= 0.0)
  assertEq("asyncGuard: value is 42", result.value, 42)
}

// ============================================================================
// SECTION 7: Breach Policy Types
// ============================================================================
//
// Three breach policies exist: Log, Warn, Degrade. These determine what
// happens when a contract threshold is exceeded.

let testBreachPolicyTypes = () => {
  Js.Console.log("\n-- Breach Policy Types --")

  // Verify the three breach policy variants exist and pattern-match correctly
  let policies: array<K9Contract.breachPolicy> = [
    K9Contract.Log,
    K9Contract.Warn,
    K9Contract.Degrade,
  ]

  policies->Array.forEach(policy => {
    let label = switch policy {
    | K9Contract.Log => "Log"
    | K9Contract.Warn => "Warn"
    | K9Contract.Degrade => "Degrade"
    }
    Js.Console.log(`[PASS] breachPolicy: ${label} variant exists`)
    passed := passed.contents + 1
  })
}

let testHandleBreachLog = () => {
  Js.Console.log("\n-- handleBreach: Log Policy --")

  // handleBreach with Log policy should not throw
  // We cannot easily capture console output in this test harness,
  // but we can verify it does not crash
  K9Contract.handleBreach(
    K9Contract.Log,
    "test-id",
    "navigation",
    20.0,
    25.0,
    None,
  )
  Js.Console.log("[PASS] handleBreach: Log policy does not throw")
  passed := passed.contents + 1
}

let testHandleBreachWarnWithCallback = () => {
  Js.Console.log("\n-- handleBreach: Warn Policy with Callback --")

  let callbackData = ref(("", 0.0))

  K9Contract.handleBreach(
    K9Contract.Warn,
    "breach-id-42",
    "sync guard",
    1.0,
    5.0,
    Some((id, elapsed) => callbackData := (id, elapsed)),
  )

  let (cbId, cbElapsed) = callbackData.contents
  assertEq("handleBreach Warn: callback received ID", cbId, "breach-id-42")
  assertEq("handleBreach Warn: callback received elapsed", cbElapsed, 5.0)
}

let testHandleBreachDegradeWithCallback = () => {
  Js.Console.log("\n-- handleBreach: Degrade Policy with Callback --")

  let callbackCalled = ref(false)

  K9Contract.handleBreach(
    K9Contract.Degrade,
    "degrade-id",
    "DOM mount",
    100.0,
    250.0,
    Some((_, _) => callbackCalled := true),
  )

  assertTrue("handleBreach Degrade: callback was called", callbackCalled.contents)
}

let testHandleBreachNoCallback = () => {
  Js.Console.log("\n-- handleBreach: Warn/Degrade without Callback --")

  // Warn and Degrade with None callback should not crash
  K9Contract.handleBreach(K9Contract.Warn, "id", "test", 10.0, 20.0, None)
  Js.Console.log("[PASS] handleBreach: Warn with None callback OK")
  passed := passed.contents + 1

  K9Contract.handleBreach(K9Contract.Degrade, "id", "test", 10.0, 20.0, None)
  Js.Console.log("[PASS] handleBreach: Degrade with None callback OK")
  passed := passed.contents + 1
}

// ============================================================================
// SECTION 8: ContractResult Shape
// ============================================================================
//
// contractResult<'a> contains: value, elapsedMs, breached, contractId.

let testContractResultShape = () => {
  Js.Console.log("\n-- ContractResult: Shape --")

  let contract = K9Contract.makeNavigationContract(1000.0)
  let result = K9Contract.enforceNavigation(contract, () => "test-value")

  // Verify all fields are accessible and have correct types
  assertEq("contractResult: value field", result.value, "test-value")
  assertTrue("contractResult: elapsedMs is float", result.elapsedMs >= 0.0)
  assertFalse("contractResult: breached is bool", result.breached)
  assertTrue("contractResult: contractId is string", Js.String2.length(result.contractId) > 0)
}

// ============================================================================
// SECTION 9: Integration — Contracts with Route Parsing
// ============================================================================
//
// Demonstrate using K9 contracts to wrap actual cadre-router parsing.

let testContractWithRouteParser = () => {
  Js.Console.log("\n-- Integration: Contract with Route Parser --")

  type route = Home | User(int)

  let router = Parser.oneOf([
    Parser.top->Parser.map(_ => Home),
    Parser.s("user")->Parser.andThen(Parser.int)->Parser.map(((_, id)) => User(id)),
  ])

  let contract = K9Contract.makeNavigationContract(50.0)

  // Enforce contract around route resolution
  let result1 = K9Contract.enforceNavigation(contract, () => {
    Parser.parse(router, Url.fromString("/"))
  })
  assertEq("contract+parser: / -> Home", result1.value, Some(Home))
  assertFalse("contract+parser: / not breached", result1.breached)

  let result2 = K9Contract.enforceNavigation(contract, () => {
    Parser.parse(router, Url.fromString("/user/42"))
  })
  assertEq("contract+parser: /user/42 -> User(42)", result2.value, Some(User(42)))
  assertFalse("contract+parser: /user/42 not breached", result2.breached)

  let result3 = K9Contract.enforceNavigation(contract, () => {
    Parser.parse(router, Url.fromString("/unknown"))
  })
  assertEq("contract+parser: /unknown -> None", result3.value, None)
  assertFalse("contract+parser: /unknown not breached", result3.breached)
}

// ============================================================================
// Run All Tests
// ============================================================================

let runAll = async () => {
  Js.Console.log("\n========================================")
  Js.Console.log("  K9 SERVICE CONTRACT TESTS")
  Js.Console.log("========================================")

  passed := 0
  failed := 0

  // Contract ID generation
  testComputeContractIdDeterministic()
  testComputeContractIdDistinct()
  testComputeContractIdNonEmpty()
  testComputeContractIdHexFormat()

  // Contract constructors
  testMakeNavigationContract()
  testMakeGuardContract()
  testMakeMountContract()
  testContractIdsAreDeterministic()

  // Contract sets
  testEmptySet()
  testStandardSet()
  testStrictSet()
  testStandardSetWithCustomBreach()

  // Navigation enforcement
  testEnforceNavigationFastResolution()
  testEnforceNavigationReturnsValue()
  testEnforceNavigationTimingMeasurement()

  // Sync guard enforcement
  testEnforceSyncGuardFastEvaluation()
  testEnforceSyncGuardReturnsGuardResult()

  // Async guard enforcement
  await testEnforceAsyncGuardFastEvaluation()
  await testEnforceAsyncGuardTimingMeasurement()

  // Breach policies
  testBreachPolicyTypes()
  testHandleBreachLog()
  testHandleBreachWarnWithCallback()
  testHandleBreachDegradeWithCallback()
  testHandleBreachNoCallback()

  // ContractResult shape
  testContractResultShape()

  // Integration
  testContractWithRouteParser()

  summary()

  Js.Console.log("\n========================================")
  Js.Console.log("  K9 CONTRACT TESTS COMPLETE")
  Js.Console.log("========================================\n")
}

// Auto-run
let _ = runAll()
