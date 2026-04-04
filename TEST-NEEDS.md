# Test & Benchmark Requirements

## CRG Grade: C — ACHIEVED 2026-04-04

All CRG C categories represented in `opm-canonicalizer` (the primary testable sub-project):
- Unit: 22 tests (null, bool, int, string, object sorting, escaping, error cases)
- Smoke: duplicate key rejection, float rejection
- P2P/property: 5 proptest properties (idempotence, no-whitespace, key sorting, array order, negative int roundtrip)
- E2E/reflexive: canonicalize-twice idempotency, whitespace stripping
- Contract: output format invariants (no spaces between tokens, negative ints preserved)
- Aspect: empty string, control char escaping, deep nesting (50 levels), malformed input
- Benchmarks: 5 Criterion benchmarks (null, simple object, nested object, array, escapes)

**Ecosystem-wide**: 2248 test files across 29+ sub-ecosystems (includes rescript-ecosystem compiler tests, Zig integration tests, robot-vacuum-cleaner Julia tests, etc.)

## Current State
- Unit tests: ~5 Rust test files + ~4 TS test files + ~54 Zig test files — partial coverage
- Integration tests: partial (some Zig integration tests across ecosystem packages)
- E2E tests: NONE
- Benchmarks: ~738 benchmark files (mostly V-lang ecosystem benchmarks)
- panic-attack scan: NEVER RUN

## What's Missing
### Point-to-Point (P2P)
This is a massive monorepo (29+ sub-ecosystems) with extreme variation in test coverage:

**Source file counts:**
- ReScript: 3,446 files — likely bulk of code, ZERO test files identified
- Julia: 635 files — ZERO test files identified
- Idris2: 323 files — ZERO test files identified
- V: 201 files — ZERO dedicated test files (benchmarks exist)
- Zig: 180 files — 54 test files (BEST coverage ratio)
- Rust: 90 files — 5 test files
- Haskell: 77 files — ZERO test files
- Elixir: 54 files — ZERO test files
- JavaScript: 557 files — ZERO test files
- TypeScript: 25 files — 4 test files
- Shell: 300 files — ZERO test files

#### Sub-ecosystems with tests:
- zig-ecosystem/ — 54 Zig test files (reasonable for 180 source files)
- deno-ecosystem/ — 4 TS test files (inadequate for ecosystem size)
- Some Rust components — 5 test files

#### Sub-ecosystems with ZERO tests:
- **rescript-ecosystem/** (3,446 files) — completely untested
- **julia-ecosystem/** (635 files) — completely untested
- **idris2-ecosystem/** (323 files) — completely untested
- **v-ecosystem/** (201 files) — benchmarks only, no correctness tests
- **haskell ecosystem** (77 files) — completely untested
- **ada-ecosystem/** — completely untested
- **coq-ecosystem/** — no test files found
- **well-known-ecosystem/** — no test files found
- **package-publishers/** — no test files found
- **techstack-enforcer/** — no test files found

### End-to-End (E2E)
- Ecosystem package build and test cycle per language
- Cross-ecosystem dependency resolution
- Package publishing workflow per ecosystem
- Satellite submodule synchronization
- Tool version enforcement

### Aspect Tests
- [ ] Security (package supply chain, dependency confusion, malicious packages)
- [ ] Performance (build time per ecosystem, package resolution speed)
- [ ] Concurrency (parallel builds across ecosystems)
- [ ] Error handling (missing tools, version conflicts, broken satellites)
- [ ] Accessibility (N/A)

### Build & Execution
- [ ] Per-ecosystem builds — not systematically verified
- [ ] Satellite submodule integrity — not verified
- [ ] Package publishing dry-run — not verified
- [ ] Self-diagnostic — none

### Benchmarks Needed
- Per-ecosystem build times
- Package resolution performance
- Cross-ecosystem integration latency
- Verify 738 existing benchmark files actually run (likely V-lang benchmarks)

### Self-Tests
- [ ] panic-attack assail on own repo
- [ ] Per-ecosystem health check

## Priority
- **HIGH** — Staggeringly large monorepo (3,446 ReScript + 635 Julia + 557 JS + 323 Idris2 + 300 Shell + 201 V + 180 Zig + 90 Rust + 77 Haskell + 54 Elixir files). The ReScript ecosystem alone has 3,446 source files with ZERO tests. Only the Zig ecosystem has reasonable test coverage. The 738 "benchmark" files are likely V-lang ecosystem benchmarks, not project-level performance tests.

## FAKE-FUZZ ALERT

- `tests/fuzz/placeholder.txt` is a scorecard placeholder inherited from rsr-template-repo — it does NOT provide real fuzz testing
- Replace with an actual fuzz harness (see rsr-template-repo/tests/fuzz/README.adoc) or remove the file
- Priority: P2 — creates false impression of fuzz coverage
