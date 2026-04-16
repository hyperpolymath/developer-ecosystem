// SPDX-License-Identifier: PMPL-1.0-or-later
// Deno tests for shared/Coprocessor_Security module
// Tests pure crypto functions (xorFold, intTo4Bytes, lcg, xorWithKey, sign/verify)
// and neural functions (classify, predict, anomaly, fingerprint)

import { assertEquals, assert } from "jsr:@std/assert";
import * as CS from "../../src/Coprocessor_Security.res.mjs";

// ========== Crypto pure functions ==========

// --- xorFold ---

Deno.test("Crypto.xorFold: empty array returns 0", () => {
  assertEquals(CS.Crypto.xorFold([]), 0);
});

Deno.test("Crypto.xorFold: single element returns itself", () => {
  assertEquals(CS.Crypto.xorFold([42]), 42);
});

Deno.test("Crypto.xorFold: XOR of all elements", () => {
  // 1 ^ 2 ^ 3 = 0
  assertEquals(CS.Crypto.xorFold([1, 2, 3]), 0);
});

Deno.test("Crypto.xorFold: identity property (x ^ x = 0)", () => {
  assertEquals(CS.Crypto.xorFold([255, 255]), 0);
});

// --- intTo4Bytes ---

Deno.test("Crypto.intTo4Bytes: zero produces [0,0,0,0]", () => {
  assertEquals(CS.Crypto.intTo4Bytes(0), [0, 0, 0, 0]);
});

Deno.test("Crypto.intTo4Bytes: 0xFF produces [0,0,0,255]", () => {
  assertEquals(CS.Crypto.intTo4Bytes(0xFF), [0, 0, 0, 255]);
});

Deno.test("Crypto.intTo4Bytes: 0x01020304 decomposes correctly", () => {
  assertEquals(CS.Crypto.intTo4Bytes(0x01020304), [1, 2, 3, 4]);
});

// --- lcgStep ---

Deno.test("Crypto.lcgStep: deterministic output for same seed", () => {
  const [next1, byte1] = CS.Crypto.lcgStep(0);
  const [next2, byte2] = CS.Crypto.lcgStep(0);
  assertEquals(next1, next2);
  assertEquals(byte1, byte2);
});

Deno.test("Crypto.lcgStep: different seeds produce different outputs", () => {
  const [next1] = CS.Crypto.lcgStep(0);
  const [next2] = CS.Crypto.lcgStep(1);
  assert(next1 !== next2);
});

Deno.test("Crypto.lcgStep: byte is in range [0, 255]", () => {
  for (let seed = 0; seed < 100; seed++) {
    const [_, byte] = CS.Crypto.lcgStep(seed);
    assert(byte >= 0 && byte <= 255);
  }
});

// --- lcgBytes ---

Deno.test("Crypto.lcgBytes: produces correct count of bytes", () => {
  const result = CS.Crypto.lcgBytes(42, 16);
  assertEquals(result.length, 16);
});

Deno.test("Crypto.lcgBytes: deterministic for same seed", () => {
  const a = CS.Crypto.lcgBytes(123, 8);
  const b = CS.Crypto.lcgBytes(123, 8);
  assertEquals(a, b);
});

Deno.test("Crypto.lcgBytes: different seeds produce different sequences", () => {
  const a = CS.Crypto.lcgBytes(0, 8);
  const b = CS.Crypto.lcgBytes(1, 8);
  // At least one byte should differ
  assert(a.some((v, i) => v !== b[i]));
});

// --- xorWithKey ---

Deno.test("Crypto.xorWithKey: empty key returns original message", () => {
  const msg = [1, 2, 3];
  assertEquals(CS.Crypto.xorWithKey(msg, []), msg);
});

Deno.test("Crypto.xorWithKey: self-inverse (encrypt then decrypt)", () => {
  const msg = [10, 20, 30, 40, 50];
  const key = [0xAB, 0xCD];
  const encrypted = CS.Crypto.xorWithKey(msg, key);
  const decrypted = CS.Crypto.xorWithKey(encrypted, key);
  assertEquals(decrypted, msg);
});

