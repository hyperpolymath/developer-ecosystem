// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell
//
// aLib Conformance Test Runner
//
// Parses aLib specification YAML files and runs conformance tests
// against language implementations.

module TestCase = {
  type t = {
    input: array<Js.Json.t>,
    output: Js.Json.t,
    description: string,
  }
}

module Spec = {
  type t = {
    operation: string,
    signature: string,
    testCases: array<TestCase.t>,
  }

  // Parse a specification markdown file
  let parseSpecFile = (filePath: string): option<t> => {
    // Read file content
    // Extract YAML test_cases block
    // Parse YAML into test case structures
    None // Placeholder
  }
}

module Runner = {
  type result =
    | Pass
    | Fail(string)

  type testResult = {
    operation: string,
    caseDescription: string,
    result: result,
  }

  // Run a single test case against an implementation
  let runTestCase = (
    ~operation: string,
    ~testCase: TestCase.t,
    ~implementation: array<Js.Json.t> => Js.Json.t,
  ): testResult => {
    let result = try {
      let output = implementation(testCase.input)
      if Js.Json.stringify(output) == Js.Json.stringify(testCase.output) {
        Pass
      } else {
        Fail(`Expected ${Js.Json.stringify(testCase.output)}, got ${Js.Json.stringify(output)}`)
      }
    } catch {
    | exn => Fail(`Exception: ${exn->Js.Exn.asJsExn->Belt.Option.getExn->Js.Exn.message->Belt.Option.getExn}`)
    }

    {
      operation,
      caseDescription: testCase.description,
      result,
    }
  }

  // Run all test cases for a spec
  let runSpec = (
    ~spec: Spec.t,
    ~implementation: array<Js.Json.t> => Js.Json.t,
  ): array<testResult> => {
    spec.testCases->Js.Array2.map(testCase =>
      runTestCase(~operation=spec.operation, ~testCase, ~implementation)
    )
  }

  // Format results for output
  let formatResults = (results: array<testResult>): string => {
    let passed = results->Js.Array2.filter(r => r.result == Pass)->Js.Array2.length
    let total = results->Js.Array2.length

    let summary = `\n=== Conformance Test Results ===\nPassed: ${passed->Belt.Int.toString}/${total->Belt.Int.toString}\n\n`

    let details = results->Js.Array2.map(r => {
      let status = switch r.result {
      | Pass => "✓ PASS"
      | Fail(msg) => `✗ FAIL: ${msg}`
      }
      `${r.operation} - ${r.caseDescription}: ${status}`
    })->Js.Array2.joinWith("\n")

    summary ++ details
  }
}

// CLI entry point
let main = () => {
  Js.log("aLib Conformance Test Runner")
  Js.log("Usage: conformance_runner <spec-dir> <impl-lang>")
}
