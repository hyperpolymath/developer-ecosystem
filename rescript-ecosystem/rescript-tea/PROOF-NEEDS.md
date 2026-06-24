# PROOF-NEEDS.md
<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->

## Current State

- **LOC**: ~24,000
- **Languages**: ReScript
- **Existing ABI proofs**: `src/abi/*.idr` (template-level)
- **Dangerous patterns**: 8+ `Obj.magic` calls in `src/tea/Tea_Render.res` (and duplicates in `lib/bs/` and `lib/ocaml/`)

## What Needs Proving

### VDOM Renderer Type Safety
- `Tea_Render.res` uses `Obj.magic` extensively for DOM node casting (`listener.element`, `container`, `domNode`)
- These are unsafe coercions between ReScript types and raw DOM objects
- The VDOM diff/patch algorithm should preserve node identity — this is provable

### Event Dispatch Correctness
- Event listener attachment/removal uses type-erased casts
- Prove: event handlers receive correctly-typed events after dispatch

### Reconciliation Algorithm
- The VDOM reconciler (patch/diff) should prove:
  - No orphaned DOM nodes after reconciliation
  - Key-based reconciliation preserves element identity
  - Attribute updates are idempotent

## Recommended Prover

- **Idris2** — model the VDOM tree as a dependent type, prove reconciliation preserves tree invariants
- Alternative: **Lean4** for equational reasoning about tree transformations

## Priority

**MEDIUM** — Core UI library used by multiple projects. `Obj.magic` is a pragmatic FFI boundary issue but the reconciliation algorithm correctness is architecturally important.

## Template ABI Cleanup (2026-03-29)

Template ABI removed -- was creating false impression of formal verification.
The removed files (Types.idr, Layout.idr, Foreign.idr) contained only RSR template
scaffolding with unresolved {{PROJECT}}/{{AUTHOR}} placeholders and no domain-specific proofs.
