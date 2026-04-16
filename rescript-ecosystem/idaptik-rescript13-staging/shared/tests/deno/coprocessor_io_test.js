// SPDX-License-Identifier: PMPL-1.0-or-later
// Deno tests for shared/Coprocessor_IO module
// Tests the virtual filesystem: write/read/delete/list/stat, path encoding,
// tombstone mechanism, null-separator splitting

import { assertEquals, assert } from "jsr:@std/assert";
import * as CpIO from "../../src/Coprocessor_IO.res.mjs";

// --- decodePath ---

Deno.test("Coprocessor_IO.decodePath: decodes ASCII bytes to string", () => {
  // "hello" = [104, 101, 108, 108, 111]
  const data = [104, 101, 108, 108, 111];
  assertEquals(CpIO.decodePath(data), "hello");
});

Deno.test("Coprocessor_IO.decodePath: stops at null byte", () => {
  const data = [65, 66, 0, 67, 68]; // "AB\0CD"
  assertEquals(CpIO.decodePath(data), "AB");
});

Deno.test("Coprocessor_IO.decodePath: empty array returns empty string", () => {
  assertEquals(CpIO.decodePath([]), "");
});

Deno.test("Coprocessor_IO.decodePath: skips bytes >= 128", () => {
  assertEquals(CpIO.decodePath([72, 200, 73]), "HI"); // 72='H', 200=skip, 73='I'
});

// --- encodePath ---

Deno.test("Coprocessor_IO.encodePath: encodes string to byte array", () => {
  const result = CpIO.encodePath("AB");
  assertEquals(result, [65, 66]);
});

Deno.test("Coprocessor_IO.encodePath: empty string returns empty array", () => {
  assertEquals(CpIO.encodePath(""), []);
});

// --- findNull ---

Deno.test("Coprocessor_IO.findNull: finds first null byte index", () => {
  assertEquals(CpIO.findNull([1, 2, 0, 3]), 2);
});

Deno.test("Coprocessor_IO.findNull: no null returns undefined", () => {
  assertEquals(CpIO.findNull([1, 2, 3]), undefined);
});

Deno.test("Coprocessor_IO.findNull: first of multiple nulls", () => {
  assertEquals(CpIO.findNull([0, 0, 0]), 0);
});

// --- splitAtNull ---

Deno.test("Coprocessor_IO.splitAtNull: splits at null byte", () => {
  const [path, content] = CpIO.splitAtNull([65, 66, 0, 1, 2, 3]);
  assertEquals(path, [65, 66]);
  assertEquals(content, [1, 2, 3]);
});

Deno.test("Coprocessor_IO.splitAtNull: no null returns [data, []]", () => {
  const [path, content] = CpIO.splitAtNull([65, 66, 67]);
  assertEquals(path, [65, 66, 67]);
  assertEquals(content, []);
});

// --- tombstone mechanism ---

Deno.test("Coprocessor_IO.tombKey: creates device+path compound key", () => {
  const key = CpIO.tombKey("dev1", "/file.txt");
  assert(key.includes("dev1"));
  assert(key.includes("/file.txt"));
});

Deno.test("Coprocessor_IO.isTombstoned: default is false", () => {
  assertEquals(CpIO.isTombstoned("tomb-test-dev", "/nofile"), false);
});

Deno.test("Coprocessor_IO.tombstone + isTombstoned: marks path as deleted", () => {
  CpIO.tombstone("tomb-dev2", "/deleted.txt");
  assertEquals(CpIO.isTombstoned("tomb-dev2", "/deleted.txt"), true);
});

Deno.test("Coprocessor_IO.clearTombstone: restores deleted path", () => {
  CpIO.tombstone("tomb-dev3", "/restored.txt");
  CpIO.clearTombstone("tomb-dev3", "/restored.txt");
  assertEquals(CpIO.isTombstoned("tomb-dev3", "/restored.txt"), false);
});

// --- Virtual FS commands ---

// Helper: encode a path string as bytes for commands
function encPath(s) {
  return Array.from(s).map((c) => c.charCodeAt(0));
}

// Helper: encode path + null + content
function encPathContent(path, content) {
  return [...encPath(path), 0, ...content];
}

Deno.test("Coprocessor_IO.cmdWrite + cmdRead: round-trip preserves content", () => {
  const deviceId = "fs-rw-test";
  const content = [10, 20, 30, 40];
  const writeResult = CpIO.cmdWrite(
    deviceId,
    encPathContent("/test.bin", content),
  );
  assertEquals(writeResult.status, 0);

  const readResult = CpIO.cmdRead(deviceId, encPath("/test.bin"));
  assertEquals(readResult.status, 0);
  assertEquals(readResult.data, content);
});

