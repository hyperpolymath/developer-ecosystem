# Operation: and

## Interface Signature

```
and: Boolean, Boolean -> Boolean
```

## Behavioral Semantics

**Purpose**: Performs logical conjunction of two boolean values.

**Parameters**:
- `a`: The first boolean value
- `b`: The second boolean value

**Return Value**: `true` if both `a` and `b` are `true`, otherwise `false`.

**Properties**:
- Commutative: `and(a, b) = and(b, a)`
- Associative: `and(and(a, b), c) = and(a, and(b, c))`
- Identity element: `and(a, true) = a`
- Annihilator element: `and(a, false) = false`
- Idempotent: `and(a, a) = a`
- Distributive over or: `and(a, or(b, c)) = or(and(a, b), and(a, c))`

**Edge Cases**:
- Short-circuit evaluation is implementation-defined (Standard Library concern)

## Executable Test Cases

```yaml
test_cases:
  - input: [true, true]
    output: true
    description: "Both values are true"

  - input: [true, false]
    output: false
    description: "First is true, second is false"

  - input: [false, true]
    output: false
    description: "First is false, second is true"

  - input: [false, false]
    output: false
    description: "Both values are false"
```
