# API & JSON Format

The `decide` command provides structured JSON output for integration with other tools, scripts, and automation.

## Input Format

### Single File Mode

```bash
techstack-enforcer decide <path>
```

### Batch Mode (stdin)

Read file paths from standard input, one per line:

```
path/to/file1.py
path/to/file2.rs
src/main.adb
lib/utils.c
```

**Example:**
```bash
# From file
cat files.txt | techstack-enforcer decide

# From git diff
git diff --name-only HEAD~1 | techstack-enforcer decide

# From find
find src -name "*.py" | techstack-enforcer decide

# Inline
echo -e "file1.py\nfile2.rs" | techstack-enforcer decide
```

---

## Output Format

### Single File Response

```json
{
  "file": "path/to/file.py",
  "decision": "deny",
  "level": "fatal",
  "pattern": "*.py",
  "reason": "Python: No static typing, memory-unsafe runtime"
}
```

### Batch Response

```json
{
  "decisions": [
    {
      "file": "path/to/file1.py",
      "decision": "deny",
      "level": "fatal",
      "pattern": "*.py",
      "reason": "Python: No static typing, memory-unsafe runtime"
    },
    {
      "file": "path/to/file2.rs",
      "decision": "allow",
      "level": "allow",
      "pattern": null,
      "reason": null
    },
    {
      "file": "src/main.c",
      "decision": "deny",
      "level": "block",
      "pattern": "*.c",
      "reason": "C: Manual memory management, buffer overflows"
    }
  ],
  "summary": {
    "total": 3,
    "allowed": 1,
    "denied": 2,
    "warnings": 0
  },
  "mode": "enforce"
}
```

---

## Field Reference

### Decision Object

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | Path to the file checked |
| `decision` | string | `"allow"`, `"deny"`, or `"warn"` |
| `level` | string | `"allow"`, `"warn"`, `"block"`, or `"fatal"` |
| `pattern` | string\|null | The filter pattern that matched |
| `reason` | string\|null | Explanation for the decision |

### Summary Object

| Field | Type | Description |
|-------|------|-------------|
| `total` | number | Total files checked |
| `allowed` | number | Files that passed |
| `denied` | number | Files that were blocked |
| `warnings` | number | Files with warnings |

### Root Object (Batch)

| Field | Type | Description |
|-------|------|-------------|
| `decisions` | array | Array of decision objects |
| `summary` | object | Aggregated statistics |
| `mode` | string | Current enforcement mode |

---

## Decision Values

| Decision | Meaning |
|----------|---------|
| `allow` | File passes all filters |
| `deny` | File is blocked by a filter |
| `warn` | File triggers a warning but is not blocked |

---

## Level Values

| Level | Description |
|-------|-------------|
| `allow` | Explicitly whitelisted |
| `warn` | Warning only (blocked in lockdown) |
| `block` | Blocked in enforce/lockdown modes |
| `fatal` | Always blocked (except learning mode) |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All files allowed (or warnings only) |
| `1` | One or more files denied |

---

## Examples

### Basic Usage

```bash
# Check a single file
techstack-enforcer decide src/main.py
```

Output:
```json
{
  "file": "src/main.py",
  "decision": "deny",
  "level": "fatal",
  "pattern": "*.py",
  "reason": "Python: No static typing, memory-unsafe runtime"
}
```

### With Definition Set

```bash
techstack-enforcer --defset=enterprise decide src/legacy.c
```

### Batch Processing

```bash
git diff --cached --name-only | techstack-enforcer decide
```

### Piping to jq

```bash
# Get only denied files
techstack-enforcer decide < files.txt | jq '.decisions[] | select(.decision == "deny") | .file'

# Get summary
techstack-enforcer decide < files.txt | jq '.summary'

# Check if any denials
if techstack-enforcer decide < files.txt | jq -e '.summary.denied > 0' > /dev/null; then
  echo "Violations found!"
  exit 1
fi
```

### Integration with Git Hooks

```bash
#!/bin/bash
# pre-commit hook

STAGED=$(git diff --cached --name-only)
if [ -z "$STAGED" ]; then
  exit 0
fi

RESULT=$(echo "$STAGED" | techstack-enforcer decide)
DENIED=$(echo "$RESULT" | jq '.summary.denied')

if [ "$DENIED" -gt 0 ]; then
  echo "Techstack violations found:"
  echo "$RESULT" | jq -r '.decisions[] | select(.decision == "deny") | "  \(.file): \(.reason)"'
  exit 1
fi
```

---

## Error Response

If an error occurs, the response includes an error field:

```json
{
  "error": "Failed to read input"
}
```

Exit code will be `1`.

## See Also

- [CLI Reference](./cli-reference.md)
- [CI Integration](./ci-integration.md)
- [Git Hooks](./git-hooks.md)
