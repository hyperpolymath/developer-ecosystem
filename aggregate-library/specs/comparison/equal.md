# Operation: equal

## Interface Signature

```
equal: Number, Number -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines if two numbers are equal in value.

**Parameters**:
- `a`: The first number to compare
- `b`: The second number to compare

**Return Value**: `true` if `a` equals `b`, otherwise `false`.

**Properties**:
- Reflexive: `equal(a, a)` is always `true`
- Symmetric: if `equal(a, b)` is `true`, then `equal(b, a)` is `true`
- Transitive: if `equal(a, b)` and `equal(b, c)`, then `equal(a, c)`

**Edge Cases**:
- Floating-point precision issues are implementation-defined
- NaN equality (typically `NaN ≠ NaN`) is implementation-defined
- Positive and negative zero equality is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [5, 5]
    output: true
    description: "Equal positive integers"

  - input: [5, 3]
    output: false
    description: "Unequal positive integers"

  - input: [0, 0]
    output: true
    description: "Zero equals zero"

  - input: [-5, -5]
    output: true
    description: "Equal negative integers"

  - input: [-5, 5]
    output: false
    description: "Negative and positive not equal"

  - input: [2.5, 2.5]
    output: true
    description: "Equal decimal numbers"

  - input: [1.0, 1]
    output: true
    description: "Decimal and integer with same value"
```
