# rescript-env - AI Assistant Instructions

## Project Overview

This is `rescript-env`, a type-safe environment variable library for ReScript. Part of the [ReScript Full Stack](https://github.com/hyperpolymath/rescript-full-stack) ecosystem.

## Machine-Readable Artefacts

The following files in `.machine_readable/` contain structured project metadata:

- `STATE.scm` - Current project state and progress
- `META.scm` - Architecture decisions and development practices
- `ECOSYSTEM.scm` - Position in the ecosystem and related projects
- `AGENTIC.scm` - AI agent interaction patterns
- `NEUROSYM.scm` - Neurosymbolic integration config
- `PLAYBOOK.scm` - Operational runbook

---

## Development Guidelines

### Language Policy

| Language | Use Case |
|----------|----------|
| **ReScript** | All library code (src/*.res, src/*.resi) |
| **JavaScript** | Only compiled output (.res.js) - never hand-written |
| **Deno** | Runtime and task runner |
| **Guile Scheme** | Machine-readable metadata files |

### BANNED

- TypeScript (use ReScript)
- Node.js/npm/yarn/pnpm/bun (use Deno)
- Go, Python, Java, Kotlin, Swift

### Key Files

```
src/Env.res      # Main implementation
src/Env.resi     # Public interface (API surface)
deno.json        # Deno configuration
rescript.json    # ReScript compiler config
justfile         # Task runner
```

### Building

```bash
just build       # Compile ReScript
just dev         # Watch mode
just test        # Run tests
just quality     # All checks
```

### Code Style

- Use `@@uncurried` for all modules
- Prefer `option` types over nullable values
- Use pattern matching over if/else
- Document public API with `/** */` comments
- Keep functions small and focused

### When Modifying Code

1. Read `src/Env.resi` to understand the public API
2. Make changes in `src/Env.res`
3. Update the interface in `src/Env.resi` if API changes
4. Run `just build` to verify compilation
5. Update documentation if needed

### Architecture Decisions

See `.machine_readable/META.scm` for ADRs:

- **ADR-001**: Runtime detection via globalThis
- **ADR-002**: Option types for missing values
- **ADR-003**: ESM-only output
- **ADR-004**: Boolean parsing values

### Security Requirements

- No hardcoded secrets
- HTTPS only for all URLs
- SPDX license headers on all source files

---

## Common Tasks

### Add a new API function

1. Add implementation in `src/Env.res`
2. Export in `src/Env.resi`
3. Add documentation in README.adoc
4. Update CHANGELOG.adoc

### Update dependencies

1. Edit `rescript.json` for ReScript deps
2. Edit `deno.json` for Deno deps
3. Run `just build` to verify

### Prepare a release

1. Update version in `deno.json`
2. Update CHANGELOG.adoc
3. Update STATE.scm version
4. Create git tag
