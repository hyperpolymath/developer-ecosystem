# CLAUDE.md - AI Assistant Guide for aggregate-library (aLib)

This document provides context for AI assistants working with the aggregate-library codebase.

## Project Overview

**aggregate-library (aLib)** is a methods/research repository demonstrating how to build a minimal "overlap" library across diverse programming systems. It serves as a proof-of-concept for **spec-driven, conformance-tested** library development.

### What This Is

- A **methods demonstration** for cross-system library overlap
- A **stress-test** for specification clarity and conformance testing
- A **reference implementation** in ReScript showing the methodology

### What This Is NOT

- NOT a replacement for ecosystem standard libraries
- NOT a proposal that all languages share one stdlib
- NOT a dependency to import - implementations borrow the **method**, not the code

## Core Methodology

### The aLib Approach

1. **Specification First**: Define minimal overlap as formal specs
   - Interface signatures
   - Behavioral semantics with properties
   - Executable test cases in YAML

2. **Conformance Testing**: Validate implementations against specs
   - Parse test cases from spec files
   - Run against implementations
   - Report conformance

3. **Reversibility**: Changes must be easy to evaluate and undo
   - Clear spec boundaries
   - Comprehensive test coverage
   - No hidden dependencies

4. **Ecosystem Neutrality**: No "blessed" implementation
   - Method applies to any language
   - ReScript is a reference, not a requirement

## Repository Structure

```
aggregate-library/
├── specs/                          # Specification files (22 operations)
│   ├── arithmetic/                 # add, subtract, multiply, divide, modulo
│   ├── comparison/                 # equal, not_equal, less_than, etc.
│   ├── logical/                    # and, or, not
│   ├── collection/                 # map, filter, fold, contains
│   ├── string/                     # concat, length, substring
│   └── conditional/                # if_then_else
├── src/
│   ├── ALib.mres                   # Complete ReScript implementation
│   ├── InterOp/                    # JavaScript interop utilities
│   └── schema/                     # Nickel schema definitions
├── scripts/
│   ├── validate-specs.ts           # Spec format validator (Deno)
│   └── run-conformance-tests.ts    # Conformance test runner (Deno)
├── test/                           # Implementation tests
├── deno.json                       # Deno configuration
└── Justfile                        # Command runner
```

## Technology Stack

Per hyperpolymath language policy:

**Allowed**:
- ✅ **ReScript**: Primary implementation language (compiles to JS)
- ✅ **Deno**: Test runner and validation scripts (NOT Node/npm/bun)
- ✅ **Nickel**: Configuration language for schemas
- ✅ **Rust, Gleam, Elixir**: Optional alternative implementations

**Banned**:
- ❌ TypeScript (use ReScript instead)
- ❌ Node.js, npm, Bun (use Deno instead)
- ❌ Python, Go (use Rust/Gleam/Elixir instead)

## Development Workflow

### 1. Adding a New Operation

```bash
# 1. Create specification file
# specs/<category>/<operation>.md with:
#   - Interface Signature
#   - Behavioral Semantics (properties, edge cases)
#   - Executable Test Cases (YAML)

# 2. Implement in ReScript
# Add to src/ALib.mres in appropriate module

# 3. Validate specification format
deno task validate:specs

# 4. Run conformance tests
deno task test

# 5. Update documentation
# Update README.adoc with new operation
```

### 2. Running Validations

```bash
# Validate all specs
just validate

# Run conformance tests
deno task test

# Check everything
just check
```

### 3. Extending to Other Languages

To create an implementation in another language:

1. Read the spec files in `specs/`
2. Implement the operations matching the interface signatures
3. Extract test cases from the YAML blocks
4. Run your implementation against the test cases
5. Report conformance results

## Specification Format

Each spec file must have these sections:

```markdown
# Operation: operation_name

## Interface Signature
\`\`\`
operation_name: Type1, Type2 -> ResultType
\`\`\`

## Behavioral Semantics

**Purpose**: Brief description

**Parameters**:
- param1: Description
- param2: Description

**Return Value**: Description

**Properties**:
- Mathematical/logical properties (commutative, associative, etc.)

**Edge Cases**:
- Overflow, underflow, division by zero, etc.

## Executable Test Cases

\`\`\`yaml
test_cases:
  - input: [arg1, arg2]
    output: expected_result
    description: "Test description"
\`\`\`
```

## aLib Implementation (src/ALib.mres)

The ReScript implementation is organized into modules:

- **Arithmetic**: add, subtract, multiply, divide, modulo
- **Comparison**: equal, notEqual, lessThan, lessEqual, greaterThan, greaterEqual
- **Logical**: and_, or_, not_
- **Collection**: map, filter, fold, contains
- **String**: concat, length, substring
- **Conditional**: ifThenElse

All operations are pure functions with no side effects.

## Testing Strategy

### Spec Validation
- Format conformance (required sections)
- YAML syntax validation
- Test case structure validation

### Conformance Testing
- Load test cases from specs
- Execute against implementation
- Compare results
- Report pass/fail

### Properties Testing
- Verify mathematical properties (commutativity, associativity, etc.)
- Test edge cases
- Validate invariants

## Common Tasks

```bash
# Install dependencies (none needed for specs)
# ReScript compilation requires rescript package

# Validate specifications
deno task validate:specs

# Run conformance tests
deno task test

# Check all validations
just validate

# Format Deno code
deno fmt

# Lint Deno code
deno lint
```

## Design Principles

1. **Minimal Surface**: Only include operations with broad overlap
2. **Explicit Semantics**: All behavior documented and tested
3. **Conformance First**: Tests drive implementation
4. **Ecosystem Respect**: Don't replace, demonstrate method
5. **Reversibility**: Easy to adopt, easy to abandon

## For Claude

When working with this repository:

1. **Spec Changes**: Always update tests when changing specs
2. **Implementation**: Follow ReScript idioms, use pure functions
3. **Testing**: Validate before committing
4. **Documentation**: Keep specs, code, and docs in sync
5. **License**: All new files use PMPL-1.0-or-later
6. **Author**: Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>

## Related Projects

- `proven` - Formal verification reference (Idris2)
- `alib-for-rescript` - Ecosystem-specific proving ground
- `rsr-template-repo` - Repository structure template
- `hypatia` - Security scanning
- `gitbot-fleet` - Quality enforcement

## Resources

- **Spec Format**: See any file in `specs/` for examples
- **ReScript Docs**: https://rescript-lang.org/
- **Deno Docs**: https://deno.com/
- **Nickel Docs**: https://nickel-lang.org/

---

Last updated: 2026-01-31
