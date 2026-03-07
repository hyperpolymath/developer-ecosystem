# Operation: modulo

## Interface Signature

```
modulo: Number, Number -> Number
```

## Behavioral Semantics

**Purpose**: Computes the remainder of division of two numbers.

**Parameters**:
- `a`: The dividend (number to be divided)
- `b`: The divisor (number by which to divide)

**Return Value**: The remainder when `a` is divided by `b`.

**Properties**:
- Non-commutative: `modulo(a, b) ≠ modulo(b, a)` (in general)
- `modulo(a, b)` has the same sign as the divisor in most implementations
- For positive integers: `0 ≤ modulo(a, b) < b` when `b > 0`

**Preconditions**:
- `b ≠ 0` (modulo by zero behavior is implementation-defined)

**Edge Cases**:
- Modulo by zero is implementation-defined (Standard Library concern)
- Sign of result with negative operands is implementation-defined
  - Some languages use truncated division (result has sign of dividend)
  - Others use floored division (result has sign of divisor)
- Behavior with floating-point numbers is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [7, 3]
    output: 1
    description: "Basic modulo with positive integers"

  - input: [10, 5]
    output: 0
    description: "Modulo with no remainder"

  - input: [15, 4]
    output: 3
    description: "Modulo returning non-zero remainder"

  - input: [0, 5]
    output: 0
    description: "Zero modulo non-zero"

  - input: [100, 7]
    output: 2
    description: "Modulo with larger numbers"
```

**Note**: Test cases with negative numbers are omitted due to implementation-defined behavior across languages.
