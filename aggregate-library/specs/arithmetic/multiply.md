# Operation: multiply

## Interface Signature

```
multiply: Number, Number -> Number
```

## Behavioral Semantics

**Purpose**: Computes the product of two numbers.

**Parameters**:
- `a`: The multiplicand (first factor)
- `b`: The multiplier (second factor)

**Return Value**: The arithmetic product `a × b`.

**Properties**:
- Commutative: `multiply(a, b) = multiply(b, a)`
- Associative: `multiply(multiply(a, b), c) = multiply(a, multiply(b, c))`
- Identity element: `multiply(a, 1) = a`
- Zero property: `multiply(a, 0) = 0`
- Distributive over addition: `multiply(a, add(b, c)) = add(multiply(a, b), multiply(a, c))`

**Edge Cases**:
- Overflow/underflow behavior is implementation-defined (Standard Library concern)
- NaN and infinity handling is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [2, 3]
    output: 6
    description: "Basic multiplication of positive integers"

  - input: [-5, 3]
    output: -15
    description: "Multiplication with negative number"

  - input: [0, 42]
    output: 0
    description: "Multiplication by zero"

  - input: [7, 1]
    output: 7
    description: "Multiplication by one (identity)"

  - input: [2.5, 4]
    output: 10.0
    description: "Multiplication with decimal number"

  - input: [-3, -4]
    output: 12
    description: "Multiplication of two negative numbers"
```
