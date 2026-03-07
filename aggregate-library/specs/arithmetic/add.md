# Operation: add

## Interface Signature

```
add: Number, Number -> Number
```

## Behavioral Semantics

**Purpose**: Computes the sum of two numbers.

**Parameters**:
- `a`: The first number (augend)
- `b`: The second number (addend)

**Return Value**: The arithmetic sum of `a` and `b`.

**Properties**:
- Commutative: `add(a, b) = add(b, a)`
- Associative: `add(add(a, b), c) = add(a, add(b, c))`
- Identity element: `add(a, 0) = a`

**Edge Cases**:
- Overflow/underflow behavior is implementation-defined (Standard Library concern)
- NaN and infinity handling is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [2, 3]
    output: 5
    description: "Basic addition of positive integers"

  - input: [-5, 3]
    output: -2
    description: "Addition with negative number"

  - input: [0, 0]
    output: 0
    description: "Addition of zeros"

  - input: [1.5, 2.5]
    output: 4.0
    description: "Addition of decimal numbers"

  - input: [-10, -20]
    output: -30
    description: "Addition of two negative numbers"
```
