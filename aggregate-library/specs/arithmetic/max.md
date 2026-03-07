# Operation: max

## Interface Signature

```
max: Number, Number -> Number
```

## Behavioral Semantics

**Purpose**: Returns the larger of two numbers.

**Parameters**:
- `a`: The first number
- `b`: The second number

**Return Value**: The maximum of `a` and `b`.

**Properties**:
- Commutative: `max(a, b) = max(b, a)`
- Associative: `max(max(a, b), c) = max(a, max(b, c))`
- Idempotent: `max(a, a) = a`
- Identity element: negative infinity (if representable)
- Selection: Result is always one of the inputs

**Edge Cases**:
- `max(a, a) = a`
- NaN handling is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [5, 3]
    output: 5
    description: "Maximum of two positive numbers"

  - input: [-5, 3]
    output: 3
    description: "Maximum with negative number"

  - input: [10, 10]
    output: 10
    description: "Maximum of equal numbers"

  - input: [0, -10]
    output: 0
    description: "Maximum with zero"
```
