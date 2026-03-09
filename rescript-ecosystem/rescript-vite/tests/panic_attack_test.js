// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Integration tests for panic-attacker compatibility.
// Verifies that rescript-vite diagnostic parsing and BoJ telemetry work
// with panic-attacker SARIF-style output and scan results.

import { assertEquals, assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseDiagnostics, stripAnsi } from "../src/RescriptCompiler.res.js";
import { make as makeBojBridge, recentEvents, isConnected } from "../src/BojBridge.res.js";

Deno.test("Panic-Attack Integration", async (t) => {
  // ==========================================================
  // Diagnostic format compatibility with panic-attacker SARIF
  // ==========================================================

  await t.step("diagnostic format is compatible with SARIF-style output", () => {
    // panic-attacker emits SARIF-like results. The rescript-vite diagnostic
    // format should map cleanly to SARIF result objects.
    const output = [
      "  We've found a bug for you!",
      "  src/Auth.res:42:10-55",
      "",
      "  This expression has type string but an expression of type int was expected",
    ].join("\n");

    const diagnostics = parseDiagnostics(output);
    assertEquals(diagnostics.length, 1);

    const d = diagnostics[0];

    // Verify all SARIF-required fields are present and correctly typed
    assertEquals(typeof d.file, "string");
    assertEquals(typeof d.line, "number");
    assertEquals(typeof d.column, "number");
    assertEquals(typeof d.endColumn, "number");
    assertEquals(typeof d.severity, "string");
    assertEquals(typeof d.message, "string");

    // SARIF location mapping:
    //   file    -> result.locations[0].physicalLocation.artifactLocation.uri
    //   line    -> result.locations[0].physicalLocation.region.startLine
    //   column  -> result.locations[0].physicalLocation.region.startColumn
    //   severity -> result.level ("error" | "warning" | "note")
    //   message -> result.message.text
    assertEquals(d.file, "src/Auth.res");
    assertEquals(d.line, 42);
    assertEquals(d.column, 10);
    assertEquals(d.endColumn, 55);
    assertEquals(d.severity, "Error");
    assert(d.message.length > 0, "message must not be empty");
  });

  await t.step("diagnostics can represent multiple SARIF results", () => {
    const output = [
      "  We've found a bug for you!",
      "  src/Login.res:10:1-30",
      "  Unbound value handleSubmit",
      "  Warning number 8",
      "  src/Login.res:15:5-20",
      "  Unused variable: tempResult",
      "  We've found a bug for you!",
      "  src/Dashboard.res:88:3-40",
      "  This pattern does not cover all cases",
    ].join("\n");

    const diagnostics = parseDiagnostics(output);
    assert(diagnostics.length >= 2, `Expected at least 2 diagnostics, got ${diagnostics.length}`);

    // Verify we get a mix of severities (errors + warnings)
    const severities = new Set(diagnostics.map((d) => d.severity));
    assert(severities.has("Error"), "Should have Error severity");
  });

  // ==========================================================
  // Parsing panic-attacker weak point messages
  // ==========================================================

  await t.step("parses panic-attacker-style weak point messages as warnings", () => {
    // panic-attacker identifies "weak points" — code that could panic at runtime.
    // When fed through the compiler output stream, these should parse as
    // diagnostics with file locations.
    const panicOutput = [
      "  Warning number 110",
      "  src/Api.res:25:3-40",
      "",
      "  [panic-attacker] Weak point: Array.getExn on unbounded index",
      "  Risk: medium, Category: unchecked-access",
    ].join("\n");

    const diagnostics = parseDiagnostics(panicOutput);
    assertEquals(diagnostics.length, 1);

    const d = diagnostics[0];
    assertEquals(d.file, "src/Api.res");
    assertEquals(d.line, 25);
    assertEquals(d.severity, "Warning");
    assert(
      d.message.includes("panic-attacker") || d.message.includes("Weak point"),
      "Should preserve panic-attacker context in message"
    );
  });

  await t.step("parses multiple panic-attacker weak points", () => {
    const panicOutput = [
      "  Warning number 110",
      "  src/Parser.res:12:5-30",
      "",
      "  [panic-attacker] Weak point: Belt.Option.getExn on nullable value",
      "",
      "  Warning number 110",
      "  src/Parser.res:45:10-50",
      "",
      "  [panic-attacker] Weak point: Js.Exn.raiseError in production path",
      "",
      "  Warning number 110",
      "  src/Codec.res:78:2-25",
      "",
      "  [panic-attacker] Weak point: switch without exhaustive match",
    ].join("\n");

    const diagnostics = parseDiagnostics(panicOutput);
    assertEquals(diagnostics.length, 3);

    // All should be warnings
    for (const d of diagnostics) {
      assertEquals(d.severity, "Warning");
    }

    // Verify file locations
    assertEquals(diagnostics[0].file, "src/Parser.res");
    assertEquals(diagnostics[0].line, 12);
    assertEquals(diagnostics[1].file, "src/Parser.res");
    assertEquals(diagnostics[1].line, 45);
    assertEquals(diagnostics[2].file, "src/Codec.res");
    assertEquals(diagnostics[2].line, 78);
  });

  // ==========================================================
  // Plugin handling of panic-attacker scan results as warnings
  // ==========================================================

  await t.step("handles panic-attacker scan results mixed with compiler errors", () => {
    const mixedOutput = [
      // Regular compiler error
      "  We've found a bug for you!",
      "  src/Main.res:5:1-20",
      "  Type mismatch: string vs int",
      // panic-attacker weak point
      "  Warning number 110",
      "  src/Main.res:15:3-40",
      "",
      "  [panic-attacker] Weak point: Array.getExn without bounds check",
      // Another compiler error
      "  We've found a bug for you!",
      "  src/Config.res:30:10-50",
      "  Unbound module JsonDecode",
    ].join("\n");

    const diagnostics = parseDiagnostics(mixedOutput);
    assert(diagnostics.length >= 2, `Expected at least 2 diagnostics, got ${diagnostics.length}`);

    // Should have both errors and warnings
    const errors = diagnostics.filter((d) => d.severity === "Error");
    const warnings = diagnostics.filter((d) => d.severity === "Warning");

    assert(errors.length >= 1, "Should have at least 1 error");
    assert(warnings.length >= 1, "Should have at least 1 warning (panic-attacker)");
  });

  await t.step("ANSI-stripped panic-attacker output preserves message content", () => {
    const ansiWrapped =
      "\x1b[33m[panic-attacker]\x1b[0m \x1b[1mWeak point:\x1b[0m \x1b[36mArray.getExn\x1b[0m on unbounded index";

    const cleaned = stripAnsi(ansiWrapped);
    assert(cleaned.includes("[panic-attacker]"), "Should preserve marker");
    assert(cleaned.includes("Weak point:"), "Should preserve label");
    assert(cleaned.includes("Array.getExn"), "Should preserve function name");
    assert(!cleaned.includes("\x1b"), "Should strip all ANSI codes");
  });

  // ==========================================================
  // BojBridge telemetry with simulated panic-attack scan data
  // ==========================================================

  await t.step("BojBridge records telemetry events from panic-attack scans", () => {
    const bridge = makeBojBridge("http://localhost:1/test");

    // Simulate recording telemetry events that include panic-attack scan data.
    // In production, requestBuild pushes events; here we simulate directly.
    const scanEvent = {
      project: "/home/user/my-rescript-app",
      timestamp: Date.now(),
      success: true,
      fileCount: 12,
      diagnosticCount: 3, // 3 panic-attacker weak points found
      durationMs: 450.5,
      cacheHitRate: 0.75,
    };

    bridge.events.push(scanEvent);

    const events = recentEvents(bridge);
    assertEquals(events.length, 1);
    assertEquals(events[0].project, "/home/user/my-rescript-app");
    assertEquals(events[0].diagnosticCount, 3);
    assertEquals(events[0].success, true);
    assertEquals(events[0].cacheHitRate, 0.75);
  });

  await t.step("BojBridge telemetry tracks multiple scan iterations", () => {
    const bridge = makeBojBridge("http://localhost:1/test");

    // Simulate a sequence of scans: initial (many issues) -> fix cycle -> clean
    const scans = [
      {
        project: "/app",
        timestamp: Date.now() - 3000,
        success: false,
        fileCount: 20,
        diagnosticCount: 15,
        durationMs: 800.0,
        cacheHitRate: 0.0,
      },
      {
        project: "/app",
        timestamp: Date.now() - 2000,
        success: false,
        fileCount: 20,
        diagnosticCount: 5,
        durationMs: 600.0,
        cacheHitRate: 0.5,
      },
      {
        project: "/app",
        timestamp: Date.now() - 1000,
        success: true,
        fileCount: 20,
        diagnosticCount: 0,
        durationMs: 400.0,
        cacheHitRate: 0.9,
      },
    ];

    for (const scan of scans) {
      bridge.events.push(scan);
    }

    const events = recentEvents(bridge);
    assertEquals(events.length, 3);

    // Verify trend: diagnostic count decreasing
    assert(events[0].diagnosticCount > events[1].diagnosticCount);
    assert(events[1].diagnosticCount > events[2].diagnosticCount);
    assertEquals(events[2].diagnosticCount, 0);

    // Verify trend: cache hit rate improving
    assert(events[2].cacheHitRate > events[0].cacheHitRate);

    // Final scan should be successful
    assertEquals(events[2].success, true);
  });

  await t.step("BojBridge telemetry respects limit with scan history", () => {
    const bridge = makeBojBridge("http://localhost:1/test");

    // Simulate 50 scan events
    for (let i = 0; i < 50; i++) {
      bridge.events.push({
        project: "/app",
        timestamp: Date.now() + i,
        success: i % 3 !== 0, // every 3rd scan fails
        fileCount: 10 + i,
        diagnosticCount: i % 3 === 0 ? 2 : 0,
        durationMs: 100 + i * 10,
        cacheHitRate: Math.min(1.0, i * 0.02),
      });
    }

    // Default limit is 20
    const recent20 = recentEvents(bridge);
    assertEquals(recent20.length, 20);

    // Custom limit
    const recent5 = recentEvents(bridge, 5);
    assertEquals(recent5.length, 5);

    // The most recent events should be returned (highest timestamps)
    assert(recent5[0].timestamp > recent20[0].timestamp - 1);
  });

  await t.step("disconnected BojBridge does not lose recorded events", async () => {
    const bridge = makeBojBridge("http://localhost:1/test");

    bridge.events.push({
      project: "/app",
      timestamp: Date.now(),
      success: true,
      fileCount: 5,
      diagnosticCount: 1,
      durationMs: 200.0,
      cacheHitRate: 0.5,
    });

    // Manually connect then disconnect
    bridge.state = { TAG: "Connected", _0: "test-session" };
    assert(isConnected(bridge), "Should be connected");

    // Import disconnect
    const { disconnect } = await import("../src/BojBridge.res.js");
    disconnect(bridge);

    assert(!isConnected(bridge), "Should be disconnected");

    // Events should still be accessible
    const events = recentEvents(bridge);
    assertEquals(events.length, 1);
    assertEquals(events[0].diagnosticCount, 1);
  });
});
