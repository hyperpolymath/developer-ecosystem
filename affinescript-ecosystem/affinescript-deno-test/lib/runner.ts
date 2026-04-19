// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// affinescript-deno-test: runner.ts
//
// Loads a compiled AffineScript WASM module and wraps its `main` export as
// a Deno.test() case. A test passes when `main` returns `true`, fails when
// it returns `false`.
//
// MVP convention (v0.1.0): one test per .affine file. The export name is
// always `main` because the current AffineScript codegen (lib/codegen.ml
// line 1725) hardcodes the exportable-name allowlist to
//   ["main"; "init_state"; "step_state"; "get_state"; "mission_active"]
// with no `pub fn` / `@export` keyword. Multi-test-per-file support is a
// planned follow-up once the compiler gains arbitrary-export syntax.
//
// Uses the existing @hyperpolymath/affine-js bridge for WASM loading and
// value marshalling, plus a minimal WASI stub for `fd_write` (AffineScript
// codegen always pulls this import even for programs that never print).

import { AffineModule } from "@hyperpolymath/affine-js";

/** Convention: the single test export per file is always named this. */
export const TEST_EXPORT = "main";

/** Result shape returned by AffineScript Bool exports (via affine-js). */
interface BoolValue {
  kind: "bool";
  value: boolean;
}

/**
 * Derive the Deno.test() case name from the WASM path. Strips the directory
 * and the `.wasm` extension; if the filename ends in `_test` or `.test`,
 * strips that suffix too for readability.
 */
function caseName(wasmPath: string): string {
  const base = wasmPath.split("/").pop() ?? wasmPath;
  return base.replace(/\.wasm$/, "").replace(/(_test|\.test)$/, "");
}

/**
 * Minimal WASI stub. AffineScript's WASM output imports
 * `wasi_snapshot_preview1.fd_write` unconditionally, even for programs that
 * do not use IO. For test modules that only return Bool, we can satisfy this
 * with a no-op that reports `0` bytes written on every call.
 */
function makeWasiStub(): WebAssembly.ModuleImports {
  return {
    fd_write: (
      _fd: number,
      _iovsPtr: number,
      _iovsLen: number,
      _nwrittenPtr: number,
    ): number => 0,
    // Pre-empt future codegen additions with harmless stubs. If the module
    // doesn't import these, they are simply unused.
    proc_exit: (_code: number): void => {},
    fd_close: (_fd: number): number => 0,
  };
}

/**
 * Register a Deno.test() case for the `main` export in the WASM module at
 * `wasmPath`. Path should be absolute; relative paths resolve against CWD.
 *
 * Side-effect: calls `Deno.test()` exactly once.
 */
export async function registerTestsFromWasm(wasmPath: string): Promise<number> {
  const absolute = wasmPath.startsWith("/")
    ? wasmPath
    : `${Deno.cwd()}/${wasmPath}`;

  const bytes = await Deno.readFile(absolute);
  const wasmMod = await WebAssembly.compile(bytes);
  const neededImports = WebAssembly.Module.imports(wasmMod);
  const needsWasi = neededImports.some((i) => i.module === "wasi_snapshot_preview1");

  // AffineModule.fromBytes only supplies imports under the "env" module key,
  // so when WASI is required we must take the alternative path: raw
  // WebAssembly.instantiate with both env + wasi_snapshot_preview1.
  if (needsWasi) {
    return await registerTestsWithWasi(bytes, wasmPath);
  }

  const mod = await AffineModule.fromBytes(bytes);

  if (!mod.functionExports.includes(TEST_EXPORT)) {
    throw new Error(
      `affinescript-deno-test: no '${TEST_EXPORT}' export found in ${wasmPath}. ` +
        `Available: [${mod.functionExports.join(", ")}]. ` +
        `Each .affine test file must define 'fn main() -> Bool'.`,
    );
  }

  Deno.test(caseName(wasmPath), () => {
    const result = mod.call(TEST_EXPORT, { returnType: "bool" }) as BoolValue;
    if (result.kind !== "bool") {
      throw new Error(
        `test '${caseName(wasmPath)}' returned non-bool value: ${JSON.stringify(result)}`,
      );
    }
    if (!result.value) {
      throw new Error(`test '${caseName(wasmPath)}' returned false`);
    }
  });
  return 1;
}

/**
 * Alternative instantiation path for WASM modules that import
 * wasi_snapshot_preview1. Bypasses AffineModule because its constructor
 * only accepts imports under the "env" module key.
 */
async function registerTestsWithWasi(
  bytes: Uint8Array,
  wasmPath: string,
): Promise<number> {
  // Copy into a fresh ArrayBuffer-backed Uint8Array so the TS BufferSource
  // overload matches (Deno's Uint8Array default-types to ArrayBufferLike,
  // which the WebAssembly.instantiate overload rejects).
  const buf = new Uint8Array(bytes.byteLength);
  buf.set(bytes);
  const { instance } = await WebAssembly.instantiate(buf.buffer, {
    env: {},
    wasi_snapshot_preview1: makeWasiStub(),
  });

  const mainExport = instance.exports[TEST_EXPORT];
  if (typeof mainExport !== "function") {
    const available = Object.keys(instance.exports).join(", ");
    throw new Error(
      `affinescript-deno-test: no '${TEST_EXPORT}' function export found in ${wasmPath}. ` +
        `Available: [${available}]. ` +
        `Each .affine test file must define 'fn main() -> Bool'.`,
    );
  }

  Deno.test(caseName(wasmPath), () => {
    const raw = (mainExport as () => number)();
    // AffineScript compiles Bool to i32 (0 = false, 1 = true).
    if (raw !== 0 && raw !== 1) {
      throw new Error(
        `test '${caseName(wasmPath)}' returned non-bool raw value ${raw}; ` +
          `'main' must have signature 'fn main() -> Bool'`,
      );
    }
    if (raw === 0) {
      throw new Error(`test '${caseName(wasmPath)}' returned false`);
    }
  });
  return 1;
}
