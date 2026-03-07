# Operation: reverse

## Interface Signature

```
reverse: String -> String
```

## Behavioral Semantics

**Purpose**: Reverses the order of characters in a string.

**Parameters**:
- `s`: The input string

**Return Value**: A new string with characters in reverse order.

**Properties**:
- Involutive: `reverse(reverse(s)) = s`
- Self-inverse: Applying twice returns original string
- Length-preserving: `length(reverse(s)) = length(s)`
- Empty string: `reverse("") = ""`
- **REVERSIBLE**: Perfect inverse operation

**Edge Cases**:
- Unicode handling is implementation-defined
- Grapheme cluster handling is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: ["hello"]
    output: "olleh"
    description: "Reverse simple string"

  - input: [""]
    output: ""
    description: "Reverse empty string"

  - input: ["a"]
    output: "a"
    description: "Reverse single character"

  - input: ["12345"]
    output: "54321"
    description: "Reverse numeric string"
```

## Reversibility

**This operation is REVERSIBLE** (self-inverse):
```
reverse(reverse(s)) = s  for all strings s
```

This makes `reverse` an ideal operation for the Common Library's reversibility principle.
