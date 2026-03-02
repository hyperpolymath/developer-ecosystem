// SPDX-License-Identifier: PMPL-1.0-or-later
// run_tests.res - Test runner for all modules

Js.Console.log("+========================================+")
Js.Console.log("|     cadre-router Test Suite           |")
Js.Console.log("+========================================+")
Js.Console.log("")

// Run all test modules
// Each module auto-runs on import

Js.Console.log("Loading Url_test...")
let _ = Url_test.runAll

Js.Console.log("\nLoading Parser_test...")
let _ = Parser_test.runAll

Js.Console.log("\nLoading Navigation_test...")
let _ = Navigation_test.runAll

Js.Console.log("\nLoading RouteBuilder_test...")
let _ = RouteBuilder_test.runAll

Js.Console.log("\nLoading Conformance_test...")
let _ = Conformance_test.runAll

// v0.4 Security Hardening Tests
Js.Console.log("\nLoading Sanitisation_test...")
let _ = Sanitisation_test.runAll

Js.Console.log("\nLoading GroupedRouting_test...")
let _ = GroupedRouting_test.runAll

// Async test modules — GuardTimeout_test and K9Contract_test have async
// runAll functions. Their auto-run triggers on import (the `let _ = runAll()`
// at module bottom). Referencing the module here ensures the import occurs.
Js.Console.log("\nLoading GuardTimeout_test (async)...")
let _ = GuardTimeout_test.runAll

Js.Console.log("\nLoading K9Contract_test (async)...")
let _ = K9Contract_test.runAll

// Transition and route structure tests
Js.Console.log("\nLoading Transition_test...")
let _ = Transition_test.runTests

Js.Console.log("\nLoading CssTransition_test...")
let _ = CssTransition_test.runAll

Js.Console.log("\nLoading NestedRoute_test...")
let _ = NestedRoute_test.runTests

Js.Console.log("\nLoading RouteMeta_test...")
let _ = RouteMeta_test.runTests

// Performance benchmarks — oneOf vs oneOfGrouped across 10/50/100 route sets
Js.Console.log("\nLoading Benchmark_test...")
let _ = Benchmark_test.runAll

// NOTE: ServerRouter_test is excluded because src/server is not in
// rescript.json sources. Add it when server sources are included.

Js.Console.log("")
Js.Console.log("+========================================+")
Js.Console.log("|     All Tests Complete                |")
Js.Console.log("+========================================+")
