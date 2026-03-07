# Operation: negate

## Interface Signature

```
negate: Number -> Number
```

## Behavioral Semantics

**Purpose**: Computes the additive inverse (negation) of a number.

**Parameters**:
- `a`: The number to negate

**Return Value**: The arithmetic negation of `a`, such that `add(a, negate(a)) = 0`.

**Properties**:
- Involutive: `negate(negate(a)) = a`
- Identity: `negate(0) = 0`
- Self-inverse: Applying twice returns original value
- Reversible: Operation can be undone by applying again

**Edge Cases**:
- Overflow on minimum integer values is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [5]
    output: -5
    description: "Negate positive number"

  - input: [-3]
    output: 3
    description: "Negate negative number"

  - input: [0]
    output: 0
    description: "Negate zero"

  - input: [-100]
    output: 100
    description: "Negate large negative number"
```

## Reversibility

**This operation is REVERSIBLE** (self-inverse):
```
negate(negate(x)) = x  for all x
```

Reversing the operation is achieved by applying negate again.
