# Operation: if_then_else

## Interface Signature

```
if_then_else: Boolean, A, A -> A
```

## Behavioral Semantics

**Purpose**: Selects one of two values based on a boolean condition.

**Parameters**:
- `condition`: A boolean value determining which branch to take
- `then_value`: The value to return if `condition` is `true`
- `else_value`: The value to return if `condition` is `false`

**Return Value**: `then_value` if `condition` is `true`, otherwise `else_value`.

**Properties**:
- True branch: `if_then_else(true, a, b) = a`
- False branch: `if_then_else(false, a, b) = b`
- Same values: `if_then_else(c, a, a) = a` for any condition `c`
- Can express boolean operations:
  - `and(a, b) = if_then_else(a, b, false)`
  - `or(a, b) = if_then_else(a, true, b)`
  - `not(a) = if_then_else(a, false, true)`

**Edge Cases**:
- Evaluation strategy (strict vs lazy) is implementation-defined
  - Strict: Both branches are evaluated before selection
  - Lazy: Only the selected branch is evaluated
- Languages may provide this as a statement/keyword rather than a function

## Executable Test Cases

```yaml
test_cases:
  - input:
      condition: true
      then_value: 10
      else_value: 20
    output: 10
    description: "Condition is true, return then_value"

  - input:
      condition: false
      then_value: 10
      else_value: 20
    output: 20
    description: "Condition is false, return else_value"

  - input:
      condition: true
      then_value: "yes"
      else_value: "no"
    output: "yes"
    description: "Works with string values"

  - input:
      condition: false
      then_value: "yes"
      else_value: "no"
    output: "no"
    description: "Returns else branch for false condition"

  - input:
      condition: equal(5, 5)
      then_value: 1
      else_value: 0
    output: 1
    description: "Condition from comparison operation"

  - input:
      condition: greater_than(3, 5)
      then_value: "bigger"
      else_value: "smaller"
    output: "smaller"
    description: "False comparison leads to else branch"
```
