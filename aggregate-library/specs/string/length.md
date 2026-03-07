# Operation: length

## Interface Signature

```
length: String -> Number
```

## Behavioral Semantics

**Purpose**: Returns the number of characters in a string.

**Parameters**:
- `s`: The string to measure

**Return Value**: A non-negative number representing the count of characters in `s`.

**Properties**:
- Empty string has length 0: `length("") = 0`
- Non-negative: `length(s) ≥ 0` for all strings `s`
- Concatenation: `length(concat(a, b)) = add(length(a), length(b))`

**Edge Cases**:
- What constitutes a "character" (code point, grapheme cluster, byte) is implementation-defined
- Unicode handling (combining characters, etc.) is implementation-defined
- Multi-byte character encoding is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: ["hello"]
    output: 5
    description: "Length of simple ASCII string"

  - input: [""]
    output: 0
    description: "Length of empty string"

  - input: ["a"]
    output: 1
    description: "Length of single character"

  - input: ["hello world"]
    output: 11
    description: "Length including space"

  - input: ["123"]
    output: 3
    description: "Length of numeric string"
```
