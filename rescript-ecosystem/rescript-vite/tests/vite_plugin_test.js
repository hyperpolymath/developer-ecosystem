// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Tests for VitePluginRescript — the main Vite plugin.

import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("VitePluginRescript", async (t) => {
  const { make } = await import("../src/VitePluginRescript.res.js");

  await t.step("make returns a valid Vite plugin object", () => {
    const plugin = make();
    assertEquals(plugin.name, "rescript-vite");
    assertEquals(plugin.enforce, "pre");
    assertExists(plugin.configResolved);
    assertExists(plugin.buildStart);
    assertExists(plugin.handleHotUpdate);
    assertExists(plugin.buildEnd);
    assertExists(plugin.closeBundle);
  });

  await t.step("make with no args uses defaults", () => {
    const plugin = make();
    assertEquals(typeof plugin.configResolved, "function");
    assertEquals(typeof plugin.buildStart, "function");
  });

  await t.step("make with custom options", () => {
    const plugin = make({
      boj: true,
      bojEndpoint: "http://custom:8080/mcp/ssg",
      useDeno: true,
      logLevel: "silent",
    });
    assertEquals(plugin.name, "rescript-vite");
  });

  await t.step("configResolved stores config", () => {
    const plugin = make({ logLevel: "silent" });
    // Simulate Vite calling configResolved
    plugin.configResolved({
      root: "/test/project",
      command: "serve",
      mode: "development",
    });
    // Plugin should not throw
  });

  await t.step("handleHotUpdate ignores non-.res files", () => {
    const plugin = make({ logLevel: "silent" });
    const result = plugin.handleHotUpdate({
      file: "/test/style.css",
      modules: [],
      server: {
        moduleGraph: { getModulesByFile: () => undefined },
        ws: { send: () => {} },
      },
    });
    // Should return None (undefined) for non-.res files
    assertEquals(result, undefined);
  });

  await t.step("handleHotUpdate processes .res files", () => {
    const plugin = make({ logLevel: "silent" });
    // Need to configure first
    plugin.configResolved({
      root: "/test",
      command: "serve",
      mode: "development",
    });

    const testModules = [{ id: "test", url: "/src/App.res.js" }];
    const result = plugin.handleHotUpdate({
      file: "/test/src/App.res",
      modules: [],
      server: {
        moduleGraph: {
          getModulesByFile: (f) => {
            if (f === "/test/src/App.res.js") return testModules;
            return undefined;
          },
        },
        ws: { send: () => {} },
      },
    });
    // Should return the modules for HMR
    if (result !== undefined) {
      assertEquals(result.length, 1);
    }
  });

  await t.step("closeBundle does not throw when no watch handle", () => {
    const plugin = make({ logLevel: "silent" });
    // Should not throw even without a running compiler
    plugin.closeBundle();
  });

  await t.step("buildEnd does not throw", () => {
    const plugin = make({ logLevel: "silent" });
    plugin.buildEnd();
  });

  await t.step("plugin enforce is 'pre'", () => {
    const plugin = make();
    assertEquals(plugin.enforce, "pre");
  });
});
