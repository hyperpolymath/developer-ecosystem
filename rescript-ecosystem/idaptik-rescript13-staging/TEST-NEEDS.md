# TEST-NEEDS — idaptik-rescript13-staging

## CRG Grade: C — ACHIEVED 2026-04-04

License: AGPL-3.0-or-later (co-developed with Joshua B. Jewell)

### Test Inventory

| Category | Status | Location | Notes |
|---|---|---|---|
| Unit | PASS | `sync-server/test/router_test.exs`, `shared/tests/deno/*.js` | Router HTTP contract + coprocessor unit tests |
| Smoke | PASS | `sync-server/test/application_test.exs` | OTP supervisor/process smoke tests |
| Property-based (P2P) | PASS | `sync-server/test/property_test.exs` | 5 StreamData properties |
| E2E | PASS | `shared/tests/deno/coprocessor_test.js` | Coprocessor domain pipeline |
| Reflexive | PASS | `sync-server/test/router_test.exs` | Same-args → same-status assertions |
| Contract | PASS | `sync-server/test/router_test.exs` | HTTP API invariants |
| Aspect | PASS | `shared/tests/deno/coprocessor_security_test.js` | Security/resilience cross-cutting |
| Benchmarks (baselined) | PASS | `shared/tests/deno/benchmark_test.js` | 10 timing-budget assertions |

New files added for CRG C:
- `sync-server/test/property_test.exs` — 5 StreamData property tests
- `shared/tests/deno/benchmark_test.js` — 10 performance baseline tests

### Commands

```sh
# Elixir tests (sync-server)
cd sync-server && mix test

# Specific property tests
cd sync-server && mix test test/property_test.exs

# Deno benchmarks
deno test --allow-read --no-check shared/tests/deno/benchmark_test.js

# All Deno shared tests (existing)
deno test --allow-read --no-check shared/tests/deno/
```

### Notes

- `stream_data ~> 1.0` added as test-only dep to `sync-server/mix.exs`.
- Benchmark tests use inline reference implementations for Coprocessor_IO
  pure functions (decodePath/encodePath/splitAtNull) because @rescript/core
  imports in `.res.mjs` files require the full Deno npm cache to be warm.
- The `Coprocessor.res.mjs` (no external deps) is loaded directly for Domain.toString benchmarks.

### Next: CRG Grade B

Requires 6 quality targets.
See `.machine_readable/6a2/STATE.a2ml` for details.
