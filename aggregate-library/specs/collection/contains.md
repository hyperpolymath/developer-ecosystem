# Operation: contains

## Interface Signature

```
contains: Collection[A], A -> Boolean
```

## Behavioral Semantics

**Purpose**: Determines whether a collection contains a specific element.

**Parameters**:
- `collection`: The source collection of elements of type `A`
- `element`: The element to search for

**Return Value**: `true` if `element` is found in `collection`, otherwise `false`.

**Properties**:
- Empty collection: `contains([], x) = false` for all `x`
- Single element match: `contains([x], x) = true`
- Single element no match: `contains([x], y) = false` when `x ≠ y`
- Can be expressed as: `contains(c, x) = greater_than(length(filter(c, e => equal(e, x))), 0)`

**Edge Cases**:
- Equality comparison semantics (reference vs value) is implementation-defined
- Short-circuit evaluation (stop on first match) is implementation-defined
- Search order and performance characteristics are implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input:
      collection: [1, 2, 3, 4, 5]
      element: 3
    output: true
    description: "Element is present in collection"

  - input:
      collection: [1, 2, 3, 4, 5]
      element: 6
    output: false
    description: "Element is not present in collection"

  - input:
      collection: []
      element: 1
    output: false
    description: "Empty collection contains no elements"

  - input:
      collection: [1]
      element: 1
    output: true
    description: "Single element collection contains that element"

  - input:
      collection: ["a", "b", "c"]
      element: "b"
    output: true
    description: "String element is present"

  - input:
      collection: [1, 2, 1, 3, 1]
      element: 1
    output: true
    description: "Element appears multiple times (still returns true)"
```
