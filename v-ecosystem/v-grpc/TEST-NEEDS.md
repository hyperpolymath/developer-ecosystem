# TEST-NEEDS.md — v-grpc

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

- [ ] gRPC service tests
- [ ] V-lang binding tests
- [ ] Protocol compatibility tests
- [ ] Performance benchmarks
- [ ] Streaming tests

## Run Tests

```bash
cd /var/mnt/eclipse/repos/v-grpc && cargo test
```
