<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-19 -->

# Spindle (loom-registry) — Project Topology

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │              OPERATOR / CLI             │
                        │        (cabal run spindle -- config.ncl)│
                        └───────────────────┬─────────────────────┘
                                            │
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │           SPINDLE CORE (HASKELL)        │
                        │                                         │
                        │  ┌───────────┐  ┌───────────────────┐  │
                        │  │  Nickel   │  │   Evaluation      │  │
                        │  │  Parser   │──►   Stage           │  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        │        │                 │              │
                        │        └────────┬────────┘              │
                        │                 ▼                       │
                        │        ┌────────────────┐               │
                        │        │  JSON Bridge   │               │
                        │        │  (Aeson)       │               │
                        │        └────────┬────────┘              │
                        └─────────────────│───────────────────────┘
                                          │
                                          ▼
                        ┌─────────────────────────────────────────┐
                        │           HASKELL DATA TYPES            │
                        │    (Type-safe config records, Aeson)    │
                        └──────────┬───────────────────┬──────────┘
                                   │                   │
                                   ▼                   ▼
                        ┌───────────────────────┐  ┌────────────────────────────────┐
                        │ CONFIG REGISTRY       │  │ WASM BACKEND (WASI)            │
                        │ - Local storage       │  │ - GHC wasm32-wasi              │
                        │ - Version tracking    │  │ - Standalone execution         │
                        └───────────────────────┘  └────────────────────────────────┘

                        ┌─────────────────────────────────────────┐
                        │          REPO INFRASTRUCTURE            │
                        │  Justfile Automation  .machine_readable/  │
                        │  Nickel Configs (ncl) RSR Silver (Doc)    │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
CORE PIPELINE (HASKELL)
  Nickel Parser (hnickel)           ██████████ 100%    Native integration active
  Evaluation Stage                  ██████████ 100%    Contract validation stable
  JSON Bridge (Aeson)               ██████████ 100%    Interop verified
  Haskell Type Decoding             ██████████ 100%    Generic deriving active

REGISTRY & TOOLS
  Config Registry Logic             ██████░░░░  60%    Local storage stable
  CLI Interface                     ████░░░░░░  40%    Argument parsing refining
  WASM Compilation (WASI)           ██░░░░░░░░  20%    GHC native target testing

REPO INFRASTRUCTURE
  Justfile Automation               ██████████ 100%    Standard build/test tasks
  .machine_readable/                ██████████ 100%    STATE tracking active
  Dogfooding (build.ncl)            ██████████ 100%    Project config via Spindle

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ████░░░░░░  ~40%   Infrastructure stable, Core 15%
```

## Key Dependencies

```
Nickel Source ───► hnickel ──────► Evaluation ──────► JSON (Aeson)
     │               │                │                 │
     ▼               ▼                ▼                 ▼
Config Spec ───► Contract ──────► Provenance ──────► Haskell Type
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