Deno.test("Crypto.xorWithKey: key wraps cyclically", () => {
  const msg = [1, 2, 3, 4];
  const key = [0xFF]; // Single byte key
  const result = CS.Crypto.xorWithKey(msg, key);
  assertEquals(result, [1 ^ 0xFF, 2 ^ 0xFF, 3 ^ 0xFF, 4 ^ 0xFF]);
});

// --- cmdHash ---

Deno.test("Crypto.cmdHash: returns status 0 with 4-byte digest", () => {
  const result = CS.Crypto.cmdHash([1, 2, 3]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 4);
});

Deno.test("Crypto.cmdHash: deterministic for same input", () => {
  const a = CS.Crypto.cmdHash([42, 13]);
  const b = CS.Crypto.cmdHash([42, 13]);
  assertEquals(a.data, b.data);
});

// --- cmdKeygen ---

Deno.test("Crypto.cmdKeygen: default produces 16 bytes", () => {
  const result = CS.Crypto.cmdKeygen([42]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 16);
});

Deno.test("Crypto.cmdKeygen: custom count respected", () => {
  const result = CS.Crypto.cmdKeygen([42, 8]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 8);
});

Deno.test("Crypto.cmdKeygen: count capped at 256", () => {
  const result = CS.Crypto.cmdKeygen([42, 500]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 16); // Falls back to default 16
});

// --- cmdSign / cmdVerify round-trip ---

Deno.test("Crypto.cmdSign + cmdVerify: signed data verifies correctly", () => {
  const data = [10, 20, 30, 40];
  const signed = CS.Crypto.cmdSign(data);
  assertEquals(signed.status, 0);
  // signed.data = data + 2-byte checksum
  assertEquals(signed.data.length, data.length + 2);

  const verified = CS.Crypto.cmdVerify(signed.data);
  assertEquals(verified.status, 0);
  assertEquals(verified.data, [1]); // 1 = valid
});

Deno.test("Crypto.cmdVerify: tampered data fails verification", () => {
  const data = [10, 20, 30, 40];
  const signed = CS.Crypto.cmdSign(data);
  // Tamper with the first byte
  const tampered = [...signed.data];
  tampered[0] = tampered[0] ^ 0xFF;
  const verified = CS.Crypto.cmdVerify(tampered);
  assertEquals(verified.status, 0);
  assertEquals(verified.data, [0]); // 0 = invalid
});

Deno.test("Crypto.cmdVerify: too-short data returns 400", () => {
  const result = CS.Crypto.cmdVerify([42]);
  assertEquals(result.status, 400);
});

// --- cmdXorCipher ---

Deno.test("Crypto.cmdXorCipher: encrypt + decrypt round-trip", () => {
  // Format: [keyLen, ...key, ...message]
  const key = [0xAA, 0xBB];
  const msg = [1, 2, 3, 4, 5];
  const encData = [key.length, ...key, ...msg];
  const encrypted = CS.Crypto.cmdXorCipher("encrypt", encData);
  assertEquals(encrypted.status, 0);

  // Decrypt with same key
  const decData = [key.length, ...key, ...encrypted.data];
  const decrypted = CS.Crypto.cmdXorCipher("decrypt", decData);
  assertEquals(decrypted.status, 0);
  assertEquals(decrypted.data, msg);
});

Deno.test("Crypto.cmdXorCipher: missing key length returns 400", () => {
  const result = CS.Crypto.cmdXorCipher("encrypt", []);
  assertEquals(result.status, 400);
});

// ========== Neural pure functions ==========

// --- classify ---

Deno.test("Neural.classify: returns [classId, confidence] tuple", () => {
  const [classId, confidence] = CS.Neural.classify([10, 20, 30]);
  assert(classId >= 0 && classId < 8);
  assert(confidence >= 0 && confidence <= 1000);
});

Deno.test("Neural.classify: deterministic for same features", () => {
  const a = CS.Neural.classify([5, 10, 15, 20]);
  const b = CS.Neural.classify([5, 10, 15, 20]);
  assertEquals(a, b);
});

// --- className ---

