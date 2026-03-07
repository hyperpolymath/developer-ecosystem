# Operation: not

## Interface Signature

```
not: Boolean -> Boolean
```

## Behavioral Semantics

**Purpose**: Performs logical negation of a boolean value.

**Parameters**:
- `a`: The boolean value to negate

**Return Value**: `true` if `a` is `false`, `false` if `a` is `true`.

**Properties**:
- Double negation: `not(not(a)) = a`
- De Morgan's laws:
  - `not(and(a, b)) = or(not(a), not(b))`
  - `not(or(a, b)) = and(not(a), not(b))`
- Complement: `and(a, not(a)) = false` and `or(a, not(a)) = true`

## Executable Test Cases

```yaml
test_cases:
  - input: [true]
    output: false
    description: "Negation of true is false"

  - input: [false]
    output: true
    description: "Negation of false is true"

  - input: [true]
    output: true
    description: "Double negation returns original value: not(not(true)) = true"
    note: "Demonstrates double negation property"
```
