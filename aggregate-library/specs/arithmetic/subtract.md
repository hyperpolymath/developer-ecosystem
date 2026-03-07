# Operation: subtract

## Interface Signature

```
subtract: Number, Number -> Number
```

## Behavioral Semantics

**Purpose**: Computes the difference between two numbers.

**Parameters**:
- `a`: The minuend (number from which another is subtracted)
- `b`: The subtrahend (number to be subtracted)

**Return Value**: The arithmetic difference `a - b`.

**Properties**:
- Non-commutative: `subtract(a, b) ≠ subtract(b, a)` (in general)
- Identity element: `subtract(a, 0) = a`
- Inverse of addition: `subtract(add(a, b), b) = a`

**Edge Cases**:
- Overflow/underflow behavior is implementation-defined (Standard Library concern)
- NaN and infinity handling is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [5, 3]
    output: 2
    description: "Basic subtraction of positive integers"

  - input: [3, 5]
    output: -2
    description: "Subtraction resulting in negative number"

  - input: [0, 0]
    output: 0
    description: "Subtraction of zeros"

  - input: [-5, 3]
    output: -8
    description: "Subtracting positive from negative"

  - input: [10.5, 2.5]
    output: 8.0
    description: "Subtraction of decimal numbers"

  - input: [-10, -20]
    output: 10
    description: "Subtracting negative from negative"
```
