# Operation: greater_than

## Interface Signature

```
greater_than: Number, Number -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines if the first number is strictly greater than the second number.

**Parameters**:
- `a`: The first number to compare
- `b`: The second number to compare

**Return Value**: `true` if `a > b`, otherwise `false`.

**Properties**:
- Transitive: if `greater_than(a, b)` and `greater_than(b, c)`, then `greater_than(a, c)`
- Asymmetric: if `greater_than(a, b)` is `true`, then `greater_than(b, a)` is `false`
- Irreflexive: `greater_than(a, a)` is always `false`
- Inverse of less_than: `greater_than(a, b) = less_than(b, a)`

**Edge Cases**:
- NaN comparison behavior is implementation-defined (Standard Library concern)
- Infinity comparison is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [5, 2]
    output: true
    description: "First number is greater than second"

  - input: [2, 5]
    output: false
    description: "First number is less than second"

  - input: [3, 3]
    output: false
    description: "Numbers are equal"

  - input: [0, -5]
    output: true
    description: "Zero greater than negative"

  - input: [-5, 0]
    output: false
    description: "Negative not greater than zero"

  - input: [-5, -10]
    output: true
    description: "Comparing two negative numbers"

  - input: [2.5, 1.5]
    output: true
    description: "Comparing decimal numbers"
```
