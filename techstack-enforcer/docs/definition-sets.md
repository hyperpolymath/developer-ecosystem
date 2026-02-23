# Definition Sets

Definition Sets are pre-configured collections of filter rules that implement coherent enforcement policies. They provide ready-to-use configurations for common use cases.

## Available Definition Sets

### strict

**Maximum memory safety enforcement.**

- **Default Mode:** `lockdown`
- **Philosophy:** Block all memory-unsafe and dynamically-typed languages
- **Use Case:** Safety-critical systems, security-sensitive applications

**Blocked (Fatal):**
- Python (`*.py`, `requirements.txt`, `Pipfile`, etc.)
- PHP (`*.php`, `composer.json`)
- Ruby (`*.rb`, `Gemfile`)
- Perl (`*.pl`, `*.pm`)

**Blocked:**
- C/C++ (`*.c`, `*.cpp`, `*.h`, `*.hpp`)
- JavaScript (`*.js`, `*.jsx`, `*.mjs`)
- Assembly (`*.asm`, `*.s`)
- Docker (`Dockerfile`, `docker-compose.yml`)
- GitHub Actions (`.github/**`)

**Allowed:**
- Rust, Ada/SPARK, Haskell, OCaml, Elm
- Elixir, Erlang, ReScript
- Nix, GitLab CI, Containerfile

```bash
techstack-enforcer --defset=strict audit .
```

---

### moderate

**Balanced safety with practical exceptions.**

- **Default Mode:** `enforce`
- **Philosophy:** Block high-risk languages, warn on others
- **Use Case:** Most projects wanting good practices

**Blocked (Fatal):**
- Python, PHP

**Blocked:**
- C/C++ core files

**Warned:**
- JavaScript (prefer TypeScript)
- Ruby, Perl
- Docker, GitHub Actions

**Allowed:**
- Rust, Go, TypeScript, Haskell
- Ada/SPARK, Elixir, Elm, Zig

```bash
techstack-enforcer --defset=moderate audit .
```

---

### permissive

**Advisory mode - warns but rarely blocks.**

- **Default Mode:** `warn`
- **Philosophy:** Inform developers without blocking
- **Use Case:** Gradual adoption, legacy codebases

**Warned (not blocked):**
- Python, PHP, C/C++
- JavaScript, Ruby
- Docker

**Allowed:**
- Everything else with informational messages

```bash
techstack-enforcer --defset=permissive audit .
```

---

### enterprise

**Corporate environments with legacy language support.**

- **Default Mode:** `enforce`
- **Philosophy:** Approved language list with legacy tolerance
- **Use Case:** Enterprise environments

**Blocked:**
- Python, PHP, Ruby, Perl (not approved)

**Warned (legacy):**
- C/C++ (migration planned)
- JavaScript (prefer TypeScript)
- Shell scripts (review for secrets)

**Allowed:**
- Java, Kotlin, Go, Rust
- TypeScript, C#, Scala
- Haskell, Ada/SPARK
- Terraform, SQL

```bash
techstack-enforcer --defset=enterprise audit .
```

---

### memory_safe

**Focus on memory safety only.**

- **Default Mode:** `enforce`
- **Philosophy:** Block only memory-unsafe languages
- **Use Case:** Systems programming safety

**Blocked:**
- C, C++, Assembly

**Warned:**
- D, Nim, Zig (verify memory mode)

**Allowed:**
- All GC-based languages (Python, Java, Go, etc.)
- Rust, Ada/SPARK
- Haskell, OCaml, Elixir

```bash
techstack-enforcer --defset=memory_safe audit .
```

---

## Using Definition Sets

### Command Line

```bash
# Use a definition set
techstack-enforcer --defset=strict audit .

# Override mode
techstack-enforcer --defset=moderate --mode=lockdown audit .

# With decide command
techstack-enforcer --defset=enterprise decide src/
```

### CI/CD

**GitLab CI:**
```yaml
variables:
  TECHSTACK_DEFSET: moderate

techstack:check:
  script:
    - techstack-enforcer --defset=$TECHSTACK_DEFSET audit .
```

**GitHub Actions:**
```yaml
env:
  TECHSTACK_DEFSET: moderate

- run: techstack-enforcer --defset=$TECHSTACK_DEFSET audit .
```

---

## Definition Set Files

Pre-built TOML files are available in the `defsets/` directory:

```
defsets/
├── strict.toml
├── moderate.toml
└── enterprise.toml
```

These can be used as templates for custom configurations.

---

## Creating Custom Sets

You can create custom definition sets by:

1. Copying an existing set from `defsets/`
2. Modifying the filters
3. Loading with `--config=`

```bash
cp defsets/moderate.toml my-policy.toml
# Edit my-policy.toml
techstack-enforcer --config=my-policy.toml audit .
```

---

## Combining Sets with Custom Filters

Definition sets can be combined with additional custom filters:

```bash
# Load moderate set, then apply custom config
techstack-enforcer --defset=moderate --config=overrides.toml audit .
```

The custom config will override or extend the definition set.

## See Also

- [Configuration](./configuration.md)
- [Block Levels](./block-levels.md)
- [Enforcement Modes](./enforcement-modes.md)
