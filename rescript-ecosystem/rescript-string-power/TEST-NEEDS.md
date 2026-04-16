<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Test & Benchmark Requirements

## CRG Grade: B — ACHIEVED 2026-04-05

The library meets the minimum bar for a Beta release: it has been
exercised through six independent test vehicles, each of which can
fail without depending on any of the others.

## Grade B Test Suite (6 Independent Targets)

| Target | Recipe                   | Runner                               | Status |
|--------|--------------------------|--------------------------------------|--------|
| T1     | `just test-structure`    | Bash (`tests/validate_structure.sh`) | PASS   |
| T2     | `just test-unit`         | `cargo test` in `tools/string-union-gen` | PASS |
| T3     | `just test-e2e`          | `tests/e2e_test.sh` builds + runs CLI  | PASS |
| T4     | `just test-property`     | `deno test tests/property_test.mjs`    | PASS |
| T5     | `just test-bench`        | `deno bench tests/bench_test.mjs`      | PASS |
| T6     | `just test-lint`         | clippy + rustfmt + shellcheck          | PASS |

Run the full suite: `just test`.

## Structural checks (T1)

`tests/validate_structure.sh` asserts:

- All required RSR files are present
  (README.adoc, LICENSE, SECURITY.md, CONTRIBUTING.adoc, CODE_OF_CONDUCT.md,
  CHANGELOG.adoc, EXPLAINME.adoc, 0-AI-MANIFEST.a2ml, READINESS.md,
  TEST-NEEDS.md, .well-known/security.txt, .github/FUNDING.yml,
  .github/workflows/ci.yml).
- LICENSE is PMPL-1.0-or-later and contains no residual MIT text.
- Every `.res` and the Rust `main.rs` carries an SPDX header.
- The Rust Cargo manifest declares `LicenseRef-PMPL-1.0-or-later`.
- All six test targets exist in the Justfile with their expected recipe names.
- All four test fixture files are present in `tests/`.

## Unit tests (T2)

Five Rust tests in `tools/string-union-gen/src/main.rs` cover:

- `test_parse_simple_union` — basic polymorphic variant parsing.
- `test_parse_with_as_annotation` — `@as("...")` overrides.
- `test_parse_multiline` — multi-line variant declarations.
- `test_multiple_unions` — multiple `@stringUnion` types in one file.
- `test_generate_code` — the generated code contains the expected functions.

## End-to-end (T3)

`tests/e2e_test.sh` builds the CLI binary, runs it on a fresh fixture with
two `@stringUnion` types (one plain, one with `@as` overrides), and asserts
that the generated `.res` file contains:

- `{typeName}ToString`, `stringTo{TypeName}`, `stringTo{TypeName}Exn`,
  `all{TypeName}Values`, `all{TypeName}Strings` for each type,
- the expected string values for plain and `@as`-overridden variants,
- nothing is written when `--dry-run` is passed.

## Property tests (T4)

`tests/property_test.mjs` runs ~200 randomised trials per property against
a JavaScript reference implementation of the core `Utils` algorithms:

1. `interleave` preserves total length (sum of static + dynamic lengths).
2. `interleave([s], [])` returns `s` unchanged.
3. `interleave` output contains every static and dynamic fragment.
4. `escapeHtml` never leaves a raw `<` or `>` in its output.
5. `escapeSqlString` doubles every single quote exactly.
6. `escapeHtml` never shortens its input.

## Benchmarks (T5)

`tests/bench_test.mjs` measures:

- `interleave` on 3-dynamic and 20-dynamic inputs,
- a string-`Array.join` variant of `interleave` for comparison,
- `escapeHtml` on short, typical-XSS, and 2 KiB inputs.

These run under `deno bench` and emit timings; they do not gate on
thresholds.

## Lint gate (T6)

- `cargo clippy --all-targets -- -D warnings` on the CLI crate.
- `cargo fmt --check` on the CLI crate.
- `shellcheck` on every `tests/*.sh` script.

## What's next (path to Grade A)

Grade A requires genuine external adopters and a documented stability
contract. See `READINESS.md` for the full promotion path.
