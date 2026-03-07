#!/usr/bin/env -S deno run --allow-read
// SPDX-License-Identifier: PMPL-1.0-or-later
// Run conformance tests for aggregate-library implementations

import {
  extractTestCases,
  loadAllTests,
  type Implementation,
  type ConformanceReport,
  type TestResult,
} from "../src/test-runner.ts";

/**
 * Reference ReScript implementation adapter
 * Maps spec operation names to ReScript implementation
 */
function createReferenceImplementation(): Implementation {
  // Import the compiled ReScript module (in production)
  // For now, create JavaScript equivalents that match ReScript semantics

  return {
    language: "ReScript (Reference)",
    operations: new Map([
      // Arithmetic
      ["arithmetic/add", (a: number, b: number) => a + b],
      ["arithmetic/subtract", (a: number, b: number) => a - b],
      ["arithmetic/multiply", (a: number, b: number) => a * b],
      ["arithmetic/divide", (a: number, b: number) => a / b],
      ["arithmetic/modulo", (a: number, b: number) => a % b],

      // Comparison
      ["comparison/equal", (a: unknown, b: unknown) => a === b],
      ["comparison/not_equal", (a: unknown, b: unknown) => a !== b],
      ["comparison/less_than", (a: number, b: number) => a < b],
      ["comparison/less_equal", (a: number, b: number) => a <= b],
      ["comparison/greater_than", (a: number, b: number) => a > b],
      ["comparison/greater_equal", (a: number, b: number) => a >= b],

      // Logical
      ["logical/and", (a: boolean, b: boolean) => a && b],
      ["logical/or", (a: boolean, b: boolean) => a || b],
      ["logical/not", (a: boolean) => !a],

      // Collection
      ["collection/map", (arr: unknown[], fn: (x: unknown) => unknown) => arr.map(fn)],
      ["collection/filter", (arr: unknown[], pred: (x: unknown) => boolean) => arr.filter(pred)],
      ["collection/fold", (arr: unknown[], init: unknown, fn: (acc: unknown, x: unknown) => unknown) =>
        arr.reduce(fn, init)],
      ["collection/contains", (arr: unknown[], elem: unknown) => arr.some(x => x === elem)],

      // String
      ["string/concat", (a: string, b: string) => a + b],
      ["string/length", (s: string) => s.length],
      ["string/substring", (s: string, start: number, end: number) => s.substring(start, end)],

      // Conditional
      ["conditional/if_then_else", (
        cond: boolean,
        thenFn: () => unknown,
        elseFn: () => unknown
      ) => cond ? thenFn() : elseFn()],
    ]),
  };
}

/**
 * Run conformance tests and generate report
 */
async function runConformanceTests(
  implementation: Implementation,
  tests: Map<string, unknown>
): Promise<ConformanceReport> {
  const results: TestResult[] = [];
  let totalTests = 0;
  let passed = 0;
  let failed = 0;
  let skipped = 0;

  for (const [key, spec] of tests) {
    const implFunc = implementation.operations.get(key);

    if (!implFunc) {
      // Skip if implementation doesn't provide this operation
      for (let i = 0; i < (spec as { testCases: unknown[] }).testCases.length; i++) {
        const testCase = (spec as { testCases: { description: string; output: unknown }[] }).testCases[i];
        results.push({
          operation: key.split("/")[1],
          category: key.split("/")[0],
          testCase: i + 1,
          description: testCase.description,
          expected: testCase.output,
          actual: undefined,
          passed: false,
          error: "Operation not implemented",
        });
        skipped++;
        totalTests++;
      }
      continue;
    }

    // Run each test case
    for (let i = 0; i < (spec as { testCases: unknown[] }).testCases.length; i++) {
      const testCase = (spec as { testCases: { input: unknown[]; output: unknown; description: string }[] }).testCases[i];
      totalTests++;

      try {
        const actual = implFunc(...testCase.input);
        const testPassed = deepEqual(actual, testCase.output);

        results.push({
          operation: key.split("/")[1],
          category: key.split("/")[0],
          testCase: i + 1,
          description: testCase.description,
          expected: testCase.output,
          actual,
          passed: testPassed,
        });

        if (testPassed) {
          passed++;
        } else {
          failed++;
        }
      } catch (error) {
        results.push({
          operation: key.split("/")[1],
          category: key.split("/")[0],
          testCase: i + 1,
          description: testCase.description,
          expected: testCase.output,
          actual: undefined,
          passed: false,
          error: error.message,
        });
        failed++;
      }
    }
  }

  return {
    language: implementation.language,
    totalTests,
    passed,
    failed,
    skipped,
    results,
  };
}

function deepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a !== typeof b) return false;
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    return a.every((val, idx) => deepEqual(val, b[idx]));
  }
  if (typeof a === "object" && a !== null && b !== null) {
    const aKeys = Object.keys(a);
    const bKeys = Object.keys(b);
    if (aKeys.length !== bKeys.length) return false;
    return aKeys.every(key => deepEqual((a as Record<string, unknown>)[key], (b as Record<string, unknown>)[key]));
  }
  // Handle floating point comparison with tolerance
  if (typeof a === "number" && typeof b === "number") {
    return Math.abs(a - b) < 1e-10;
  }
  return false;
}

function printReport(report: ConformanceReport) {
  console.log("\n" + "=".repeat(80));
  console.log(`Conformance Report: ${report.language}`);
  console.log("=".repeat(80));
  console.log(`Total Tests: ${report.totalTests}`);
  console.log(`Passed: ${report.passed} (${(report.passed / report.totalTests * 100).toFixed(1)}%)`);
  console.log(`Failed: ${report.failed}`);
  console.log(`Skipped: ${report.skipped}`);
  console.log("=".repeat(80));

  const failedTests = report.results.filter(r => !r.passed);
  if (failedTests.length > 0) {
    console.log("\nFailed Tests:");
    console.log("-".repeat(80));
    for (const result of failedTests) {
      console.log(`\n${result.category}/${result.operation} - Test #${result.testCase}`);
      console.log(`  Description: ${result.description}`);
      console.log(`  Expected: ${JSON.stringify(result.expected)}`);
      console.log(`  Actual: ${JSON.stringify(result.actual)}`);
      if (result.error) {
        console.log(`  Error: ${result.error}`);
      }
    }
  } else {
    console.log("\n✓ All tests passed!");
  }

  console.log("\n" + "=".repeat(80));
}

// Main execution
if (import.meta.main) {
  console.log("Loading test specifications...");
  const tests = await loadAllTests();
  console.log(`Loaded ${tests.size} operation specs with test cases`);

  console.log("\nRunning conformance tests for Reference Implementation...");
  const impl = createReferenceImplementation();
  const report = await runConformanceTests(impl, tests);

  printReport(report);

  // Exit with error code if any tests failed
  if (report.failed > 0) {
    Deno.exit(1);
  }
}
