# Operation: absolute

## Interface Signature

```
absolute: Number -> Number
```

## Behavioral Semantics

**Purpose**: Computes the absolute value (magnitude) of a number.

**Parameters**:
- `a`: The input number

**Return Value**: The non-negative magnitude of `a`.

**Properties**:
- Non-negativity: `absolute(a) >= 0` for all `a`
- Positive-definiteness: `absolute(a) = 0` if and only if `a = 0`
- Evenness: `absolute(-a) = absolute(a)`
- Idempotent: `absolute(absolute(a)) = absolute(a)`
- Triangle inequality: `absolute(add(a, b)) <= add(absolute(a), absolute(b))`

**Edge Cases**:
- `absolute(0) = 0`
- Overflow on minimum integer values is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [5]
    output: 5
    description: "Absolute value of positive number"

  - input: [-5]
    output: 5
    description: "Absolute value of negative number"

  - input: [0]
    output: 0
    description: "Absolute value of zero"

  - input: [-100]
    output: 100
    description: "Absolute value of large negative"
```

## Reversibility

**This operation is NOT fully reversible**:
- Information is lost: sign of the original number
- Cannot distinguish between `absolute(5)` and `absolute(-5)`

However, it is **idempotent** and **deterministic**, making it suitable for the Common Library.
