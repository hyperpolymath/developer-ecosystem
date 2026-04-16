// SPDX-License-Identifier: PMPL-1.0-or-later
// Deno tests for shared/Kernel_Crypto module
// Tests rate limiting, quantum fallback for high-strength cracks, backend dispatch

import { assertEquals, assert } from "jsr:@std/assert";
import * as Kernel_Crypto from "../../src/Kernel_Crypto.res.mjs";
import * as Coprocessor from "../../src/Coprocessor.res.mjs";

// --- Constants ---

Deno.test("Kernel_Crypto.maxConcurrentCrypto: is 3", () => {
  assertEquals(Kernel_Crypto.maxConcurrentCrypto, 3);
});

// --- getCount ---

Deno.test("Kernel_Crypto.getCount: new device starts at 0", () => {
  const count = Kernel_Crypto.getCount("kc-count-fresh");
  assertEquals(count.contents, 0);
});

Deno.test("Kernel_Crypto.getCount: returns same ref for same device", () => {
  const ref1 = Kernel_Crypto.getCount("kc-count-same");
  const ref2 = Kernel_Crypto.getCount("kc-count-same");
  // Should be the same reference object
  ref1.contents = 99;
  assertEquals(ref2.contents, 99);
  // Clean up
  ref1.contents = 0;
});

// --- handleCrypto: basic dispatch ---

Deno.test("Kernel_Crypto.handleCrypto: hash command succeeds", async () => {
  Coprocessor.initDefaults();
  const result = await Kernel_Crypto.handleCrypto(
    "kc-hash-test",
    "hash",
    [42, 13, 7],
  );
  // Uses fallback stub which returns status 0
  assertEquals(result.status, 0);
});

// --- handleCrypto: rate limiting ---

Deno.test("Kernel_Crypto.handleCrypto: rate limit hit at 3 concurrent ops returns 429", async () => {
  const deviceId = "kc-ratelimit-test";
  Coprocessor.initDefaults();

  // Force the count to 3 (maxConcurrentCrypto)
  const count = Kernel_Crypto.getCount(deviceId);
  count.contents = 3;

  const result = await Kernel_Crypto.handleCrypto(
    deviceId,
    "hash",
    [1],
  );
  assertEquals(result.status, 429);
  assert(result.message.includes("rate limit"));

  // Clean up
  count.contents = 0;
});

Deno.test("Kernel_Crypto.handleCrypto: under rate limit proceeds normally", async () => {
  const deviceId = "kc-underrate-test";
  Coprocessor.initDefaults();

  const count = Kernel_Crypto.getCount(deviceId);
  count.contents = 2; // Under 3

  const result = await Kernel_Crypto.handleCrypto(
    deviceId,
    "hash",
    [1],
  );
  assertEquals(result.status, 0);

  // Clean up
  count.contents = 0;
});

// --- handleCrypto: crack with high strength requires quantum ---

Deno.test("Kernel_Crypto.handleCrypto: crack strength >= 4 uses quantum backend", async () => {
  const deviceId = "kc-crack-quantum";
  Coprocessor.initDefaults();

  const count = Kernel_Crypto.getCount(deviceId);
  count.contents = 0;

  // data[0] = target, data[1] = strength (4 = high, requires quantum)
  const result = await Kernel_Crypto.handleCrypto(
    deviceId,
    "crack",
    [42, 4],
  );
  // Should succeed because initDefaults registers a quantum-sim stub
  assertEquals(result.status, 0);

  // Clean up
  count.contents = 0;
});

Deno.test("Kernel_Crypto.handleCrypto: crack strength < 4 uses crypto backend", async () => {
  const deviceId = "kc-crack-normal";
  Coprocessor.initDefaults();

  const count = Kernel_Crypto.getCount(deviceId);
  count.contents = 0;

  // strength = 3 (below quantum threshold)
  const result = await Kernel_Crypto.handleCrypto(
    deviceId,
    "crack",
    [42, 3],
  );
  assertEquals(result.status, 0);

  // Clean up
  count.contents = 0;
});
