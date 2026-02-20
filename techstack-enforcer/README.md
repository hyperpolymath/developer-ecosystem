# Techstack Enforcer

<!-- SPDX-License-Identifier: MPL-2.0-or-later -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

[![License](https://img.shields.io/badge/License-MPL_2.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![SPARK Verified](https://img.shields.io/badge/SPARK-verified-green)](https://www.adacore.com/about-spark)

A formally verified technology stack enforcement system written in Ada/SPARK. Blocks unwanted technologies **by every possible means** — git hooks, CI/CD pipelines, file watchers, container build guards — and notifies when blocking occurs. Includes an Ada/SPARK TUI for rapid policy management and a learning mode that analyses security failures to recommend safer languages by design.

## Intent

Techstack Enforcer exists to make language policy violations **impossible to ignore**. The enforcer itself is written in Ada/SPARK — a language with formal verification guarantees — so the enforcement engine cannot be compromised by the same class of memory-safety bugs it guards against. The core design principle is **absolute blocking at every layer**, not just advisory warnings that developers can skip.

## Overview

### Multi-Layer Blocking Architecture

Enforcement operates at every layer where code enters a repository:

| Layer | Mechanism | When It Fires |
|-------|-----------|---------------|
| **Layer 1: Pre-commit hooks** | `.git/hooks/pre-commit` | Before any local commit |
| **Layer 2: Pre-push hooks** | `.git/hooks/pre-push` | Before pushing to remote |
| **Layer 3: CI/CD pipelines** | GitLab CI / GitHub Actions | On every MR/PR and push to main |
| **Layer 4: File watchers** | GitVisor integration | Real-time, on file change |
| **Layer 5: Container guards** | Containerfile pre-build check | Before any container build |
| **Layer 6: Commit-msg hooks** | `.git/hooks/commit-msg` | Validates commit metadata |

Every violation triggers desktop notifications (`notify-send`), structured logging, and optional webhook alerts. In lockdown mode, violations are **fatal** — no workaround, no override.

### Features

- **Formally Verified Core**: SPARK-proven enforcement engine — no buffer overflows, no null dereferences, no undefined behaviour in the enforcer itself
- **Multi-Layer Enforcement**: Git hooks + CI/CD + file watchers + container guards
- **Ada/SPARK TUI**: Keyboard-driven interface for managing filters in real time
- **Learning Mode**: Analyses CVE patterns and security failures to recommend safer languages
- **Definition Sets**: Pre-configured policies (strict, moderate, enterprise)
- **JSON API**: Structured allow/deny decisions for automation and tool integration
- **Desktop Notifications**: `notify-send` alerts on every violation
- **Composable Policies**: Layer multiple filterlists with inheritance and overrides

## Quick Start

```bash
# Build with SPARK verification
gprbuild -P techstack_enforcer.gpr -XMODE=release
gnatprove -P techstack_enforcer.gpr --level=2

# Audit a repository
./bin/techstack_main audit .

# Use a definition set
./bin/techstack_main --defset=strict audit .

# Get JSON decisions for automation
./bin/techstack_main decide src/main.py

# Launch the TUI
./bin/techstack_tui_main

# Install hooks across all repos
./scripts/install-repo-hooks.sh /path/to/repo
```

## Architecture

```
techstack-enforcer/
├── src/
│   ├── core/                        # SPARK-verified enforcement engine
│   │   ├── techstack_enforcer.ads       # Core logic (SPARK_Mode)
│   │   ├── techstack_types.ads          # Type definitions with dependent types
│   │   ├── techstack_patterns.ads       # Glob pattern matching
│   │   ├── techstack_defsets.ads        # Definition set loading
│   │   └── techstack_json_io.ads        # JSON API output
│   ├── tui/                         # Ada/SPARK Terminal User Interface
│   │   └── techstack_tui.ads            # ncurses-based TUI
│   ├── learning/                    # Security failure analysis
│   │   └── techstack_learning.ads       # CVE → language recommendation
│   ├── hooks/                       # Git hook integration
│   │   └── techstack_hook.adb           # Pre-commit/pre-push/commit-msg
│   ├── techstack_main.adb           # CLI entry point
│   └── techstack_tui_main.adb       # TUI entry point
├── src/abi/                         # Idris2 ABI definitions (planned)
├── ffi/zig/                         # Zig FFI bridge (planned)
├── config/
│   └── techstack.toml               # Main configuration
├── defsets/                         # Pre-configured policy sets
│   ├── strict.toml                      # Maximum memory safety
│   ├── moderate.toml                    # Balanced with exceptions
│   └── enterprise.toml                  # Corporate/legacy support
├── hooks/                           # Hook scripts for CI/CD
├── ci-templates/                    # Reusable CI/CD templates
│   ├── gitlab-ci-techstack.yml
│   └── github-action-techstack.yml
└── scripts/                         # Installation and helper scripts
    ├── install.sh
    └── install-repo-hooks.sh
```

## The TUI

The Ada/SPARK TUI provides rapid, keyboard-centric filter management:

```
==========================================
     TECHSTACK ENFORCER v1.0
     Ada/SPARK Filter Management TUI
==========================================
  Mode: [ENFORCE] - Blocking enabled

  FILTER LIST (45 entries)
  -----------------------------------------------
 > [#] *.py                     | Python: No static typing...
   [#] *.php                    | PHP: Memory-unsafe, injection...
   [X] *.c                      | C: Manual memory management
   [!] *.sh                     | Shell script - verify manually
   [+] *.rs                     | Rust: Memory-safe with ownership

  [a]dd [e]dit [d]elete [Space]toggle [1-4]mode [s]can [?]help [q]uit
```

| Key | Action |
|-----|--------|
| `a` | Add new filter |
| `d` | Delete filter |
| `e` | Edit filter |
| `l` | Toggle learning mode |
| `s` | Scan repository |
| `1`-`4` | Switch mode (Learning/Warn/Enforce/Lockdown) |
| `w` | Save configuration |
| `j`/`k` | Navigate up/down |
| `q` | Quit |

## Learning Mode

The learning engine analyses security failures and recommends language changes that would prevent entire vulnerability classes by design:

| Vulnerability Type | Recommended Languages |
|--------------------|----------------------|
| Buffer overflow | Rust, Ada/SPARK, Haskell, OCaml |
| Null dereference | Rust, Haskell, ReScript, Elm |
| Race condition | Elixir, Erlang, Rust, Haskell |
| Injection attack | Haskell, Rust, ReScript, Elm |
| Use-after-free | Rust, Ada/SPARK, Haskell |
| Integer overflow | Ada/SPARK, Rust, Haskell |
| Type confusion | Haskell, OCaml, Rust, ReScript |
| Memory leak | Rust, Ada/SPARK, Haskell, Elixir |

Learning mode integrates with the NVD 2.0 CVE API to correlate real-world vulnerabilities with language design features. When enabled, it observes violations without blocking (useful for onboarding), builds a pattern database, and surfaces actionable recommendations via the TUI and JSON API.

## Enforcement Levels

| Level | Symbol | Behaviour |
|-------|--------|-----------|
| Fatal | `#` | **Always blocked** — no override, no exception |
| Block | `X` | Blocked in enforce and lockdown modes |
| Warn | `!` | Warning only (blocked in lockdown) |
| Allow | `+` | Explicitly permitted |

## Enforcement Modes

| Mode | Behaviour |
|------|-----------|
| **Learning** | Observe and log only, never block |
| **Warn** | Show warnings, allow all operations |
| **Enforce** | Block on Block and Fatal violations |
| **Lockdown** | Block on **all** violations including Warn |

## Definition Sets

| Set | Mode | Description |
|-----|------|-------------|
| `strict` | lockdown | Maximum memory safety — blocks all unsafe languages |
| `moderate` | enforce | Balanced safety with practical exceptions |
| `permissive` | warn | Advisory only — warns but rarely blocks |
| `enterprise` | enforce | Corporate/legacy support |
| `memory_safe` | enforce | Focus on memory safety — blocks C/C++/Assembly |

## Notification System

Every violation triggers notifications through multiple channels:

- **Desktop**: `notify-send` with urgency level matching violation severity
- **Log**: Structured log file (`techstack.log`) with JSON entries
- **Webhook**: Optional HTTP POST to external services (Slack, Teams, etc.)
- **Syslog**: Optional syslog integration for centralised monitoring

If learning mode is enabled, violations also trigger the analysis engine which correlates the blocked pattern with the CVE database and surfaces recommendations.

## CI/CD Integration

**GitLab CI:**
```yaml
include:
  - project: 'your-group/techstack-enforcer'
    file: '/ci-templates/gitlab-ci-techstack.yml'

variables:
  TECHSTACK_DEFSET: moderate
```

**GitHub Actions:** See [ci-templates/github-action-techstack.yml](ci-templates/github-action-techstack.yml)

## Philosophy

Techstack Enforcer is opinionated by design. It enforces preferences for:

1. **Memory-safe languages** — Rust, Ada/SPARK, Haskell, Elixir, ReScript
2. **Static typing** — type errors caught at compile time, not in production
3. **Formal verification** — the enforcer itself is SPARK-verified
4. **Open infrastructure** — Podman over Docker, GitLab alongside GitHub
5. **Absolute blocking** — violations are not suggestions, they are walls

The core insight: **the best security fix is a language that makes the vulnerability class impossible**. A buffer overflow cannot happen in Rust. A null pointer exception cannot happen in Haskell. A race condition is structurally prevented by the actor model in Elixir. Rather than patching symptoms, Techstack Enforcer prevents the disease.

## Commands

| Command | Description |
|---------|-------------|
| `audit <path>` | Full repository audit with statistics |
| `decide [path]` | JSON allow/deny decisions |
| `check <path>` | Check single file/directory |
| `list` | Show all configured filters |
| `defsets` | List available definition sets |
| `init` | Initialise with default filters |
| `version` | Show version information |

## Building

Requirements: GNAT Ada compiler, GPRbuild

```bash
# Debug build
gprbuild -P techstack_enforcer.gpr -XMODE=debug

# Release build
gprbuild -P techstack_enforcer.gpr -XMODE=release

# SPARK formal verification
gnatprove -P techstack_enforcer.gpr --level=2
```

## Documentation

- [Getting Started](docs/getting-started.md) — Installation and first steps
- [CLI Reference](docs/cli-reference.md) — Complete command reference
- [Definition Sets](docs/definition-sets.md) — Pre-configured policies
- [TUI Guide](docs/tui-guide.md) — Interactive interface
- [CI Integration](docs/ci-integration.md) — Pipeline setup
- [API & JSON Format](docs/api-json-format.md) — Automation interface

## License

PMPL-1.0-or-later (MPL-2.0 fallback for platform compatibility). See [license/PMPL-1.0.txt](license/PMPL-1.0.txt).
