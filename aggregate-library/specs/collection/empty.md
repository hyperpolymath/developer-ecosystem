# Operation: empty

## Interface Signature

```
empty: Collection[A] -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines if a collection has no elements.

**Parameters**:
- `collection`: The input collection

**Return Value**: `true` if the collection is empty, `false` otherwise.

**Properties**:
- Equivalence: `empty(c) = equal(length(c), 0)`
- Deterministic: Always returns the same value for the same collection
- Type-independent: Works for any collection type

**Edge Cases**:
- Empty collection returns `true`
- Any non-empty collection returns `false`

## Executable Test Cases

```yaml
test_cases:
  - input: [[]]
    output: true
    description: "Empty collection is empty"

  - input: [[1]]
    output: false
    description: "Single-element collection is not empty"

  - input: [[1, 2, 3]]
    output: false
    description: "Multiple-element collection is not empty"

  - input: [["a", "b"]]
    output: false
    description: "String collection with elements is not empty"
```