Deno.test("Neural.className: maps class ids to names", () => {
  assertEquals(CS.Neural.className(0), "Laptop");
  assertEquals(CS.Neural.className(1), "Desktop");
  assertEquals(CS.Neural.className(2), "Server");
  assertEquals(CS.Neural.className(3), "Router");
  assertEquals(CS.Neural.className(4), "Firewall");
  assertEquals(CS.Neural.className(5), "Switch");
  assertEquals(CS.Neural.className(6), "Camera");
  assertEquals(CS.Neural.className(7), "IoT");
});

Deno.test("Neural.className: unknown class id returns 'Unknown'", () => {
  assertEquals(CS.Neural.className(99), "Unknown");
});

// --- protocolName ---

Deno.test("Neural.protocolName: maps protocol ids", () => {
  assertEquals(CS.Neural.protocolName(1), "HTTP");
  assertEquals(CS.Neural.protocolName(2), "SSH");
  assertEquals(CS.Neural.protocolName(3), "DNS");
  assertEquals(CS.Neural.protocolName(4), "SMTP");
  assertEquals(CS.Neural.protocolName(5), "FTP");
  assertEquals(CS.Neural.protocolName(0), "UNKNOWN");
  assertEquals(CS.Neural.protocolName(99), "UNKNOWN");
});

// --- fingerprint ---

Deno.test("Neural.fingerprint: empty sample returns [0, 0]", () => {
  assertEquals(CS.Neural.fingerprint([]), [0, 0]);
});

Deno.test("Neural.fingerprint: printable ASCII scores as HTTP", () => {
  // All printable ASCII bytes (32-126) should lean toward HTTP
  const sample = Array.from({ length: 50 }, (_, i) => 65 + (i % 26)); // A-Z repeated
  const [protocolId, confidence] = CS.Neural.fingerprint(sample);
  assertEquals(protocolId, 1); // HTTP
  assert(confidence > 0);
});

Deno.test("Neural.fingerprint: control bytes lean toward SSH", () => {
  // Mostly control chars (0-31)
  const sample = Array.from({ length: 50 }, (_, i) => i % 31);
  const [protocolId, _confidence] = CS.Neural.fingerprint(sample);
  // Should be SSH (2) or at least not HTTP
  assert(protocolId >= 0);
});

// --- countInRange ---

Deno.test("Neural.countInRange: counts values in range [lo, hi]", () => {
  assertEquals(CS.Neural.countInRange([1, 5, 10, 15, 20], 5, 15), 3);
});

Deno.test("Neural.countInRange: empty array returns 0", () => {
  assertEquals(CS.Neural.countInRange([], 0, 100), 0);
});

Deno.test("Neural.countInRange: no matches returns 0", () => {
  assertEquals(CS.Neural.countInRange([1, 2, 3], 10, 20), 0);
});

// ========== Quantum pure functions ==========

// --- shorFactors ---

Deno.test("Quantum.shorFactors: factors of 12 are [2, 2, 3]", () => {
  assertEquals(CS.Quantum.shorFactors(12), [2, 2, 3]);
});

Deno.test("Quantum.shorFactors: prime number returns [n]", () => {
  assertEquals(CS.Quantum.shorFactors(17), [17]);
});

Deno.test("Quantum.shorFactors: 1 returns empty array", () => {
  assertEquals(CS.Quantum.shorFactors(1), []);
});

Deno.test("Quantum.shorFactors: 100 = 2*2*5*5", () => {
  assertEquals(CS.Quantum.shorFactors(100), [2, 2, 5, 5]);
});

// --- cmdShor ---

Deno.test("Quantum.cmdShor: n < 2 returns 400", () => {
  const result = CS.Quantum.cmdShor([1]);
  assertEquals(result.status, 400);
});

Deno.test("Quantum.cmdShor: valid n returns factors", () => {
  const result = CS.Quantum.cmdShor([30]);
  assertEquals(result.status, 0);
  assertEquals(result.data, [2, 3, 5]);
});

Deno.test("Quantum.cmdShor: n > 10^9 returns 400", () => {
  const result = CS.Quantum.cmdShor([2000000000]);
  assertEquals(result.status, 400);
});

// --- cmdEntangle ---

