<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-19 -->

# RSR Template Repo — Project Topology

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │              NEW REPOSITORY             │
                        │        (Consumer of this Template)      │
                        └───────────────────┬─────────────────────┘
                                            │ Scaffolding
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │           RSR TEMPLATE HUB              │
                        │                                         │
                        │  ┌───────────┐  ┌───────────────────┐  │
                        │  │ AI Gate-  │  │  ABI / FFI        │  │
                        │  │ keeper    │  │  Standard         │  │
                        │  │ (0-AI-M)  │  │ (Idris2/Zig)      │  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        │        │                 │              │
                        │  ┌─────▼─────┐  ┌────────▼──────────┐  │
                        │  │ Topology  │  │  SCM / 6SCM       │  │
                        │  │ Guide     │  │  Metadata         │  │
                        │  │ (Visual)  │  │ (machine_read)    │  │
                        │  └─────┬─────┘  └────────┬──────────┘  │
                        └────────│─────────────────│──────────────┘
                                 │                 │
                                 ▼                 ▼
                        ┌─────────────────────────────────────────┐
                        │          PLATFORM INTEGRATION           │
                        │  ┌───────────┐  ┌───────────┐  ┌───────┐│
                        │  │ GitHub    │  │ GitLab    │  │ Nix / ││
                        │  │ Workflows │  │ CI/CD     │  │ Guix  ││
                        │  └───────────┘  └───────────┘  └───────┘│
                        └─────────────────────────────────────────┘

                        ┌─────────────────────────────────────────┐
                        │          REPO INFRASTRUCTURE            │
                        │  Justfile / Mustfile  .machine_readable/  │
                        │  Codeowners / Reuse   0-AI-MANIFEST.a2ml  │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
CORE STANDARDS
  ABI/FFI Standard (Idris2/Zig)     ██████████ 100%    Universal interface stable
  AI Gatekeeper (0-AI-MANIFEST)     ██████████ 100%    Universal entry point active
  TOPOLOGY.md Standard              ██████████ 100%    Visual summary guide active
  6SCM Metadata Structure           ██████████ 100%    Machine-readable state stable

INFRASTRUCTURE
  Justfile Automation               ██████████ 100%    Standard build/verify tasks
  CI/CD Workflow Templates          ██████████ 100%    GH/GL scaffolding verified
  Multi-Forge Sync                  ██████████ 100%    Hub-and-spoke mirroring stable

REPO INFRASTRUCTURE
  .machine_readable/                ██████████ 100%    STATE/META/ECOSYSTEM active
  Governance & License              ██████████ 100%    PMPL & Ethical use verified
  Development Shells (Nix/Guix)     ██████████ 100%    Reproducible env stable

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ██████████ 100%    RSR Template Stable & Certified
```

## Key Dependencies

```
Philosophy ──────► RSR Standard ──────► Template Scaffolding ──► New Repo
     │                 │                      │                    │
     ▼                 ▼                      ▼                    ▼
CCCP Policy ─────► 0-AI-MANIFEST ────────► Justfile ──────────► Compliance
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
