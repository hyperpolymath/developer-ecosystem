// SPDX-License-Identifier: Apache-2.0
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

Js.Console.log("")
Js.Console.log("+========================================+")
Js.Console.log("|     All Tests Complete                |")
Js.Console.log("+========================================+")
