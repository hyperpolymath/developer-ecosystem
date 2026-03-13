# Reversibility

This document describes how operations in Synapse can be undone and how to recover from mistakes.

## Core Principle

**Every operation can be undone.** Synapse is designed with reversibility as a first-class concern.

## Reversible Operations

### Code Generation

| Operation | How to Reverse |
|-----------|----------------|
| `just gen-ui` | Delete generated file, or regenerate from unchanged source |
| Wrong output path | Regenerate with correct path |
| Wrong iOS version | Regenerate with correct `--ios` flag |

Generated Swift files are always regenerable from Rust sources. The Rust files are the source of truth.

### Configuration Changes

| Operation | How to Reverse |
|-----------|----------------|
| Edit template | `git checkout src/templates/swift_templates.zig` |
| Edit parser | `git checkout src/parser/rust_parser.zig` |
| Change Justfile | `git checkout Justfile` |

### Build Artifacts

| Operation | How to Reverse |
|-----------|----------------|
| `zig build` | `just clean` or `rm -rf zig-out .zig-cache` |

## Non-Destructive Defaults

Synapse follows these principles:

1. **No implicit overwrites**: Generated files are clearly marked with "AUTO-GENERATED - DO NOT EDIT"
2. **No hidden state**: All configuration is explicit in command arguments or Justfile
3. **No side effects**: Generation only creates the specified output file
4. **Confirmation for risky operations**: None exist (by design)

## Recovery Scenarios

### "I accidentally deleted my Rust source"

```bash
# If committed:
git checkout -- examples/rust/models.rs

# If not committed:
# The Rust source is the canonical data. Recover from backup.
```

### "I generated to the wrong location"

```bash
# Delete the wrong file
rm /wrong/path/Generated.swift

# Regenerate to correct location
just gen-ui output=/correct/path/Generated.swift
```

### "The generated Swift has errors"

1. Check the Rust source for syntax issues
2. Check template compatibility with your iOS version
3. Regenerate: `just gen-ui`
4. If templates are broken: `git checkout src/templates/`

### "I broke the templates"

```bash
# Reset templates to last commit
git checkout src/templates/swift_templates.zig

# Or reset all Zig source
git checkout src/
```

### "I want to undo everything since last commit"

```bash
# See what changed
git status
git diff

# Undo all changes
git checkout -- .

# Or selectively
git checkout -- src/templates/
```

## Safe Experimentation

Synapse encourages experimentation through:

1. **Git history**: Every committed state is recoverable
2. **RVC tidying**: Automated cleanup prevents cruft
3. **Clear separation**: Source (Rust) vs Generated (Swift) are distinct
4. **Idempotent generation**: Running twice produces identical output

## Data Flow

```
Rust Source (canonical)
       ↓
   Synapse Generator
       ↓
Swift Output (regenerable)
```

The arrow is one-way. Swift output depends on Rust source, never the reverse.

## What Cannot Be Undone

1. **Uncommitted Rust changes**: If you delete source without committing, it's gone
2. **Force-pushed branches**: Standard Git warning applies
3. **Deleted branches**: Standard Git warning applies

## Best Practices

1. **Commit frequently**: Small, atomic commits are easier to reverse
2. **Use branches**: Experiment on feature branches, merge when confident
3. **Review before commit**: `git diff` shows exactly what changed
4. **Don't edit generated files**: They will be overwritten

## Contact

Questions about reversibility: Open an issue with the `reversibility` label.
