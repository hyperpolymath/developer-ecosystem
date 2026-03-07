# Operation: concat

## Interface Signature

```
concat: String, String -> String
```

## Behavioral Semantics

**Purpose**: Concatenates two strings together, forming a new string.

**Parameters**:
- `a`: The first string
- `b`: The second string

**Return Value**: A new string consisting of all characters from `a` followed by all characters from `b`.

**Properties**:
- Associative: `concat(concat(a, b), c) = concat(a, concat(b, c))`
- Identity element: `concat(a, "") = concat("", a) = a` (empty string)
- NOT commutative: `concat(a, b) ≠ concat(b, a)` (in general)

**Edge Cases**:
- Concatenating empty strings returns the other string
- String encoding/character set handling is implementation-defined

## Executable Test Cases

```yaml
test_cases:
  - input: ["hello", "world"]
    output: "helloworld"
    description: "Basic string concatenation"

  - input: ["hello", " world"]
    output: "hello world"
    description: "Concatenation with space"

  - input: ["", "test"]
    output: "test"
    description: "Concatenation with empty string (left)"

  - input: ["test", ""]
    output: "test"
    description: "Concatenation with empty string (right)"

  - input: ["", ""]
    output: ""
    description: "Concatenation of two empty strings"

  - input: ["123", "456"]
    output: "123456"
    description: "Concatenation of numeric strings"
```
