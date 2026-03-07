# Operation: less_equal

## Interface Signature

```
less_equal: Number, Number -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines if the first number is less than or equal to the second number.

**Parameters**:
- `a`: The first number to compare
- `b`: The second number to compare

**Return Value**: `true` if `a ≤ b`, otherwise `false`.

**Properties**:
- Transitive: if `less_equal(a, b)` and `less_equal(b, c)`, then `less_equal(a, c)`
- Reflexive: `less_equal(a, a)` is always `true`
- Antisymmetric: if `less_equal(a, b)` and `less_equal(b, a)`, then `equal(a, b)`
- Equivalent to: `or(less_than(a, b), equal(a, b))`

**Edge Cases**:
- NaN comparison behavior is implementation-defined (Standard Library concern)
- Infinity comparison is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [2, 5]
    output: true
    description: "First number is less than second"

  - input: [5, 5]
    output: true
    description: "Numbers are equal"

  - input: [5, 2]
    output: false
    description: "First number is greater than second"

  - input: [-5, 0]
    output: true
    description: "Negative less than or equal to zero"

  - input: [0, 0]
    output: true
    description: "Zero less than or equal to itself"

  - input: [-10, -10]
    output: true
    description: "Equal negative numbers"

  - input: [1.5, 2.0]
    output: true
    description: "Comparing decimal numbers (less than)"
```
