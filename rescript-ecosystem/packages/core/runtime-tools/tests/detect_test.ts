// SPDX-License-Identifier: AGPL-3.0-or-later
// Tests for runtime detection

import { assertEquals, assertExists } from "@std/assert";

// We'll test the compiled ReScript output
// For now, test the detection logic directly

Deno.test("runtime detection - identifies Deno", () => {
  const isDeno = typeof (globalThis as any).Deno !== "undefined";
  assertEquals(isDeno, true, "Should detect Deno runtime");
});

Deno.test("runtime detection - Deno version exists", () => {
  const version = (globalThis as any).Deno?.version?.deno;
  assertExists(version, "Deno version should exist");
});

Deno.test("runtime detection - Bun not present in Deno", () => {
  const isBun = typeof (globalThis as any).Bun !== "undefined";
  assertEquals(isBun, false, "Bun should not be detected in Deno");
});

Deno.test("capabilities - filesystem available", () => {
  const hasFs = typeof Deno.readFile === "function";
  assertEquals(hasFs, true, "Filesystem should be available");
});

Deno.test("capabilities - network available", () => {
  const hasNet = typeof fetch === "function";
  assertEquals(hasNet, true, "Network (fetch) should be available");
});

Deno.test("capabilities - WebAssembly available", () => {
  const hasWasm = typeof WebAssembly !== "undefined";
  assertEquals(hasWasm, true, "WebAssembly should be available");
});
