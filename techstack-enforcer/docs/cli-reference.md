# CLI Reference

Complete command-line reference for `techstack-enforcer`.

## Synopsis

```
techstack-enforcer <command> [options] [arguments]
```

## Commands

### check

Check a single file or directory against filters.

```bash
techstack-enforcer check <path>
```

**Examples:**
```bash
techstack-enforcer check src/main.py
techstack-enforcer check ./lib/
```

**Exit codes:**
- `0` - File/directory passes all checks
- `1` - Violations found

---

### audit

Perform a full repository audit with statistics.

```bash
techstack-enforcer audit [path]
```

**Arguments:**
- `path` - Repository path (default: current directory)

**Examples:**
```bash
techstack-enforcer audit
techstack-enforcer audit /path/to/repo
techstack-enforcer --defset=strict audit .
```

**Output:**
```
Scanning: /path/to/repo
----------------------------------------
Files scanned:   150
Violations:       12
Fatal blocks:      3

FAIL: Repository has techstack violations
```

---

### decide

Output allow/deny decisions as JSON. Designed for integration with other tools.

```bash
# Single file
techstack-enforcer decide <path>

# Batch mode (reads paths from stdin)
techstack-enforcer decide
```

**Input Format (stdin for batch mode):**
```
path/to/file1.py
path/to/file2.rs
src/main.adb
```

**Output Format (JSON):**
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
    }
  ],
  "summary": {
    "total": 2,
    "allowed": 1,
    "denied": 1,
    "warnings": 0
  },
  "mode": "enforce"
}
```

**Examples:**
```bash
# Single file decision
techstack-enforcer decide src/app.py

# Batch from file list
cat changed_files.txt | techstack-enforcer decide

# With definition set
techstack-enforcer --defset=enterprise decide src/legacy.c

# Pipe to jq for processing
techstack-enforcer decide src/ | jq '.summary'
```

---

### list

Display all configured filters.

```bash
techstack-enforcer list
```

**Output:**
```
Techstack Filter List ( 45 entries)
----------------------------------------
  [FATAL] *.py                          | Python: No static typing, memory-unsafe
  [FATAL] *.php                         | PHP: Memory-unsafe, injection-prone
  [BLOCK] *.c                           | C: Manual memory management
  [WARN ] *.sh                          | Shell script - verify manually
  [ALLOW] *.rs                          | Rust: Memory-safe with ownership
```

---

### defsets

List available definition sets.

```bash
techstack-enforcer defsets
```

**Output:**
```
Available Definition Sets:
----------------------------------------
  strict       - Maximum memory safety - blocks all unsafe languages
  moderate     - Balanced safety with practical exceptions
  permissive   - Advisory mode - warns but rarely blocks
  enterprise   - Corporate environments with legacy support
  memory_safe  - Focus on memory safety - blocks C/C++/Assembly

Usage: techstack-enforcer --defset=<name> <command>
```

---

### init

Initialize with default filters.

```bash
techstack-enforcer init
```

---

### version

Show version information.

```bash
techstack-enforcer version
techstack-enforcer -v
techstack-enforcer --version
```

---

### help

Display usage information.

```bash
techstack-enforcer help
techstack-enforcer -h
techstack-enforcer --help
```

---

## Global Options

### --defset=\<name\>

Load a pre-configured definition set before executing the command.

```bash
techstack-enforcer --defset=strict audit .
techstack-enforcer --defset=enterprise decide src/
```

**Available sets:**
- `strict` - Maximum memory safety (lockdown mode)
- `moderate` - Balanced approach (enforce mode)
- `permissive` - Advisory only (warn mode)
- `enterprise` - Corporate/legacy support (enforce mode)
- `memory_safe` - Focus on memory safety (enforce mode)

---

### --mode=\<mode\>

Override the enforcement mode.

```bash
techstack-enforcer --mode=lockdown audit .
techstack-enforcer --mode=learning audit .
```

**Modes:**
- `learning` - Observe and log only, never block
- `warn` - Show warnings, but allow all operations
- `enforce` - Block on `Block` and `Fatal` violations
- `lockdown` - Block on all violations including `Warn`

---

### --config=\<file\>

Use a specific configuration file.

```bash
techstack-enforcer --config=/path/to/custom.toml audit .
```

---

### --fatal-exit

Exit with code 1 on any fatal violation.

```bash
techstack-enforcer --fatal-exit audit .
```

---

### --notify

Send desktop notifications for violations.

```bash
techstack-enforcer --notify audit .
```

Requires `notify-send` (Linux) or equivalent.

---

### --json

Output results in JSON format.

```bash
techstack-enforcer --json audit .
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TECHSTACK_BIN` | Path to enforcer binary | `techstack-enforcer` |
| `TECHSTACK_MODE` | Default enforcement mode | `enforce` |
| `TECHSTACK_NOTIFY` | Enable desktop notifications | `1` |
| `TECHSTACK_DEFSET` | Default definition set | (none) |

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success / No violations |
| `1` | Violations found or error |

## See Also

- [Definition Sets](./definition-sets.md)
- [Configuration](./configuration.md)
- [API & JSON Format](./api-json-format.md)
