# Operation: less_than

## Interface Signature

```
less_than: Number, Number -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines if the first number is strictly less than the second number.

**Parameters**:
- `a`: The first number to compare
- `b`: The second number to compare

**Return Value**: `true` if `a < b`, otherwise `false`.

**Properties**:
- Transitive: if `less_than(a, b)` and `less_than(b, c)`, then `less_than(a, c)`
- Asymmetric: if `less_than(a, b)` is `true`, then `less_than(b, a)` is `false`
- Irreflexive: `less_than(a, a)` is always `false`

**Edge Cases**:
- NaN comparison behavior is implementation-defined (Standard Library concern)
- Infinity comparison is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [2, 5]
    output: true
    description: "First number is less than second"

  - input: [5, 2]
    output: false
    description: "First number is greater than second"

  - input: [3, 3]
    output: false
    description: "Numbers are equal"

  - input: [-5, 0]
    output: true
    description: "Negative less than zero"

  - input: [0, -5]
    output: false
    description: "Zero not less than negative"

  - input: [-10, -5]
    output: true
    description: "Comparing two negative numbers"

  - input: [1.5, 2.0]
    output: true
    description: "Comparing decimal numbers"
```
