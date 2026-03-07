# Operation: divide

## Interface Signature

```
divide: Number, Number -> Number
```

## Behavioral Semantics

**Purpose**: Computes the quotient of two numbers.

**Parameters**:
- `a`: The dividend (number to be divided)
- `b`: The divisor (number by which to divide)

**Return Value**: The arithmetic quotient `a ÷ b`.

**Properties**:
- Non-commutative: `divide(a, b) ≠ divide(b, a)` (in general)
- Identity element: `divide(a, 1) = a`
- Inverse of multiplication: `divide(multiply(a, b), b) = a` (when `b ≠ 0`)

**Preconditions**:
- `b ≠ 0` (division by zero behavior is implementation-defined)

**Edge Cases**:
- Division by zero is implementation-defined (Standard Library concern)
  - May return error, infinity, or NaN depending on language
- Integer vs floating-point division is implementation-defined
- Overflow/underflow behavior is implementation-defined
- NaN and infinity handling is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [6, 2]
    output: 3
    description: "Basic division with exact result"

  - input: [7, 2]
    output: 3.5
    description: "Division with fractional result"

  - input: [0, 5]
    output: 0
    description: "Zero divided by non-zero"

  - input: [-10, 2]
    output: -5
    description: "Division with negative dividend"

  - input: [10, -2]
    output: -5
    description: "Division with negative divisor"

  - input: [-12, -3]
    output: 4
    description: "Division of two negative numbers"
```
