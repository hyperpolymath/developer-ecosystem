# Operation: substring

## Interface Signature

```
substring: String, Number, Number -> String
```

## Behavioral Semantics

**Purpose**: Extracts a portion of a string between two indices.

**Parameters**:
- `s`: The source string
- `start`: The starting index (inclusive)
- `end`: The ending index (exclusive)

**Return Value**: A new string containing characters from `s` starting at index `start` up to (but not including) index `end`.

**Preconditions**:
- `0 ≤ start ≤ length(s)`
- `start ≤ end ≤ length(s)`

**Properties**:
- `substring(s, 0, length(s)) = s` (entire string)
- `substring(s, i, i) = ""` (empty substring)
- `length(substring(s, start, end)) = subtract(end, start)`

**Edge Cases**:
- Index out of bounds behavior is implementation-defined (may error or clamp)
- Negative indices are implementation-defined
- Zero-based vs one-based indexing is implementation-defined (specification assumes zero-based)
- Character encoding and multi-byte characters is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: ["hello", 0, 5]
    output: "hello"
    description: "Extract entire string"

  - input: ["hello", 1, 4]
    output: "ell"
    description: "Extract middle portion"

  - input: ["hello", 0, 1]
    output: "h"
    description: "Extract first character"

  - input: ["hello", 4, 5]
    output: "o"
    description: "Extract last character"

  - input: ["hello", 2, 2]
    output: ""
    description: "Empty substring (start equals end)"

  - input: ["hello world", 6, 11]
    output: "world"
    description: "Extract word from sentence"
```
