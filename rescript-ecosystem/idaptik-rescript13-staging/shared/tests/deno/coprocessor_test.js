// SPDX-License-Identifier: PMPL-1.0-or-later
// Deno tests for shared/Coprocessor module
// Tests coprocessor registration, lookup, domain filtering, stub creation

import { assertEquals, assertExists, assert } from "jsr:@std/assert";
import * as Coprocessor from "../../src/Coprocessor.res.mjs";

// --- Domain.toString ---

Deno.test("Coprocessor.Domain.toString: IO domain", () => {
  assertEquals(Coprocessor.Domain.toString("IO"), "IO");
});

Deno.test("Coprocessor.Domain.toString: Vector domain", () => {
  assertEquals(Coprocessor.Domain.toString("Vector"), "Vector");
});

Deno.test("Coprocessor.Domain.toString: Quantum domain", () => {
  assertEquals(Coprocessor.Domain.toString("Quantum"), "Quantum");
});

Deno.test("Coprocessor.Domain.toString: Crypto domain", () => {
  assertEquals(Coprocessor.Domain.toString("Crypto"), "Crypto");
});

Deno.test("Coprocessor.Domain.toString: all 10 domains return correct strings", () => {
  const domains = [
    "IO", "Vector", "Tensor", "Graphics", "Physics",
    "Maths", "Quantum", "Crypto", "Audio", "Neural",
  ];
  for (const d of domains) {
    assertEquals(Coprocessor.Domain.toString(d), d);
  }
});

// --- createStub ---

Deno.test("Coprocessor.createStub: creates backend with correct id", () => {
  const stub = Coprocessor.createStub("test-io", "IO", "Test IO backend");
  assertEquals(stub.id, "test-io");
});

Deno.test("Coprocessor.createStub: creates backend with correct domain", () => {
  const stub = Coprocessor.createStub("test-vec", "Vector", "Test vector");
  assertEquals(stub.domain, "Vector");
});

Deno.test("Coprocessor.createStub: creates backend with correct description", () => {
  const stub = Coprocessor.createStub("test-desc", "Maths", "Math fallback");
  assertEquals(stub.description, "Math fallback");
});

Deno.test("Coprocessor.createStub: stats initialised to zero", () => {
  const stub = Coprocessor.createStub("test-stats", "Physics", "Physics sim");
  assertEquals(stub.stats.totalCompute, 0);
  assertEquals(stub.stats.totalMemory, 0);
  assertEquals(stub.stats.totalEnergy, 0.0);
  assertEquals(stub.stats.totalCalls, 0);
});

Deno.test("Coprocessor.createStub: isAccelerated returns false", () => {
  const stub = Coprocessor.createStub("test-accel", "Tensor", "Tensor sim");
  assertEquals(stub.isAccelerated(), false);
});

Deno.test("Coprocessor.createStub: execute returns status 0", async () => {
  const stub = Coprocessor.createStub("test-exec", "Neural", "Neural sim");
  const result = await stub.execute("test_cmd", [1, 2, 3]);
  assertEquals(result.status, 0);
  assertEquals(result.metrics.computeUnits, 10);
  assertEquals(result.metrics.memoryBytes, 1024);
});

// --- register / get / listByDomain ---

Deno.test("Coprocessor.register + get: registered backend is retrievable", () => {
  const stub = Coprocessor.createStub(
    "reg-test-1",
    "Audio",
    "Registration test",
  );
  Coprocessor.register(stub);
  const retrieved = Coprocessor.get("reg-test-1");
  assertExists(retrieved);
  assertEquals(retrieved.id, "reg-test-1");
  assertEquals(retrieved.domain, "Audio");
});

Deno.test("Coprocessor.get: non-existent id returns undefined", () => {
  const result = Coprocessor.get("nonexistent-backend-xyz");
  assertEquals(result, undefined);
});

Deno.test("Coprocessor.listByDomain: filters backends by domain", () => {
  // Register two backends for Graphics domain with unique ids
  const g1 = Coprocessor.createStub(
    "gfx-domain-test-1",
    "Graphics",
    "Graphics 1",
  );
  const g2 = Coprocessor.createStub(
    "gfx-domain-test-2",
    "Graphics",
    "Graphics 2",
  );
  Coprocessor.register(g1);
  Coprocessor.register(g2);
  const gfxBackends = Coprocessor.listByDomain("Graphics");
  // At least our two should be present
  const ourIds = gfxBackends
    .filter((b) => b.id.startsWith("gfx-domain-test"))
    .map((b) => b.id);
  assert(ourIds.includes("gfx-domain-test-1"));
  assert(ourIds.includes("gfx-domain-test-2"));
});

// --- emptyMetrics ---

Deno.test("Coprocessor.emptyMetrics: all fields are zero", () => {
  assertEquals(Coprocessor.emptyMetrics.computeUnits, 0);
  assertEquals(Coprocessor.emptyMetrics.memoryBytes, 0);
  assertEquals(Coprocessor.emptyMetrics.energyJoules, 0.0);
  assertEquals(Coprocessor.emptyMetrics.latencyMs, 0.0);
});

// --- initDefaults ---

Deno.test("Coprocessor.initDefaults: registers fallback backends for all 10 domains", () => {
  Coprocessor.initDefaults();
  const expectedIds = [
    "io-fallback",
    "vector-soft",
    "tensor-soft",
    "graphics-canvas",
    "physics-soft",
    "maths-js",
    "quantum-sim",
    "crypto-js",
    "audio-web",
    "neural-soft",
  ];
  for (const id of expectedIds) {
    const b = Coprocessor.get(id);
    assertExists(b, `Expected fallback backend "${id}" to be registered`);
  }
});
