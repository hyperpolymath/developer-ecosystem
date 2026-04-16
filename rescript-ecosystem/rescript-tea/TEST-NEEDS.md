# TEST-NEEDS: rescript-tea

## CRG Grade: C — ACHIEVED 2026-04-04

## Current State

| Category | Count | Details |
|----------|-------|---------|
| **Source modules** | 18 | 17 ReScript modules (Tea, Vdom, Html, Svg, Cmd, Sub, App, Render, Http, Json, Time, Animationframe, Keyboard, Mouse, Window, Ssr, Debug, Test) + 3 Idris2 ABI + 2 Zig FFI |
| **Unit tests** | ~1 | tea_test.js exists but grep shows only 1 describe block |
| **Integration tests** | 0 | None |
| **E2E tests** | 0 | None |
| **Benchmarks** | 0 | bench_test.js exists with 4 lines. benchmarks/ dir has only a README |
| **Fuzz tests** | 0 | fuzz/ dir has only placeholder.txt |

## What's Missing

### P2P Tests
- [ ] No tests verifying Tea framework modules work together (App + Vdom + Cmd + Sub pipeline)

### E2E Tests (CRITICAL)
- [ ] No browser-based rendering tests
- [ ] No SSR output validation
- [ ] No HTTP module integration test

### Aspect Tests
- [ ] **Security**: No XSS injection tests for Html/Svg modules, no sanitization tests
- [ ] **Performance**: No virtual DOM diffing benchmarks, no render cycle measurements
- [ ] **Concurrency**: No tests for concurrent Cmd/Sub handling
- [ ] **Error handling**: No tests for malformed JSON, failed HTTP requests, invalid Vdom trees

### Build & Execution
- [ ] No ReScript compilation verification test
- [ ] No Zig FFI integration test beyond template placeholder
- [ ] No Idris2 ABI type checking verification

### Benchmarks Needed (CRITICAL)
- [ ] bench_test.js is 4 lines -- effectively empty. CLAIMED benchmark that does not exist
- [ ] Vdom diff performance (100/1000/10000 nodes)
- [ ] SSR throughput
- [ ] Event handler dispatch latency

### Self-Tests
- [ ] Tea_Test.res exists as module but no self-diagnostic runner

## FLAGGED ISSUES
- **bench_test.js is a phantom benchmark** -- 4 lines, no actual measurements
- **benchmarks/ directory contains only README.adoc** -- claimed capability does not exist
- **17 ReScript modules with effectively 1 test file** = test desert
- **fuzz/placeholder.txt** -- claimed fuzz testing is fake

## Priority: P0 (CRITICAL)

## Session 9 additions (2026-04-04)

### What Was Added

| Area | Tests Added | Location |
|------|-------------|----------|
| CI runner | GitHub Actions workflow for existing test suite (e2e_test.js, tea_test.js, property_test.js) | `.github/workflows/e2e.yml` |

### Updated Test Counts

| Suite | Count | Status |
|-------|-------|--------|
| CI workflows | 21 | Running e2e suite |
