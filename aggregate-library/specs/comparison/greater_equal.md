# Operation: greater_equal

## Interface Signature

```
greater_equal: Number, Number -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines if the first number is greater than or equal to the second number.

**Parameters**:
- `a`: The first number to compare
- `b`: The second number to compare

**Return Value**: `true` if `a ≥ b`, otherwise `false`.

**Properties**:
- Transitive: if `greater_equal(a, b)` and `greater_equal(b, c)`, then `greater_equal(a, c)`
- Reflexive: `greater_equal(a, a)` is always `true`
- Antisymmetric: if `greater_equal(a, b)` and `greater_equal(b, a)`, then `equal(a, b)`
- Equivalent to: `or(greater_than(a, b), equal(a, b))`
- Inverse of less_equal: `greater_equal(a, b) = less_equal(b, a)`

**Edge Cases**:
- NaN comparison behavior is implementation-defined (Standard Library concern)
- Infinity comparison is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [5, 2]
    output: true
    description: "First number is greater than second"

  - input: [5, 5]
    output: true
    description: "Numbers are equal"

  - input: [2, 5]
    output: false
    description: "First number is less than second"

  - input: [0, -5]
    output: true
    description: "Zero greater than or equal to negative"

  - input: [0, 0]
    output: true
    description: "Zero greater than or equal to itself"

  - input: [-5, -5]
    output: true
    description: "Equal negative numbers"

  - input: [2.5, 1.5]
    output: true
    description: "Comparing decimal numbers (greater than)"
```
