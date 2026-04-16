// SPDX-License-Identifier: PMPL-1.0-or-later
// Deno tests for shared/PortNames module
// Tests port name suffixes, coprocessor domain detection, well-known port constants

import { assertEquals, assert } from "jsr:@std/assert";
import * as PortNames from "../../src/PortNames.res.mjs";

// --- Suffix constants ---

Deno.test("PortNames: inputSuffix is ':in'", () => {
  assertEquals(PortNames.inputSuffix, ":in");
});

Deno.test("PortNames: outputSuffix is ':out'", () => {
  assertEquals(PortNames.outputSuffix, ":out");
});

Deno.test("PortNames: controlSuffix is ':ctrl'", () => {
  assertEquals(PortNames.controlSuffix, ":ctrl");
});

// --- withInput / withOutput / withControl ---

Deno.test("PortNames.withInput: appends ':in' to port name", () => {
  assertEquals(PortNames.withInput("firewall"), "firewall:in");
});

Deno.test("PortNames.withOutput: appends ':out' to port name", () => {
  assertEquals(PortNames.withOutput("router"), "router:out");
});

Deno.test("PortNames.withControl: appends ':ctrl' to port name", () => {
  assertEquals(PortNames.withControl("switch"), "switch:ctrl");
});

Deno.test("PortNames.withInput: works with coprocessor domain port", () => {
  assertEquals(PortNames.withInput("crypto"), "crypto:in");
});

// --- Well-known port constants ---

Deno.test("PortNames: well-known device port names", () => {
  assertEquals(PortNames.console, "console");
  assertEquals(PortNames.display, "display");
  assertEquals(PortNames.audio, "audio");
  assertEquals(PortNames.alert, "alert");
  assertEquals(PortNames.firewall, "firewall");
  assertEquals(PortNames.router, "router");
  assertEquals(PortNames.switch_, "switch");
  assertEquals(PortNames.server, "server");
  assertEquals(PortNames.camera, "camera");
  assertEquals(PortNames.patchPanel, "patch");
  assertEquals(PortNames.powerSupply, "power");
  assertEquals(PortNames.fibreHub, "fibre");
  assertEquals(PortNames.phoneSystem, "pbx");
});

// --- Coop port names ---

Deno.test("PortNames: cooperative play port names", () => {
  assertEquals(PortNames.coopSync, "coop:sync");
  assertEquals(PortNames.coopChat, "coop:chat");
  assertEquals(PortNames.coopItem, "coop:item");
});

// --- Coprocessor domain constants ---

Deno.test("PortNames: coprocessor domain port names", () => {
  assertEquals(PortNames.cpCrypto, "crypto");
  assertEquals(PortNames.cpVector, "vector");
  assertEquals(PortNames.cpMaths, "maths");
  assertEquals(PortNames.cpIO, "io");
  assertEquals(PortNames.cpNeural, "neural");
  assertEquals(PortNames.cpQuantum, "quantum");
  assertEquals(PortNames.cpPhysics, "physics");
  assertEquals(PortNames.cpAudio, "audio");
  assertEquals(PortNames.cpTensor, "tensor");
  assertEquals(PortNames.cpGraphics, "graphics");
});

// --- coprocessorDomains array ---

Deno.test("PortNames.coprocessorDomains: contains all 10 domains", () => {
  assertEquals(PortNames.coprocessorDomains.length, 10);
  assert(PortNames.coprocessorDomains.includes("crypto"));
  assert(PortNames.coprocessorDomains.includes("quantum"));
  assert(PortNames.coprocessorDomains.includes("graphics"));
});

// --- isCoprocessorPort ---

Deno.test("PortNames.isCoprocessorPort: 'crypto:in' is a coprocessor port", () => {
  assert(PortNames.isCoprocessorPort("crypto:in"));
});

Deno.test("PortNames.isCoprocessorPort: 'quantum:out' is a coprocessor port", () => {
  assert(PortNames.isCoprocessorPort("quantum:out"));
});

Deno.test("PortNames.isCoprocessorPort: 'maths' (bare domain) is a coprocessor port", () => {
  assert(PortNames.isCoprocessorPort("maths"));
});

Deno.test("PortNames.isCoprocessorPort: 'firewall' is NOT a coprocessor port", () => {
  assertEquals(PortNames.isCoprocessorPort("firewall"), false);
});

Deno.test("PortNames.isCoprocessorPort: 'console' is NOT a coprocessor port", () => {
  assertEquals(PortNames.isCoprocessorPort("console"), false);
});

Deno.test("PortNames.isCoprocessorPort: 'coop:sync' is NOT a coprocessor port", () => {
  assertEquals(PortNames.isCoprocessorPort("coop:sync"), false);
});
