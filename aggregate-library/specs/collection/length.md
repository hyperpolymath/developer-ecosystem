# Operation: length

## Interface Signature

```
length: Collection[A] -> Number
```

## Behavioral Semantics

**Purpose**: Returns the number of elements in a collection.

**Parameters**:
- `collection`: The input collection

**Return Value**: A non-negative integer representing the count of elements.

**Properties**:
- Non-negativity: `length(c) >= 0` for all collections `c`
- Empty collection: `length([]) = 0`
- Single element: `length([x]) = 1`
- Preserves under map: `length(map(c, f)) = length(c)`
- Deterministic: Always returns the same value for the same collection

**Edge Cases**:
- Empty collection returns 0
- Maximum length is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: [[1, 2, 3, 4, 5]]
    output: 5
    description: "Length of five-element collection"

  - input: [[]]
    output: 0
    description: "Length of empty collection"

  - input: [[42]]
    output: 1
    description: "Length of single-element collection"

  - input: [["a", "b", "c"]]
    output: 3
    description: "Length of string collection"
```
