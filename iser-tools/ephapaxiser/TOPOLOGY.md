<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->
# TOPOLOGY — ephapaxiser

Repository structure and module relationships for ephapaxiser.

## Directory Map

```
ephapaxiser/
├── 0-AI-MANIFEST.a2ml              # AI agent entry point (read first)
├── Cargo.toml                      # Rust package definition
├── Justfile                        # Task runner recipes
├── Containerfile                   # OCI container build (Chainguard base)
├── contractile.just                # Contractile CLI recipes
├── LICENSE                         # PMPL-1.0-or-later
├── README.adoc                     # Project overview
├── ROADMAP.adoc                    # Phase plan (0-6)
├── TOPOLOGY.md                     # THIS FILE
├── SECURITY.md                     # Security policy
├── CONTRIBUTING.adoc               # Contribution guide
├── CHANGELOG.md                    # Release notes
│
├── src/                            # Rust source code
│   ├── main.rs                     # CLI entry point (clap subcommands)
│   ├── lib.rs                      # Library root (re-exports)
│   ├── manifest/                   # ephapaxiser.toml parser and validator
│   │   └── mod.rs                  # Manifest, WorkloadConfig, DataConfig, Options
│   ├── codegen/                    # Ephapax wrapper code generation
│   │   └── mod.rs                  # generate_all, build, run (stubs)
│   ├── abi/                        # Rust-side ABI module
│   │   └── mod.rs                  # Idris2 proof type bindings
│   ├── core/                       # Core analysis logic (future)
│   ├── errors/                     # Error types
│   ├── aspects/                    # Cross-cutting concerns
│   ├── bridges/                    # Language bridge adapters
│   ├── contracts/                  # Runtime contract checking
│   ├── definitions/                # Resource type definitions
│   │
│   └── interface/                  # Verified Interface Seams
│       ├── abi/                    # Idris2 ABI — THE SPEC
│       │   ├── Types.idr           # LinearResource, UsageCount, ConsumeProof,
│       │   │                       #   ResourceLifecycle, Platform, Handle, Result
│       │   ├── Layout.idr          # Resource tracking struct layout, padding,
│       │   │                       #   alignment proofs, C ABI compliance
│       │   └── Foreign.idr         # FFI declarations: init, free, process,
│       │                           #   resource analysis, linearity enforcement
│       ├── ffi/                    # Zig FFI — THE BRIDGE
│       │   ├── build.zig           # Shared + static library build config
│       │   ├── src/
│       │   │   └── main.zig        # C-ABI implementation of Foreign.idr decls
│       │   └── test/
│       │       └── integration_test.zig  # FFI compliance tests
│       └── generated/              # Auto-generated C headers (THE RESULT)
│           └── abi/                # Generated header files
│
├── container/                      # Stapeln container ecosystem
├── docs/                           # Technical documentation
│   ├── architecture/               # Topology, diagrams, threat model
│   ├── attribution/                # Citations, owners, maintainers
│   ├── decisions/                  # Architecture Decision Records
│   ├── developer/                  # Developer guides
│   ├── governance/                 # Governance documents
│   ├── legal/                      # Legal exhibits
│   ├── practice/                   # How-to manuals
│   ├── reports/                    # Generated reports
│   ├── standards/                  # Standards references
│   ├── templates/                  # Document templates
│   ├── theory/                     # Domain theory
│   ├── whitepapers/                # Whitepapers
│   └── wikis/                      # Wiki content
│
├── examples/                       # Usage examples
├── features/                       # Feature specifications
├── tests/                          # Integration tests
├── verification/                   # Formal verification artifacts
│
├── .machine_readable/              # ALL machine-readable metadata
│   ├── 6a2/                        # A2ML state files
│   │   ├── STATE.a2ml              # Project state, progress, blockers
│   │   ├── META.a2ml               # Architecture decisions, governance
│   │   ├── ECOSYSTEM.a2ml          # Position in -iser ecosystem
│   │   ├── AGENTIC.a2ml            # AI agent constraints
│   │   ├── NEUROSYM.a2ml           # Hypatia neurosymbolic config
│   │   └── PLAYBOOK.a2ml           # Operational runbook
│   ├── ai/                         # AI configuration
│   ├── anchors/                    # Semantic boundary declarations
│   ├── bot_directives/             # Bot-specific instructions
│   ├── compliance/                 # REUSE dep5, cargo-deny
│   ├── configs/                    # git-cliff, etc.
│   ├── contractiles/               # K9, must, trust, dust, lust
│   ├── integrations/               # proven, verisimdb, vexometer
│   ├── policies/                   # Maintenance axes, checklist, SDA
│   └── scripts/                    # Forge sync, lifecycle, verification
│
├── .github/                        # GitHub workflows and community files
├── .hypatia/                       # Hypatia scanner rules
├── .claude/                        # Claude Code project instructions
└── .well-known/                    # Well-known URIs
```

## Data Flow

```
                  ephapaxiser.toml
                       │
              ┌────────▼────────┐
              │  Manifest Parser │  (src/manifest/mod.rs)
              │  parse + validate│
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │ Resource Analyser│  (src/core/ — future)
              │ detect handles,  │
              │ map acquire/free │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │   Idris2 ABI     │  (src/interface/abi/)
              │ LinearResource   │
              │ ConsumeProof     │
              │ UsageCount       │
              │ PROVES linearity │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │    Zig FFI       │  (src/interface/ffi/)
              │ C-ABI bridge     │
              │ zero overhead    │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │ Ephapax Codegen  │  (src/codegen/mod.rs)
              │ emit wrappers    │
              │ Rust / C / Zig   │
              └────────┬────────┘
                       │
                       ▼
              wrapped source code
              (compile-time safe)
```

## Key Invariants

1. **Idris2 wins**: When Idris2 proofs conflict with Ephapax linear types,
   the proofs are authoritative. Adjust wrappers, never proofs.
2. **Single-use**: Every wrapped resource must be consumed exactly once.
   This is enforced structurally, not by convention.
3. **Zero runtime overhead**: All linearity proofs are erased at compile time.
4. **Machine-readable in `.machine_readable/` only**: No state files in root.

## Ecosystem Position

Part of the [hyperpolymath -iser family](https://github.com/hyperpolymath/iseriser).
Siblings include typedqliser, chapeliser, verisimiser, and 26+ others.