Deno.test("Coprocessor_IO.cmdRead: non-existent file returns 404", () => {
  const result = CpIO.cmdRead("fs-read-missing", encPath("/nope.txt"));
  assertEquals(result.status, 404);
});

Deno.test("Coprocessor_IO.cmdRead: empty path returns 400", () => {
  const result = CpIO.cmdRead("fs-read-empty", []);
  assertEquals(result.status, 400);
});

Deno.test("Coprocessor_IO.cmdWrite: empty path returns 400", () => {
  const result = CpIO.cmdWrite("fs-write-empty", [0, 1, 2, 3]);
  assertEquals(result.status, 400);
});

Deno.test("Coprocessor_IO.cmdDelete: existing file returns 0", () => {
  const deviceId = "fs-del-test";
  CpIO.cmdWrite(deviceId, encPathContent("/to-delete.txt", [1, 2]));

  const result = CpIO.cmdDelete(deviceId, encPath("/to-delete.txt"));
  assertEquals(result.status, 0);

  // Read after delete returns 404
  const readResult = CpIO.cmdRead(deviceId, encPath("/to-delete.txt"));
  assertEquals(readResult.status, 404);
});

Deno.test("Coprocessor_IO.cmdDelete: non-existent file returns 404", () => {
  const result = CpIO.cmdDelete("fs-del-miss", encPath("/ghost.txt"));
  assertEquals(result.status, 404);
});

Deno.test("Coprocessor_IO.cmdStat: returns size of existing file", () => {
  const deviceId = "fs-stat-test";
  CpIO.cmdWrite(deviceId, encPathContent("/sized.bin", [1, 2, 3, 4, 5]));

  const result = CpIO.cmdStat(deviceId, encPath("/sized.bin"));
  assertEquals(result.status, 0);
  // Size = 5 bytes. data = [sizeHi, sizeLo]
  const size = (result.data[0] << 8) | result.data[1];
  assertEquals(size, 5);
});

Deno.test("Coprocessor_IO.cmdStat: non-existent file returns size 0", () => {
  const result = CpIO.cmdStat("fs-stat-miss", encPath("/missing.bin"));
  assertEquals(result.status, 0);
  const size = (result.data[0] << 8) | result.data[1];
  assertEquals(size, 0);
});

Deno.test("Coprocessor_IO.cmdList: lists files with matching prefix", () => {
  const deviceId = "fs-list-test";
  CpIO.cmdWrite(
    deviceId,
    encPathContent("/logs/access.log", [1]),
  );
  CpIO.cmdWrite(
    deviceId,
    encPathContent("/logs/error.log", [2]),
  );
  CpIO.cmdWrite(
    deviceId,
    encPathContent("/config/main.cfg", [3]),
  );

  const result = CpIO.cmdList(deviceId, encPath("/logs"));
  assertEquals(result.status, 0);
  // The list data encodes path names separated by null bytes
  // At minimum, it should contain data (non-empty)
  assert(result.data.length > 0, "List should return encoded file paths");
  assert(
    result.message.includes("2"),
    "Should find 2 files under /logs prefix",
  );
});

Deno.test("Coprocessor_IO.cmdList: empty prefix lists all files", () => {
  const deviceId = "fs-list-all";
  CpIO.cmdWrite(deviceId, encPathContent("/a.txt", [1]));
  CpIO.cmdWrite(deviceId, encPathContent("/b.txt", [2]));

  const result = CpIO.cmdList(deviceId, []);
  assertEquals(result.status, 0);
  assert(result.data.length > 0);
});

// --- Write overwrites existing file ---

Deno.test("Coprocessor_IO.cmdWrite: overwrite replaces content", () => {
  const deviceId = "fs-overwrite";
  CpIO.cmdWrite(deviceId, encPathContent("/file.bin", [1, 2, 3]));
  CpIO.cmdWrite(deviceId, encPathContent("/file.bin", [99]));

  const readResult = CpIO.cmdRead(deviceId, encPath("/file.bin"));
  assertEquals(readResult.status, 0);
  assertEquals(readResult.data, [99]);
});

// --- Write after delete restores file ---

Deno.test("Coprocessor_IO.cmdWrite: writing after delete restores file", () => {
  const deviceId = "fs-restore";
  CpIO.cmdWrite(deviceId, encPathContent("/revival.txt", [1]));
  CpIO.cmdDelete(deviceId, encPath("/revival.txt"));

  // Should be 404 after delete
  assertEquals(CpIO.cmdRead(deviceId, encPath("/revival.txt")).status, 404);

  // Write new content
  CpIO.cmdWrite(deviceId, encPathContent("/revival.txt", [42]));
  const result = CpIO.cmdRead(deviceId, encPath("/revival.txt"));
  assertEquals(result.status, 0);
  assertEquals(result.data, [42]);
});
