// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Benchmarks for rescript-vite core functions.

import {
  parseDiagnostics,
  parseChangedFiles,
  stripAnsi,
} from "../src/RescriptCompiler.res.js";
import { make } from "../src/VitePluginRescript.res.js";
import { make as makeBojBridge } from "../src/BojBridge.res.js";

// --- Test data generators ---

/** Generate a single ReScript compiler error block */
function makeErrorBlock(file, line) {
  return [
    "  We've found a bug for you!",
    `  ${file}:${line}:1-20`,
    "",
    "  This has type: string",
    "  But expected: int",
    "",
  ].join("\n");
}

/** Generate a warning block */
function makeWarningBlock(file, line) {
  return [
    "  Warning number 3",
    `  ${file}:${line}:5-15`,
    "",
    "  deprecated: use newFunction instead",
    "",
  ].join("\n");
}

/** Generate compiler output with N errors */
function makeErrorOutput(n) {
  const blocks = [];
  for (let i = 0; i < n; i++) {
    blocks.push(makeErrorBlock(`src/Module${i}.res`, i + 1));
  }
  return blocks.join("\n");
}

/** Generate a Building/Compiling line */
function makeBuildLine(file) {
  return `  Building ${file}`;
}

/** Generate build output with N files */
function makeBuildOutput(n) {
  const lines = ["Parsed source files"];
  for (let i = 0; i < n; i++) {
    lines.push(makeBuildLine(`src/Component${i}.res`));
  }
  lines.push("Compiled modules");
  return lines.join("\n");
}

/** Wrap a string with various ANSI escape codes */
function wrapAnsi(s) {
  return `\x1b[1;31m${s}\x1b[0m \x1b[36m${s}\x1b[0m \x1b[2m${s}\x1b[0m`;
}

/** Generate a large ANSI-laden string */
function makeLargeAnsiString(repeats) {
  const base = "\x1b[31mERROR\x1b[0m: \x1b[1;33mWarning\x1b[0m in \x1b[36msrc/File.res\x1b[0m:\x1b[2m42:10\x1b[0m";
  return Array.from({ length: repeats }, () => base).join("\n");
}

// ============================================================
// Diagnostic Parsing Benchmarks
// ============================================================

Deno.bench("parseDiagnostics: clean output (no errors)", {
  group: "diagnostic-parsing",
  baseline: true,
}, () => {
  parseDiagnostics("Parsed 10 source files\nCompiled 10 modules\n");
});

Deno.bench("parseDiagnostics: single error", {
  group: "diagnostic-parsing",
}, () => {
  parseDiagnostics(makeErrorOutput(1));
});

Deno.bench("parseDiagnostics: 5 errors", {
  group: "diagnostic-parsing",
}, () => {
  parseDiagnostics(makeErrorOutput(5));
});

Deno.bench("parseDiagnostics: 20 errors", {
  group: "diagnostic-parsing",
}, () => {
  parseDiagnostics(makeErrorOutput(20));
});

Deno.bench("parseDiagnostics: 50 errors", {
  group: "diagnostic-parsing",
}, () => {
  parseDiagnostics(makeErrorOutput(50));
});

Deno.bench("parseDiagnostics: large output with ANSI codes", {
  group: "diagnostic-parsing",
}, () => {
  const output = [
    "\x1b[1;31mWe've found a bug for you!\x1b[0m",
    "\x1b[36m  src/App.res\x1b[0m:\x1b[2m15:1-30\x1b[0m",
    "",
    "  \x1b[33mThis has type: string\x1b[0m",
    "  \x1b[33mBut expected: int\x1b[0m",
    "",
    "\x1b[1;31mWe've found a bug for you!\x1b[0m",
    "\x1b[36m  src/Nav.res\x1b[0m:\x1b[2m8:3-12\x1b[0m",
    "",
    "  \x1b[33mUnbound value foo\x1b[0m",
  ].join("\n");
  parseDiagnostics(output);
});

