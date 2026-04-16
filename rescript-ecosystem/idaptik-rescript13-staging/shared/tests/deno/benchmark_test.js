// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell
//
// shared/tests/deno/benchmark_test.js
// Benchmark (performance baseline) tests for IDApTIK shared coprocessor modules.
//
// CRG Grade C benchmark category: each test asserts a timing budget.
//
// Coprocessor.res.mjs has no external imports and can be loaded directly.
// Coprocessor_IO.res.mjs depends on @rescript/core (requires full npm install),
// so IO benchmarks use inline reference implementations of the pure functions
// being measured — identical in semantics to the compiled ReScript output.
//
// Baselines measured:
//   B1 - Domain.toString repeated calls
//   B2 - decodePath reference implementation (8, 256, 1024 bytes)
//   B3 - encodePath reference implementation
//   B4 - splitAtNull reference implementation on a large payload
//   B5 - decodePath → encodePath roundtrip
//   B6 - Throughput: 10,000 decodePath calls

import { assert } from "jsr:@std/assert";
import * as Cp from "../../../src/shared/Coprocessor.res.mjs";

// ---------------------------------------------------------------------------
// Reference implementations (match compiled ReScript in Coprocessor_IO.res.mjs)
// These are inlined here so the benchmarks run without @rescript/core.
// ---------------------------------------------------------------------------

/**
 * Decode a byte array to an ASCII string, stopping at the first null byte
 * and skipping bytes >= 128.  Matches Coprocessor_IO.decodePath behaviour.
 * @param {number[]} bytes
 * @returns {string}
 */
function refDecodePath(bytes) {
  let result = "";
  for (const b of bytes) {
    if (b === 0) break;
    if (b < 128) result += String.fromCharCode(b);
  }
  return result;
}

/**
 * Encode a string to a byte array of char codes.
 * Matches Coprocessor_IO.encodePath behaviour.
 * @param {string} s
 * @returns {number[]}
 */
function refEncodePath(s) {
  return [...s].map((c) => c.charCodeAt(0));
}

/**
 * Split a byte array at the first null byte.
 * Returns [before, after] where `after` excludes the null byte.
 * @param {number[]} bytes
 * @returns {[number[], number[]]}
 */
