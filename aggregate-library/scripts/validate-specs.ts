// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
/**
 * Specification Validator
 *
 * Validates that all spec files conform to the aLib specification format:
 * - Interface Signature section
 * - Behavioral Semantics section
 * - Executable Test Cases section (with valid YAML)
 */

import { walk } from "@std/fs";
import { parse as parseYaml } from "@std/yaml";
import { assert, assertEquals } from "@std/assert";

interface SpecFile {
  path: string;
  content: string;
}

interface TestCase {
  input: unknown;
  output: unknown;
  description: string;
}

const REQUIRED_SECTIONS = [
  "## Interface Signature",
  "## Behavioral Semantics",
  "## Executable Test Cases",
];

async function findSpecFiles(): Promise<SpecFile[]> {
  const specs: SpecFile[] = [];

  for await (const entry of walk("./specs", {
    exts: [".md"],
    includeFiles: true,
    includeDirs: false,
  })) {
    const content = await Deno.readTextFile(entry.path);
    specs.push({ path: entry.path, content });
  }

  return specs;
}

function validateSpecFormat(spec: SpecFile): void {
  console.log(`  Validating ${spec.path}...`);

  // Check for required sections
  for (const section of REQUIRED_SECTIONS) {
    if (!spec.content.includes(section)) {
      throw new Error(`Missing required section "${section}" in ${spec.path}`);
    }
  }

  // Extract and validate YAML test cases
  const yamlMatch = spec.content.match(/```yaml\n([\s\S]+?)\n```/);
  if (!yamlMatch) {
    throw new Error(`No YAML test cases found in ${spec.path}`);
  }

  try {
    const testData = parseYaml(yamlMatch[1]) as {
      test_cases?: TestCase[];
    };

    if (!testData.test_cases || !Array.isArray(testData.test_cases)) {
      throw new Error(`Invalid test_cases structure in ${spec.path}`);
    }

    // Validate each test case has required fields
    for (const testCase of testData.test_cases) {
      if (
        !("input" in testCase) ||
        !("output" in testCase) ||
        !("description" in testCase)
      ) {
        throw new Error(
          `Test case missing required fields in ${spec.path}: ${JSON.stringify(testCase)}`,
        );
      }
    }

    console.log(`    ✅ ${testData.test_cases.length} test cases validated`);
  } catch (error) {
    throw new Error(
      `Failed to parse YAML in ${spec.path}: ${(error as Error).message}`,
    );
  }
}

async function main() {
  console.log("🔍 Validating specification files...\n");

  const specs = await findSpecFiles();
  console.log(`Found ${specs.length} specification files\n`);

  let validCount = 0;
  const errors: string[] = [];

  for (const spec of specs) {
    try {
      validateSpecFormat(spec);
      validCount++;
    } catch (error) {
      errors.push(`❌ ${(error as Error).message}`);
    }
  }

  console.log(`\n📊 Results:`);
  console.log(`  ✅ ${validCount} specifications valid`);
  if (errors.length > 0) {
    console.log(`  ❌ ${errors.length} specifications invalid\n`);
    errors.forEach((error) => console.log(error));
    Deno.exit(1);
  } else {
    console.log(`\n✨ All specifications are valid!`);
  }
}

if (import.meta.main) {
  main();
}
