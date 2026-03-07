# Operation: fold

## Interface Signature

```
fold: Collection[A], B, Function[B, A -> B] -> B
```

**Alternative names**: reduce, foldl, aggregate

## Behavioral Semantics

**Purpose**: Reduces a collection to a single value by iteratively applying a combining function.

**Parameters**:
- `collection`: The source collection of elements of type `A`
- `initial`: The initial accumulator value of type `B`
- `fn`: A combining function that takes the current accumulator (type `B`) and an element (type `A`) and returns a new accumulator (type `B`)

**Return Value**: The final accumulated value after processing all elements.

**Properties**:
- Empty collection: `fold([], initial, fn) = initial`
- Single element: `fold([x], initial, fn) = fn(initial, x)`
- Left-associative: Processes elements from left to right
- For collection `[a, b, c]`: `fold([a,b,c], init, fn) = fn(fn(fn(init, a), b), c)`

**Edge Cases**:
- Order of evaluation (left-to-right) is specified
- Right fold (foldr) may be provided in Standard Library
- Lazy vs eager evaluation is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input:
      collection: [1, 2, 3, 4]
      initial: 0
      fn: "acc, x => add(acc, x)"
    output: 10
    description: "Sum all numbers in collection"

  - input:
      collection: [1, 2, 3, 4]
      initial: 1
      fn: "acc, x => multiply(acc, x)"
    output: 24
    description: "Product of all numbers in collection"

  - input:
      collection: []
      initial: 42
      fn: "acc, x => add(acc, x)"
    output: 42
    description: "Folding empty collection returns initial value"

  - input:
      collection: [5]
      initial: 10
      fn: "acc, x => add(acc, x)"
    output: 15
    description: "Folding single element"

  - input:
      collection: ["a", "b", "c"]
      initial: ""
      fn: "acc, s => concat(acc, s)"
    output: "abc"
    description: "Concatenate strings using fold"

  - input:
      collection: [1, 2, 3]
      initial: 0
      fn: "acc, x => add(acc, 1)"
    output: 3
    description: "Count elements using fold"
```
