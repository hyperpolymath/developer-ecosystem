// SPDX-License-Identifier: PLMP-1.0-or-later
// Benchmark suite proving zero-cost abstractions

import { Email, Slug, NonEmptyString } from "../../src/Common/Alib_String.res.js";

// Baseline: Plain string operations
const plainStringValidation = (input) => {
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input)) {
    return input;
  }
  throw new Error("Invalid");
};

// Branded type: Alib.String.Email
const brandedTypeValidation = (input) => {
  const result = Email.parse(input);
  if (result.TAG === "Ok") {
    return Email.reveal(result._0);
  }
  throw new Error("Invalid");
};

// Test data
const validEmail = "user@example.com";
const invalidEmail = "not-an-email";

// Benchmark: Parse overhead
Deno.bench("Baseline: Plain regex validation", { group: "parse" }, () => {
  try {
    plainStringValidation(validEmail);
  } catch (_) {}
});

Deno.bench("Branded: Email.parse() validation", { group: "parse" }, () => {
  const result = Email.parse(validEmail);
  if (result.TAG === "Ok") {
    Email.reveal(result._0);
  }
});

// Benchmark: Reveal overhead (should be 0%)
Deno.bench("Baseline: Identity function", { group: "reveal" }, () => {
  const x = validEmail;
  const y = x; // Identity operation
  return y;
});

Deno.bench("Branded: Email.reveal()", { group: "reveal" }, () => {
  const email = Email.parse(validEmail);
  if (email.TAG === "Ok") {
    const revealed = Email.reveal(email._0);
    return revealed;
  }
});

// Benchmark: Hot path usage (real-world scenario)
Deno.bench("Baseline: Validate + use (plain)", { group: "hotpath" }, () => {
  const emails = [
    "alice@example.com",
    "bob@example.com",
    "charlie@example.com",
  ];

  const valid = emails.filter(e => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e));
  return valid.map(e => e.toLowerCase());
});

Deno.bench("Branded: Validate + use (typed)", { group: "hotpath" }, () => {
  const emails = [
    "alice@example.com",
    "bob@example.com",
    "charlie@example.com",
  ];

  const valid = emails
    .map(e => Email.parse(e))
    .filter(r => r.TAG === "Ok")
    .map(r => Email.reveal(r._0).toLowerCase());
  return valid;
});

// Benchmark: Slug validation
Deno.bench("Slug: Valid parse", () => {
  const result = Slug.parse("valid-kebab-slug");
  if (result.TAG === "Ok") {
    Slug.reveal(result._0);
  }
});

Deno.bench("Slug: Invalid parse", () => {
  const result = Slug.parse("Invalid_Slug");
  // Should be Error
});

// Benchmark: NonEmptyString
Deno.bench("NonEmptyString: Valid", () => {
  const result = NonEmptyString.parse("hello");
  if (result.TAG === "Ok") {
    NonEmptyString.reveal(result._0);
  }
});

Deno.bench("NonEmptyString: Invalid", () => {
  const result = NonEmptyString.parse("");
  // Should be Error
});

// Summary function (run after benchmarks)
console.log("\n=== Zero-Cost Claims ===");
console.log("Target: Parse overhead <= 5%");
console.log("Target: Reveal overhead == 0%");
console.log("\nRun: deno bench test/benchmark/string_benchmark.js");
console.log("Compare 'Baseline' vs 'Branded' groups");