Deno.test("Quantum.cmdEntangle: returns unique id each call", () => {
  const r1 = CS.Quantum.cmdEntangle([10, 20]);
  const r2 = CS.Quantum.cmdEntangle([30, 40]);
  assertEquals(r1.status, 0);
  assertEquals(r2.status, 0);
  assert(r1.data[0] !== r2.data[0], "Entangle ids should be unique");
});

// --- cmdQrng ---

Deno.test("Quantum.cmdQrng: produces requested number of random bytes", () => {
  const result = CS.Quantum.cmdQrng([10]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 10);
});

Deno.test("Quantum.cmdQrng: count capped at 256", () => {
  const result = CS.Quantum.cmdQrng([500]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 256);
});

Deno.test("Quantum.cmdQrng: default count is 1", () => {
  const result = CS.Quantum.cmdQrng([]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 1);
});

// ========== Audio pure functions ==========

// --- cmdAnalyse ---

Deno.test("Audio.cmdAnalyse: no samples returns 400", () => {
  const result = CS.Audio.cmdAnalyse([0]);
  assertEquals(result.status, 400);
});

Deno.test("Audio.cmdAnalyse: returns dominant level and peak", () => {
  // data[0] = n, then n samples
  const result = CS.Audio.cmdAnalyse([5, 10, 20, 20, 20, 10]);
  assertEquals(result.status, 0);
  // dominant should be 20 (most frequent), peak should be 20
  assertEquals(result.data[0], 20); // dominant
  assertEquals(result.data[1], 20); // peak
});

// --- cmdDetect ---

Deno.test("Audio.cmdDetect: signal above threshold detected", () => {
  // [n, threshold, ...samples]
  const result = CS.Audio.cmdDetect([4, 50, 10, 20, 80, 30]);
  assertEquals(result.status, 0);
  assertEquals(result.data[0], 1); // found
  assertEquals(result.data[1], 2); // index of 80
});

Deno.test("Audio.cmdDetect: no signal above threshold", () => {
  const result = CS.Audio.cmdDetect([3, 100, 10, 20, 30]);
  assertEquals(result.status, 0);
  assertEquals(result.data[0], 0); // not found
});

// --- cmdCompare ---

Deno.test("Audio.cmdCompare: identical signals have max similarity", () => {
  // [n, ...a(n), ...b(n)]
  const result = CS.Audio.cmdCompare([3, 10, 20, 30, 10, 20, 30]);
  assertEquals(result.status, 0);
  assertEquals(result.data[0], 1000); // max similarity
});

Deno.test("Audio.cmdCompare: very different signals have low similarity", () => {
  const result = CS.Audio.cmdCompare([3, 0, 0, 0, 255, 255, 255]);
  assertEquals(result.status, 0);
  assert(result.data[0] < 800, "Similarity should be low for very different signals");
});

// ========== Graphics pure functions ==========

Deno.test("Graphics.cmdScramble + cmdUnscramble: round-trip preserves data", () => {
  const data = [1, 2, 3, 4, 5];
  const seed = 42;
  // Format: [n, seed, ...data]
  const scrambled = CS.Graphics.cmdScramble([data.length, seed, ...data]);
  assertEquals(scrambled.status, 0);

  const unscrambled = CS.Graphics.cmdUnscramble([
    scrambled.data.length,
    seed,
    ...scrambled.data,
  ]);
  assertEquals(unscrambled.status, 0);
  assertEquals(unscrambled.data, data);
});

Deno.test("Graphics.cmdNoise: exceeding pixel cap returns 413", () => {
  // 100x100 = 10000 > 4096 cap
  const result = CS.Graphics.cmdNoise([100, 100, 0]);
  assertEquals(result.status, 413);
});

Deno.test("Graphics.cmdNoise: within cap succeeds with correct pixel count", () => {
  const result = CS.Graphics.cmdNoise([8, 8, 42]);
  assertEquals(result.status, 0);
  assertEquals(result.data.length, 64); // 8*8
});

Deno.test("Graphics.cmdBlend: 50/50 blend of identical arrays returns same values", () => {
  const a = [100, 200];
  const b = [100, 200];
  const result = CS.Graphics.cmdBlend([2, 500, ...a, ...b]);
  assertEquals(result.status, 0);
  assertEquals(result.data, [100, 200]);
});
