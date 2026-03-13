<!-- SPDX-License-Identifier: MPL-2.0 -->
# idris2-echidna Roadmap

## Current Status: v0.1.0 Released

Overall completion: **85%**

## Component Status

| Component | Progress | Notes |
|-----------|----------|-------|
| Core Prover API | 95% | Prover, ProverKind, Theorem types complete with docs |
| Z3 Integration | 85% | Z3 SMT solver bindings working |
| CVC5 Integration | 80% | CVC5 bindings scaffolded |
| Other Provers | 75% | Lean, Coq, Agda, Isabelle scaffolded |
| Aspect System | 65% | Multi-aspect verification scaffolded |
| Neural Integration | 55% | Neural theorem proving hooks scaffolded |
| FFI Layer | 40% | FFI to native provers needs implementation |
| Examples | 90% | Comprehensive examples module |
| Tests | 90% | TestProver.idr with compile-time tests |
| Documentation | 90% | README with API reference, pack.toml |

## Milestones

### v0.1.0 - Core API ✅ Complete
- Type-safe prover selection
- SMT-LIB formula encoding
- Proof result types with dependent typing
- Multi-prover strategy support
- Integration-ready for dyadt claims

### v0.2.0 - Multiple Provers 🔄 In Progress
- [ ] Implement Z3 FFI calls
- [ ] Add CVC5 backend
- [ ] Test with real prover installations

### v0.3.0 - FFI Integration 📋 Planned
- [ ] Complete FFI layer
- [ ] Neural proof synthesis
- [ ] Aspect-based routing

### v1.0.0 - Production Ready 📋 Planned
- [ ] Full test coverage
- [ ] Performance optimization
- [ ] Comprehensive documentation

## Blockers & Issues

| Priority | Issue |
|----------|-------|
| High | FFI layer needs implementation for real prover calls |
| Medium | Neural integration is placeholder only |

## Critical Next Actions

| Timeframe | Action |
|-----------|--------|
| Immediate | Test with real Z3 installation |
| This Week | Implement CVC5 backend |
| This Month | Add fuzzing tests |

## Working Features

- Type-safe prover selection
- SMT-LIB formula encoding
- Proof result types with dependent typing
- Multi-prover strategy support
- Integration-ready for dyadt claims
- Comprehensive Examples.idr
- Pack package manager support
