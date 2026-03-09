// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Tests for RescriptCompiler diagnostic parsing and changed file detection.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseDiagnostics, parseChangedFiles, defaultConfig } from "../src/RescriptCompiler.res.js";

Deno.test("RescriptCompiler", async (t) => {
  // --- parseDiagnostics ---

  await t.step("parseDiagnostics returns empty array for clean output", () => {
    const result = parseDiagnostics("Parsed 10 source files\nCompiled 10 modules\n");
    assertEquals(result.length, 0);
  });

  await t.step("parseDiagnostics returns empty for empty string", () => {
    const result = parseDiagnostics("");
    assertEquals(result.length, 0);
  });

  await t.step("parseDiagnostics returns empty for whitespace", () => {
    const result = parseDiagnostics("   \n\n  \n");
    assertEquals(result.length, 0);
  });

  await t.step("parseDiagnostics parses error with file location", () => {
    const output = [
      "  We've found a bug for you!",
      "  src/Main.res:42:10-55",
      "",
      "  This has type: string",
      "  But expected: int",
    ].join("\n");
    const result = parseDiagnostics(output);
    assertEquals(result.length, 1);
    assertEquals(result[0].file, "src/Main.res");
    assertEquals(result[0].line, 42);
    assertEquals(result[0].column, 10);
    assertEquals(result[0].endColumn, 55);
    assertEquals(result[0].severity, "Error");
  });

  await t.step("parseDiagnostics parses warning", () => {
    const output = [
      "  Warning number 3",
      "  src/Util.res:10:5-20",
      "",
      "  deprecated: use newFunction instead",
    ].join("\n");
    const result = parseDiagnostics(output);
    assertEquals(result.length, 1);
    assertEquals(result[0].file, "src/Util.res");
    assertEquals(result[0].severity, "Warning");
  });

  await t.step("parseDiagnostics handles .resi files", () => {
    const output = [
      "  We've found a bug for you!",
      "  src/Types.resi:5:3-20",
      "",
      "  Type mismatch",
    ].join("\n");
    const result = parseDiagnostics(output);
    assertEquals(result.length, 1);
    assertEquals(result[0].file, "src/Types.resi");
  });

  await t.step("parseDiagnostics strips ANSI codes", () => {
    const output = [
      "  \x1b[1;31mWe've found a bug for you!\x1b[0m",
      "  \x1b[36msrc/App.res\x1b[0m:\x1b[2m15:1-30\x1b[0m",
      "",
      "  Error message here",
    ].join("\n");
    const result = parseDiagnostics(output);
    assertEquals(result.length, 1);
    assertEquals(result[0].file, "src/App.res");
    assertEquals(result[0].line, 15);
  });

  await t.step("parseDiagnostics handles multiple diagnostics", () => {
    const output = [
      "  We've found a bug for you!",
      "  src/A.res:1:1-10",
      "  Error one",
      "  We've found a bug for you!",
      "  src/B.res:2:5-15",
      "  Error two",
    ].join("\n");
    const result = parseDiagnostics(output);
    assertEquals(result.length, 2);
    assertEquals(result[0].file, "src/A.res");
    assertEquals(result[1].file, "src/B.res");
  });

  // --- parseChangedFiles ---

  await t.step("parseChangedFiles returns empty for clean output", () => {
    const result = parseChangedFiles("Parsed 5 source files\nCompiled 5 modules\n");
    assertEquals(result.length, 0);
  });

  await t.step("parseChangedFiles returns empty for empty string", () => {
    const result = parseChangedFiles("");
    assertEquals(result.length, 0);
  });

  // --- defaultConfig ---

  await t.step("defaultConfig sets cwd", () => {
    const cfg = defaultConfig("/my/project");
    assertEquals(cfg.cwd, "/my/project");
    assertEquals(cfg.useDeno, false);
    assertEquals(cfg.compilerFlags.length, 0);
  });

  await t.step("defaultConfig has no callbacks by default", () => {
    const cfg = defaultConfig(".");
    assertEquals(cfg.onDiagnostic, undefined);
    assertEquals(cfg.onFileChanged, undefined);
    assertEquals(cfg.rescriptBin, undefined);
  });
});
