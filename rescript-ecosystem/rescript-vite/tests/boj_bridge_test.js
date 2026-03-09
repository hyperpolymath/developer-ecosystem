// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Tests for BojBridge — BoJ server integration.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { make, isConnected, disconnect, recentEvents, defaultEndpoint } from "../src/BojBridge.res.js";

Deno.test("BojBridge", async (t) => {
  await t.step("make creates a disconnected bridge", () => {
    const bridge = make();
    assertEquals(isConnected(bridge), false);
    assertEquals(bridge.endpoint, defaultEndpoint);
    assertEquals(bridge.events.length, 0);
  });

  await t.step("make accepts custom endpoint", () => {
    const bridge = make("http://custom:9090/mcp/ssg");
    assertEquals(bridge.endpoint, "http://custom:9090/mcp/ssg");
  });

  await t.step("defaultEndpoint is localhost:7077", () => {
    assertEquals(defaultEndpoint, "http://localhost:7077/mcp/ssg");
  });

  await t.step("isConnected returns false initially", () => {
    const bridge = make();
    assertEquals(isConnected(bridge), false);
  });

  await t.step("disconnect sets state to Disconnected", () => {
    const bridge = make();
    // Manually set to Connected for test
    bridge.state = { TAG: "Connected", _0: "test-session" };
    disconnect(bridge);
    assertEquals(isConnected(bridge), false);
  });

  await t.step("recentEvents returns empty array initially", () => {
    const bridge = make();
    const events = recentEvents(bridge);
    assertEquals(events.length, 0);
  });

  await t.step("recentEvents respects limit", () => {
    const bridge = make();
    // Add some test events
    for (let i = 0; i < 30; i++) {
      bridge.events.push({
        project: "/test",
        timestamp: Date.now(),
        success: true,
        fileCount: 1,
        diagnosticCount: 0,
        durationMs: 100,
        cacheHitRate: 0.5,
      });
    }
    const recent = recentEvents(bridge, 10);
    assertEquals(recent.length, 10);
  });

  await t.step("recentEvents returns all if under limit", () => {
    const bridge = make();
    bridge.events.push({
      project: "/test",
      timestamp: Date.now(),
      success: true,
      fileCount: 5,
      diagnosticCount: 0,
      durationMs: 200,
      cacheHitRate: 1.0,
    });
    const recent = recentEvents(bridge);
    assertEquals(recent.length, 1);
    assertEquals(recent[0].project, "/test");
    assertEquals(recent[0].fileCount, 5);
  });

  await t.step("probe returns false when BoJ is unreachable", async () => {
    const bridge = make("http://localhost:1/nonexistent");
    // Import probe
    const { probe } = await import("../src/BojBridge.res.js");
    const result = await probe(bridge);
    assertEquals(result, false);
    assertEquals(isConnected(bridge), false);
  });
});
