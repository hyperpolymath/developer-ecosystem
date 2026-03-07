# Operation: map

## Interface Signature

```
map: Collection[A], Function[A -> B] -> Collection[B]
```

## Behavioral Semantics

**Purpose**: Transforms each element of a collection by applying a function, producing a new collection of the same length.

**Parameters**:
- `collection`: The source collection of elements of type `A`
- `fn`: A function that transforms elements from type `A` to type `B`

**Return Value**: A new collection containing the results of applying `fn` to each element in `collection`, preserving order.

**Properties**:
- Preserves length: `length(map(c, fn)) = length(c)`
- Preserves order: Elements appear in the same order as the source collection
- Identity: `map(c, identity) = c` (where `identity(x) = x`)
- Composition: `map(map(c, f), g) = map(c, compose(g, f))` (where `compose(g, f)(x) = g(f(x))`)
- Empty collection: `map([], fn) = []`

**Edge Cases**:
- Lazy vs eager evaluation is implementation-defined
- Side effects in the function are implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input:
      collection: [1, 2, 3]
      fn: "x => multiply(x, 2)"
    output: [2, 4, 6]
    description: "Double each number in collection"

  - input:
      collection: [1, 2, 3]
      fn: "x => add(x, 10)"
    output: [11, 12, 13]
    description: "Add 10 to each number"

  - input:
      collection: []
      fn: "x => multiply(x, 2)"
    output: []
    description: "Mapping over empty collection returns empty collection"

  - input:
      collection: [5]
      fn: "x => x"
    output: [5]
    description: "Identity function returns same element"

  - input:
      collection: ["a", "b", "c"]
      fn: "s => concat(s, s)"
    output: ["aa", "bb", "cc"]
    description: "Map over string collection"
```