function refSplitAtNull(bytes) {
  const nullIdx = bytes.indexOf(0);
  if (nullIdx === -1) return [bytes, []];
  return [bytes.slice(0, nullIdx), bytes.slice(nullIdx + 1)];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Run `fn` `iterations` times and return the median elapsed time in ms.
 * @param {() => void} fn
 * @param {number} iterations
 * @returns {number}
 */
function median(fn, iterations = 100) {
  const samples = [];
  for (let i = 0; i < iterations; i++) {
    const t0 = performance.now();
    fn();
    samples.push(performance.now() - t0);
  }
  samples.sort((a, b) => a - b);
  return samples[Math.floor(samples.length / 2)];
}

/**
 * Build a byte array from an ASCII string.
 * @param {string} s
 * @returns {number[]}
 */
function asciiBytes(s) {
  return [...s].map((c) => c.charCodeAt(0));
}

// ---------------------------------------------------------------------------
// B1: Coprocessor.Domain.toString — loaded directly from compiled ReScript
// ---------------------------------------------------------------------------

Deno.test("benchmark B1a: Domain.toString 1000 calls complete in < 10ms", () => {
  const domains = ["IO", "Vector", "Quantum", "Crypto", "Compute"];
  const t0 = performance.now();

  for (let i = 0; i < 1000; i++) {
    Cp.Domain.toString(domains[i % domains.length]);
  }

  const elapsed = performance.now() - t0;
  assert(elapsed < 10, `1000x Domain.toString: ${elapsed.toFixed(2)}ms (limit: 10ms)`);
});

Deno.test("benchmark B1b: Domain.toString median per-call < 0.01ms", () => {
  const elapsed = median(() => Cp.Domain.toString("IO"), 1000);
  assert(
    elapsed < 0.01,
    `Domain.toString median: ${elapsed.toFixed(4)}ms (limit: 0.01ms)`,
  );
});

// ---------------------------------------------------------------------------
// B2: decodePath reference implementation
// ---------------------------------------------------------------------------

Deno.test("benchmark B2a: decodePath 8-byte payload median < 0.01ms", () => {
  const payload = asciiBytes("hello/xy");
  const elapsed = median(() => refDecodePath(payload), 1000);
  assert(elapsed < 0.01, `decodePath 8B: median=${elapsed.toFixed(4)}ms (limit: 0.01ms)`);
});

Deno.test("benchmark B2b: decodePath 256-byte payload median < 0.1ms", () => {
  const payload = asciiBytes("a".repeat(256));
  const elapsed = median(() => refDecodePath(payload), 500);
  assert(elapsed < 0.1, `decodePath 256B: median=${elapsed.toFixed(4)}ms (limit: 0.1ms)`);
});

Deno.test("benchmark B2c: decodePath 1024-byte payload median < 0.5ms", () => {
  const payload = asciiBytes("b".repeat(1024));
  const elapsed = median(() => refDecodePath(payload), 200);
  assert(elapsed < 0.5, `decodePath 1024B: median=${elapsed.toFixed(4)}ms (limit: 0.5ms)`);
});

// ---------------------------------------------------------------------------
// B3: encodePath reference implementation
// ---------------------------------------------------------------------------

Deno.test("benchmark B3a: encodePath 8-char string median < 0.01ms", () => {
  const elapsed = median(() => refEncodePath("hello/xy"), 1000);
  assert(elapsed < 0.01, `encodePath 8ch: median=${elapsed.toFixed(4)}ms (limit: 0.01ms)`);
});

Deno.test("benchmark B3b: encodePath 256-char string median < 0.1ms", () => {
  const s = "z".repeat(256);
  const elapsed = median(() => refEncodePath(s), 500);
  assert(elapsed < 0.1, `encodePath 256ch: median=${elapsed.toFixed(4)}ms (limit: 0.1ms)`);
});

// ---------------------------------------------------------------------------
// B4: splitAtNull on a large payload
// ---------------------------------------------------------------------------

Deno.test("benchmark B4: splitAtNull on 512-byte payload median < 0.2ms", () => {
  const path = asciiBytes("path/to/file.dat");
  const content = new Array(448).fill(7);
  const payload = [...path, 0, ...content];

  const elapsed = median(() => refSplitAtNull(payload), 200);
  assert(elapsed < 0.2, `splitAtNull 512B: median=${elapsed.toFixed(4)}ms (limit: 0.2ms)`);
});

// ---------------------------------------------------------------------------
// B5: decodePath → encodePath roundtrip
// ---------------------------------------------------------------------------

Deno.test("benchmark B5: decodePath → encodePath roundtrip (128-char) median < 0.1ms", () => {
  const original = "c".repeat(128);
  const encoded = refEncodePath(original);

  const elapsed = median(() => {
    const decoded = refDecodePath(encoded);
    refEncodePath(decoded);
  }, 500);

  assert(elapsed < 0.1, `roundtrip 128ch: median=${elapsed.toFixed(4)}ms (limit: 0.1ms)`);
});

// ---------------------------------------------------------------------------
// B6: Throughput — 10,000 decodePath calls
// ---------------------------------------------------------------------------

Deno.test("benchmark B6: decodePath throughput — 10,000 calls in < 50ms", () => {
  const payload = asciiBytes("img/sprite/hero.png");
  const t0 = performance.now();

  for (let i = 0; i < 10_000; i++) {
    refDecodePath(payload);
  }

  const elapsed = performance.now() - t0;
  assert(elapsed < 50, `10,000x decodePath: ${elapsed.toFixed(2)}ms (limit: 50ms)`);
});
