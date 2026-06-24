<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# idris2-dyadt Roadmap

## Current Status: v0.1.0 Released

Overall completion: **90%**

## Component Status

| Component | Progress | Notes |
|-----------|----------|-------|
| Claim Types | 98% | Claim data type with rich constructors |
| Evidence Types | 95% | AllOf/AnyOf evidence combinators |
| Verdict Types | 90% | Verified/Contested verdict types |
| Verifier | 85% | Claim verification infrastructure |
| Combinators | 90% | Claim combination utilities |
| Echidna Integration | 95% | Integration with idris2-echidna |
| CNO Integration | 95% | Integration with idris2-cno |
| Examples | 95% | Comprehensive claim verification examples |
| Tests | 95% | TestClaims.idr with compile-time proofs |
| Documentation | 95% | README with API reference, pack.toml |

## Milestones

### v0.1.0 - Core Types ✅ Complete
- Claims as dependent types
- Evidence as proof terms
- Compile-time claim verification

### v0.2.0 - Integrations ✅ Complete
- Integration with echidna provers
- Integration with CNO identity proofs
- Deployment pipeline examples

### v0.3.0 - Runtime Verification 🔄 In Progress
- [ ] Dynamic claim verification
- [ ] External evidence loading
- [ ] Hybrid compile/runtime verification

### v1.0.0 - Production Ready 📋 Planned
- [ ] Full test coverage
- [ ] Performance optimization
- [ ] Comprehensive documentation

## Blockers & Issues

| Priority | Issue |
|----------|-------|
| Medium | Evidence module uses believe_me in some places |
| Low | More claim types could be added |

## Critical Next Actions

| Timeframe | Action |
|-----------|--------|
| Immediate | Add fuzzing tests |
| This Week | Implement runtime verification fallback |
| This Month | Submit to pack-db |

## Working Features

- Claims as dependent types
- Evidence as proof terms
- Compile-time claim verification
- AllOf/AnyOf evidence combinators
- Integration with echidna provers
- Integration with CNO identity proofs
- Deployment pipeline examples
- Pack package manager support

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Application                          │
└─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
                          ┌─────────────┐
                          │ idris2-dyadt │
                          │  (claims)    │
                          └─────────────┘
                           │           │
              ┌────────────┘           └────────────┐
              ▼                                     ▼
       ┌─────────────┐                       ┌─────────┐
       │ idris2-     │                       │idris2-  │
       │ echidna     │                       │  cno    │
       │ (provers)   │                       │(CNOs)   │
       └─────────────┘                       └─────────┘
```
