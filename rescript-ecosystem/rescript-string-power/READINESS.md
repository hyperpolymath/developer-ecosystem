<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# rescript-string-power — Component Readiness Assessment

**Standard:** [Component Readiness Grades (CRG) v2.2](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)
**Current Grade:** B
**Assessed:** 2026-04-05
**Assessor:** Jonathan D.A. Jewell

---

## Summary

| Component                         | Grade | Release Stage | Evidence                                       |
|-----------------------------------|-------|---------------|------------------------------------------------|
| `StringPower` ReScript library    | B     | Beta-stable   | 15 ReScript assertions + 6 independent targets |
| `string-union-gen` Rust CLI       | B     | Beta-stable   | 5 cargo unit tests + e2e fixture verification  |

**Overall:** Grade B — 6 independent test targets all passing; library exercised
end-to-end through the CLI; semantic properties of the interpolation and escape
primitives verified by randomised tests.

---

## Grade B Evidence — 6 Independent Test Targets

| Target | Recipe                   | Runner                    | Status |
|--------|--------------------------|---------------------------|--------|
| T1     | `just test-structure`    | Bash (`validate_structure.sh`)       | PASS |
| T2     | `just test-unit`         | Rust (`cargo test`)                  | PASS |
| T3     | `just test-e2e`          | Bash + Rust CLI + fixture            | PASS |
| T4     | `just test-property`     | Deno (`property_test.mjs`)           | PASS |
| T5     | `just test-bench`        | Deno (`bench_test.mjs`)              | PASS |
| T6     | `just test-lint`         | clippy + rustfmt + shellcheck        | PASS |

Run all six: `just test`.

The six targets exercise the repository through **genuinely distinct** vehicles:

- a Bash structural audit,
- Rust's own unit-test harness,
- an end-to-end shell-driven invocation of the compiled CLI binary,
- Deno's property-style runner on a JavaScript port of the core algorithms,
- Deno's benchmark harness on the same primitives,
- three static-analysis tools (clippy, rustfmt, shellcheck) bundled as a single
  lint gate.

Each target can fail independently without the others being affected.

---

## Concerns and Maintenance Notes

- **ReScript compiler is not exercised in CI.** The Justfile can build the
  ReScript library (`just build-rescript`), but the CI matrix deliberately
  avoids requiring a Node/npm toolchain to run. The JavaScript port of the
  algorithms in `tests/property_test.mjs` carries the weight of semantic
  coverage.
- **Watch mode** in `string-union-gen` is a documented stub — not yet
  implemented. Does not affect Grade B because the non-watch path is the
  primary one.
- **GraphQL parsing** is a simple regex pass, not a full lexer. It handles
  the documented cases; if more grammar coverage is needed, an external
  parser should be wired in rather than extending the inline code.

---

## Promotion path to Grade A

Grade A would need: genuine external adopters (not the author's other
projects), a documented stability contract, and formal verification or
fuzzing of the SQL-escape path.

---

Generate the shields.io badge: `just crg-badge`.
