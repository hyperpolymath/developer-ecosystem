# Operation: not_equal

## Interface Signature

```
not_equal: Number, Number -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines if two numbers are not equal in value.

**Parameters**:
- `a`: The first number to compare
- `b`: The second number to compare

**Return Value**: `true` if `a` does not equal `b`, otherwise `false`.

**Properties**:
- Irreflexive: `not_equal(a, a)` is always `false`
- Symmetric: if `not_equal(a, b)` is `true`, then `not_equal(b, a)` is `true`
- Negation of equal: `not_equal(a, b) = not(equal(a, b))`

**Edge Cases**:
- Floating-point precision issues are implementation-defined
- NaN inequality is implementation-defined
- Positive and negative zero inequality is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [5, 3]
    output: true
    description: "Unequal positive integers"

  - input: [5, 5]
    output: false
    description: "Equal positive integers"

  - input: [0, 1]
    output: true
    description: "Zero not equal to one"

  - input: [-5, 5]
    output: true
    description: "Negative and positive are unequal"

  - input: [-5, -5]
    output: false
    description: "Equal negative integers"

  - input: [2.5, 2.0]
    output: true
    description: "Unequal decimal numbers"

  - input: [1.0, 1]
    output: false
    description: "Decimal and integer with same value are equal"
```
