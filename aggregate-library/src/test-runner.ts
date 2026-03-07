// SPDX-License-Identifier: PMPL-1.0-or-later
// Conformance test runner for aggregate-library (aLib)
// Validates language implementations against specification test cases

import { parse as parseYaml } from "@std/yaml";
import { walk } from "@std/fs/walk";
import { join, relative } from "@std/path";

export interface TestCase {
  input: unknown[];
  output: unknown;
  description: string;
}

export interface SpecTest {
  operation: string;
  category: string;
  signature: string;
  testCases: TestCase[];
}

export interface Implementation {
  language: string;
  operations: Map<string, (...args: unknown[]) => unknown>;
}

export interface TestResult {
  operation: string;
  category: string;
  testCase: number;
  description: string;
  expected: unknown;
  actual: unknown;
  passed: boolean;
  error?: string;
}

export interface ConformanceReport {
  language: string;
  totalTests: number;
  passed: number;
  failed: number;
  skipped: number;
  results: TestResult[];
}

/**
 * Extract test cases from a specification file
 */
export async function extractTestCases(specPath: string): Promise<SpecTest | null> {
  try {
    const content = await Deno.readTextFile(specPath);
    const relativePath = relative(Deno.cwd(), specPath);
    const parts = relativePath.split("/");

    const operation = parts[parts.length - 1].replace(".md", "");
    const category = parts[parts.length - 2];

    // Extract interface signature
    const sigMatch = content.match(/## Interface Signature\s*```\s*\n([^`]+?)```/);
    const signature = sigMatch ? sigMatch[1].trim() : "";

    // Extract YAML test cases
    const yamlMatch = content.match(/```yaml\s+([\s\S]*?)```/);
    if (!yamlMatch) {
      return null;
    }

    const yamlContent = yamlMatch[1];
    const parsed = parseYaml(yamlContent) as { test_cases?: TestCase[] };

    if (!parsed.test_cases) {
      return null;
    }

    return {
      operation,
      category,
      signature,
      testCases: parsed.test_cases,
    };
  } catch (error) {
    console.error(`Failed to extract test cases from ${specPath}:`, error.message);
    return null;
  }
}

/**
 * Load all test cases from specs directory
 */
export async function loadAllTests(): Promise<Map<string, SpecTest>> {
  const tests = new Map<string, SpecTest>();
  const specsDir = join(Deno.cwd(), "specs");

  for await (const entry of walk(specsDir, { exts: [".md"] })) {
    if (entry.isFile) {
      const test = await extractTestCases(entry.path);
      if (test) {
        const key = `${test.category}/${test.operation}`;
        tests.set(key, test);
      }
    }
  }

  return tests;
}

/**
 * Run conformance tests for an implementation
 */
export async function runConformanceTests(
  implementation: Implementation,
  tests: Map<string, SpecTest>
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
      for (let i = 0; i < spec.testCases.length; i++) {
        results.push({
          operation: spec.operation,
          category: spec.category,
          testCase: i + 1,
          description: spec.testCases[i].description,
          expected: spec.testCases[i].output,
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
    for (let i = 0; i < spec.testCases.length; i++) {
      const testCase = spec.testCases[i];
      totalTests++;

      try {
        const actual = implFunc(...testCase.input);
        const testPassed = deepEqual(actual, testCase.output);

        results.push({
          operation: spec.operation,
          category: spec.category,
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
          operation: spec.operation,
          category: spec.category,
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

/**
 * Deep equality check for test results
 */
function deepEqual(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a === null || b === null) return false;
  if (typeof a !== typeof b) return false;

  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    return a.every((val, idx) => deepEqual(val, b[idx]));
  }

  if (typeof a === "object" && typeof b === "object") {
    const keysA = Object.keys(a as object);
    const keysB = Object.keys(b as object);
    if (keysA.length !== keysB.length) return false;
    return keysA.every((key) =>
      deepEqual((a as Record<string, unknown>)[key], (b as Record<string, unknown>)[key])
    );
  }

  return false;
}

/**
 * Print conformance report to console
 */
export function printReport(report: ConformanceReport): void {
  console.log("\n" + "=".repeat(70));
  console.log(`📋 Conformance Report: ${report.language}`);
  console.log("=".repeat(70));
  console.log(`Total tests: ${report.totalTests}`);
  console.log(`Passed: ${report.passed} ✅`);
  console.log(`Failed: ${report.failed} ❌`);
  console.log(`Skipped: ${report.skipped} ⏭️`);
  console.log(`Success rate: ${((report.passed / report.totalTests) * 100).toFixed(1)}%`);

  // Group results by category
  const byCategory = new Map<string, TestResult[]>();
  for (const result of report.results) {
    if (!byCategory.has(result.category)) {
      byCategory.set(result.category, []);
    }
    byCategory.get(result.category)!.push(result);
  }

  // Print results by category
  for (const [category, results] of Array.from(byCategory.entries()).sort()) {
    const categoryPassed = results.filter((r) => r.passed).length;
    const categoryTotal = results.length;
    const status = categoryPassed === categoryTotal ? "✅" : "⚠️";

    console.log(`\n${status} ${category}/ (${categoryPassed}/${categoryTotal})`);

    for (const result of results) {
      if (!result.passed) {
        const statusIcon = result.error ? "⏭️" : "❌";
        console.log(`  ${statusIcon} ${result.operation} #${result.testCase}: ${result.description}`);
        if (result.error) {
          console.log(`     Error: ${result.error}`);
        } else {
          console.log(`     Expected: ${JSON.stringify(result.expected)}`);
          console.log(`     Got: ${JSON.stringify(result.actual)}`);
        }
      }
    }
  }

  console.log("\n" + "=".repeat(70));
}

/**
 * Example usage showing how to create an implementation
 */
if (import.meta.main) {
  // Example: JavaScript/TypeScript implementation
  const jsImplementation: Implementation = {
    language: "JavaScript/TypeScript (Deno)",
    operations: new Map([
      ["arithmetic/add", (a: number, b: number) => a + b],
      ["arithmetic/subtract", (a: number, b: number) => a - b],
      ["arithmetic/multiply", (a: number, b: number) => a * b],
      ["arithmetic/divide", (a: number, b: number) => {
        if (b === 0) throw new Error("Division by zero");
        return a / b;
      }],
      ["arithmetic/modulo", (a: number, b: number) => a % b],
      ["comparison/equal", (a: unknown, b: unknown) => a === b],
      ["comparison/not_equal", (a: unknown, b: unknown) => a !== b],
      ["comparison/less_than", (a: number, b: number) => a < b],
      ["comparison/greater_than", (a: number, b: number) => a > b],
      ["comparison/less_equal", (a: number, b: number) => a <= b],
      ["comparison/greater_equal", (a: number, b: number) => a >= b],
      ["logical/and", (a: boolean, b: boolean) => a && b],
      ["logical/or", (a: boolean, b: boolean) => a || b],
      ["logical/not", (a: boolean) => !a],
      ["string/concat", (a: string, b: string) => a + b],
      ["string/length", (s: string) => s.length],
      ["string/substring", (s: string, start: number, end: number) => s.substring(start, end)],
      ["collection/map", <T, U>(arr: T[], fn: (x: T) => U) => arr.map(fn)],
      ["collection/filter", <T>(arr: T[], fn: (x: T) => boolean) => arr.filter(fn)],
      ["collection/fold", <T, U>(arr: T[], init: U, fn: (acc: U, x: T) => U) => arr.reduce(fn, init)],
      ["collection/contains", <T>(arr: T[], val: T) => arr.includes(val)],
      ["conditional/if_then_else", <T>(cond: boolean, thenVal: T, elseVal: T) => cond ? thenVal : elseVal],
    ]),
  };

  console.log("🧪 Running aLib conformance tests...\n");

  const tests = await loadAllTests();
  console.log(`Loaded ${tests.size} operation specifications with ${Array.from(tests.values()).reduce((sum, t) => sum + t.testCases.length, 0)} test cases\n`);

  const report = await runConformanceTests(jsImplementation, tests);
  printReport(report);

  // Exit with error code if any tests failed
  if (report.failed > 0) {
    Deno.exit(1);
  }
}
