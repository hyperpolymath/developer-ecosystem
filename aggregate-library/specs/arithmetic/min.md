# Operation: min

## Interface Signature

```
min: Number, Number -> Number
```

## Behavioral Semantics

**Purpose**: Returns the smaller of two numbers.

**Parameters**:
- `a`: The first number
- `b`: The second number

**Return Value**: The minimum of `a` and `b`.

**Properties**:
- Commutative: `min(a, b) = min(b, a)`
- Associative: `min(min(a, b), c) = min(a, min(b, c))`
- Idempotent: `min(a, a) = a`
- Identity element: negative infinity (if representable)
- Selection: Result is always one of the inputs

**Edge Cases**:
- `min(a, a) = a`
- NaN handling is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [5, 3]
    output: 3
    description: "Minimum of two positive numbers"

  - input: [-5, 3]
    output: -5
    description: "Minimum with negative number"

  - input: [10, 10]
    output: 10
    description: "Minimum of equal numbers"

  - input: [0, -10]
    output: -10
    description: "Minimum with zero"
```
