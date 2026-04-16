# TEST-NEEDS.md — v-rest

## CRG Grade: C — ACHIEVED 2026-04-04

## Current Test State

| Category | Count | Notes |
|----------|-------|-------|
| Zig FFI tests | 1 | `ffi/zig/test/integration_test.zig` |
| Test infrastructure | Present | `tests/` directory structure |
| Maintenance reports | Present | Via reports/maintenance/ |

## What's Covered

- [x] Zig FFI integration tests
- [x] Test framework infrastructure
- [x] Maintenance tracking

## Still Missing (for CRG B+)

- [ ] REST API endpoint tests
- [ ] V-lang binding tests
- [ ] HTTP method validation tests
- [ ] Performance benchmarks
- [ ] Error handling tests

## Run Tests

```bash
cd /var/mnt/eclipse/repos/v-rest && cargo test
```
