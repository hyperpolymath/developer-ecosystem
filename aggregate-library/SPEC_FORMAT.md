# Common Library Specification Format

This document defines the minimal format for specifying operations in the aggregate-library (aLib) Common Library.

## Design Philosophy

The Common Library specification is intentionally minimal - it defines only the **intersection** of functionality across 7 radically different programming languages:

- WokeLang (consent-driven, emotional)
- Duet/Ensemble (AI-first, session types, effects)
- Eclexia (sustainability, energy budgets)
- Oblíbený (security, provable termination)
- RT-Lang (real-time, dependent types, safety certification)
- Phronesis (ethical reasoning, values-based)
- Julia the Viper (reversible computing, totality)

## Specification Components

Each operation in the Common Library MUST include these three components:

### 1. Interface Signature

The abstract signature of the operation, independent of any specific language syntax.

```
operation_name: InputType1, InputType2, ... -> OutputType
```

Example:
```
add: Number, Number -> Number
```

### 2. Behavioral Semantics

A clear, unambiguous description of what the operation does, including:

- **Purpose**: What the operation computes
- **Parameters**: Description of each input parameter
- **Return Value**: Description of what is returned
- **Edge Cases**: Behavior for special inputs (if applicable)
- **Constraints**: Any preconditions or invariants

Example:
```
Purpose: Adds two numbers together
Parameters:
  - a: The first number
  - b: The second number
Return Value: The sum of a and b
Edge Cases:
  - Overflow behavior is language-specific (Standard Library)
  - NaN/Infinity handling is language-specific (Standard Library)
```

### 3. Executable Test Cases

Concrete test cases that demonstrate the operation's behavior. Each test case includes:

- **Input**: Specific input values
- **Expected Output**: The expected result
- **Description**: Brief explanation of what is being tested

Example:
```yaml
test_cases:
  - input: [2, 3]
    output: 5
    description: "Basic addition of positive integers"

  - input: [-5, 3]
    output: -2
    description: "Addition with negative number"

  - input: [0, 0]
    output: 0
    description: "Addition of zeros"
```

## What is NOT Included

To keep the specification minimal and cross-paradigm, the following are explicitly **excluded**:

- ❌ Full Abstract Syntax Trees (ASTs)
- ❌ Deep semantic models
- ❌ Language-specific syntax
- ❌ Error handling mechanisms (language-specific)
- ❌ Type system details beyond basic categories (Number, String, Boolean, Collection)
- ❌ Memory management strategies
- ❌ Concurrency primitives
- ❌ Performance characteristics

These belong in each language's **Standard Library** or implementation documentation.

## Type System

The Common Library uses a minimal type vocabulary:

- **Number**: Numeric values (integers, floats - specifics are language-dependent)
- **String**: Text/character sequences
- **Boolean**: True/false values
- **Collection[T]**: Ordered sequences of elements of type T
- **Function[A -> B]**: Functions from type A to type B

## File Organization

Specifications are organized by category:

```
specs/
├── arithmetic/
│   ├── add.md
│   ├── subtract.md
│   ├── multiply.md
│   ├── divide.md
│   └── modulo.md
├── comparison/
│   ├── less_than.md
│   ├── greater_than.md
│   ├── equal.md
│   ├── not_equal.md
│   ├── less_equal.md
│   └── greater_equal.md
├── logical/
│   ├── and.md
│   ├── or.md
│   └── not.md
├── string/
│   ├── concat.md
│   ├── length.md
│   └── substring.md
├── collection/
│   ├── map.md
│   ├── filter.md
│   ├── fold.md
│   └── contains.md
└── conditional/
    └── if_then_else.md
```

## Example: Complete Specification

Here's a complete example for the `add` operation:

### Operation: add

#### Interface Signature
```
add: Number, Number -> Number
```

#### Behavioral Semantics

**Purpose**: Computes the sum of two numbers.

**Parameters**:
- `a`: The first number (augend)
- `b`: The second number (addend)

**Return Value**: The arithmetic sum of `a` and `b`.

**Properties**:
- Commutative: `add(a, b) = add(b, a)`
- Associative: `add(add(a, b), c) = add(a, add(b, c))`
- Identity element: `add(a, 0) = a`

**Edge Cases**:
- Overflow/underflow behavior is implementation-defined (Standard Library concern)
- NaN and infinity handling is implementation-defined (Standard Library concern)

#### Executable Test Cases

```yaml
test_cases:
  - input: [2, 3]
    output: 5
    description: "Basic addition of positive integers"

  - input: [-5, 3]
    output: -2
    description: "Addition with negative number"

  - input: [0, 0]
    output: 0
    description: "Addition of zeros"

  - input: [1.5, 2.5]
    output: 4.0
    description: "Addition of decimal numbers"

  - input: [-10, -20]
    output: -30
    description: "Addition of two negative numbers"
```

## Rationale

This minimal format ensures:

1. **Cross-paradigm compatibility**: Works across all 7 languages regardless of their philosophical differences
2. **Clear contracts**: Unambiguous specification of behavior
3. **Testability**: Concrete test cases enable verification
4. **Simplicity**: Focuses on the essential intersection, not language-specific details
5. **Extensibility**: Each language extends through its Standard Library

---

Last updated: 2025-11-22
