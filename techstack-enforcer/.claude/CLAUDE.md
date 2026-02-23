# CLAUDE.md - AI Assistant Instructions for techstack-enforcer

## Project Overview

Techstack Enforcer is a formally verified technology stack enforcement system written in Ada/SPARK. It blocks unwanted technologies by every possible means: git hooks, CI/CD, file watchers, container guards.

## Machine-Readable Artefacts

The following files in `.machine_readable/` contain structured project metadata:

- `STATE.scm` - Current project state and progress
- `META.scm` - Architecture decisions and development practices
- `ECOSYSTEM.scm` - Position in the ecosystem and related projects
- `AGENTIC.scm` - AI agent interaction patterns
- `NEUROSYM.scm` - Neurosymbolic integration config
- `PLAYBOOK.scm` - Operational runbook

## Build Commands

```bash
# Build
gprbuild -P techstack_enforcer.gpr -XMODE=release

# SPARK verification
gnatprove -P techstack_enforcer.gpr --level=2

# Run audit
./bin/techstack_main audit .

# Launch TUI
./bin/techstack_tui_main
```

## Critical Invariants

- Core engine (src/core/) MUST use SPARK_Mode
- Multi-layer blocking: never remove a blocking layer
- Learning mode MUST NOT block (observe-only)
- Lockdown mode MUST block ALL violations including Warn
- All enforcement decisions flow through the formally verified core

## Language Policy

This project is written in Ada/SPARK. See hyperpolymath/mustfile for the standard language policy.