Deno.bench("parseDiagnostics: edge case — empty string", {
  group: "diagnostic-parsing",
}, () => {
  parseDiagnostics("");
});

Deno.bench("parseDiagnostics: edge case — only whitespace and newlines", {
  group: "diagnostic-parsing",
}, () => {
  parseDiagnostics("   \n\n  \n    \n\n");
});

Deno.bench("parseDiagnostics: edge case — mixed errors and warnings", {
  group: "diagnostic-parsing",
}, () => {
  const output = [
    makeErrorBlock("src/A.res", 1),
    makeWarningBlock("src/B.res", 5),
    makeErrorBlock("src/C.res", 10),
    makeWarningBlock("src/D.res", 20),
    makeErrorBlock("src/E.res", 30),
  ].join("\n");
  parseDiagnostics(output);
});

// ============================================================
// Changed File Detection Benchmarks
// ============================================================

Deno.bench("parseChangedFiles: no files", {
  group: "changed-file-detection",
  baseline: true,
}, () => {
  parseChangedFiles("Parsed 5 source files\nCompiled 5 modules\n");
});

Deno.bench("parseChangedFiles: few files (3)", {
  group: "changed-file-detection",
}, () => {
  parseChangedFiles(makeBuildOutput(3));
});

Deno.bench("parseChangedFiles: many files (50)", {
  group: "changed-file-detection",
}, () => {
  parseChangedFiles(makeBuildOutput(50));
});

Deno.bench("parseChangedFiles: many files (200)", {
  group: "changed-file-detection",
}, () => {
  parseChangedFiles(makeBuildOutput(200));
});

// ============================================================
// Plugin Creation Benchmarks
// ============================================================

Deno.bench("make(): default options", {
  group: "plugin-creation",
  baseline: true,
}, () => {
  make();
});

Deno.bench("make(): with BoJ enabled", {
  group: "plugin-creation",
}, () => {
  make({
    boj: true,
    bojEndpoint: "http://localhost:7077/mcp/ssg",
    logLevel: "silent",
  });
});

Deno.bench("make(): with all options", {
  group: "plugin-creation",
}, () => {
  make({
    boj: true,
    bojEndpoint: "http://custom:9090/mcp/ssg",
    useDeno: true,
    rescriptBin: "/usr/local/bin/rescript",
    compilerFlags: ["-warn-error", "+a", "-bs-g"],
    logLevel: "verbose",
  });
});

// ============================================================
// stripAnsi Benchmarks
// ============================================================

Deno.bench("stripAnsi: small string (no escape codes)", {
  group: "strip-ansi",
  baseline: true,
}, () => {
  stripAnsi("Just a plain string with no ANSI codes");
});

Deno.bench("stripAnsi: small string (with escape codes)", {
  group: "strip-ansi",
}, () => {
  stripAnsi("\x1b[31mError\x1b[0m: something failed");
});

Deno.bench("stripAnsi: medium string (multiple codes)", {
  group: "strip-ansi",
}, () => {
  stripAnsi(
    "\x1b[1;31mWe've found a bug\x1b[0m in \x1b[36msrc/App.res\x1b[0m:\x1b[2m15:1-30\x1b[0m — \x1b[33mtype mismatch\x1b[0m"
  );
});

Deno.bench("stripAnsi: large string (100 escape sequences)", {
  group: "strip-ansi",
}, () => {
  stripAnsi(makeLargeAnsiString(100));
});

Deno.bench("stripAnsi: large string (500 escape sequences)", {
  group: "strip-ansi",
}, () => {
  stripAnsi(makeLargeAnsiString(500));
});

// ============================================================
// BojBridge Creation Benchmarks
// ============================================================

Deno.bench("BojBridge.make(): default endpoint", {
  group: "boj-bridge",
  baseline: true,
}, () => {
  makeBojBridge();
});

Deno.bench("BojBridge.make(): custom endpoint", {
  group: "boj-bridge",
}, () => {
  makeBojBridge("http://custom:8080/mcp/ssg");
});
