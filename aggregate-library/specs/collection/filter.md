# Operation: filter

## Interface Signature

```
filter: Collection[A], Function[A -> Boolean] -> Collection[A]
```

## Behavioral Semantics

**Purpose**: Selects elements from a collection that satisfy a predicate function, producing a new collection.

**Parameters**:
- `collection`: The source collection of elements of type `A`
- `predicate`: A function that returns `true` for elements to keep, `false` for elements to exclude

**Return Value**: A new collection containing only the elements from `collection` for which `predicate` returns `true`, preserving original order.

**Properties**:
- Length: `length(filter(c, p)) ≤ length(c)`
- Preserves order: Elements appear in the same relative order as in source collection
- Always true predicate: `filter(c, always_true) = c`
- Always false predicate: `filter(c, always_false) = []`
- Empty collection: `filter([], p) = []`
- Composition: `filter(filter(c, p1), p2) = filter(c, x => and(p1(x), p2(x)))`

**Edge Cases**:
- Lazy vs eager evaluation is implementation-defined
- Side effects in the predicate are implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input:
      collection: [1, 2, 3, 4, 5]
      predicate: "x => greater_than(x, 2)"
    output: [3, 4, 5]
    description: "Filter numbers greater than 2"

  - input:
      collection: [1, 2, 3, 4, 5]
      predicate: "x => equal(modulo(x, 2), 0)"
    output: [2, 4]
    description: "Filter even numbers"

  - input:
      collection: [1, 2, 3]
      predicate: "x => true"
    output: [1, 2, 3]
    description: "Filter with always-true predicate returns all elements"

  - input:
      collection: [1, 2, 3]
      predicate: "x => false"
    output: []
    description: "Filter with always-false predicate returns empty collection"

  - input:
      collection: []
      predicate: "x => true"
    output: []
    description: "Filter empty collection returns empty collection"
```
