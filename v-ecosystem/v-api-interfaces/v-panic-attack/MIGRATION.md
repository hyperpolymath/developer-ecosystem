# SPDX-License-Identifier: CC-BY-SA-4.0

# panic-attack V-lang API — Migration Notice

`panic_attack.v` was moved here from `hyperpolymath/panic-attack` repository
(`api/v/panic_attack.v`) as part of the V-lang → Zig migration (2026-04-10).

V-lang is banned estate-wide. This file is preserved in `v-ecosystem` per the
V-sources-MOVE-not-delete policy.

**Replacement:** `hyperpolymath/panic-attack` `ffi/zig/src/panic_attack.zig`
(Zig FFI binding with identical C ABI surface). Status: planned.

The V-lang binding exposed:
- `Severity` enum (info/warning/error/critical)
- `ScanOp` enum (assail/ambush/abduct/adjudicate/axial)
- `Finding` struct (file, line, severity, message, rule_id)
- C FFI procs: `panic_severity_compare`, `panic_severity_meets`, `panic_valid_lang`
- Pub fns: `severity_meets()`, `is_supported_lang()`
