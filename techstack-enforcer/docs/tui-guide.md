# TUI Guide

The Terminal User Interface (TUI) provides an interactive way to manage filters and monitor enforcement.

## Starting the TUI

```bash
./bin/techstack_tui_main
# or if installed:
techstack-tui
```

## Interface Overview

```
==========================================
     TECHSTACK ENFORCER v1.0
     Ada/SPARK Filter Management TUI
==========================================
  Mode: [ENFORCE] - Blocking enabled

  FILTER LIST (45 entries)
  -----------------------------------------------
 > [#] *.py                     | Python: No static typing...
   [#] *.php                    | PHP: Memory-unsafe, injection...
   [X] *.c                      | C: Manual memory management
   [!] *.sh                     | Shell script - verify manually
   [+] *.rs                     | Rust: Memory-safe with ownership

  [a]dd [e]dit [d]elete [Space]toggle [1-4]mode [s]can [?]help [q]uit
```

## Keyboard Shortcuts

### Navigation

| Key | Action |
|-----|--------|
| `j` or `↓` | Move selection down |
| `k` or `↑` | Move selection up |
| `g` | Go to first filter |
| `G` | Go to last filter |

### Filter Management

| Key | Action |
|-----|--------|
| `a` | Add new filter |
| `e` | Edit selected filter |
| `d` | Delete selected filter |
| `Space` | Toggle enabled/disabled |

### Enforcement Mode

| Key | Mode | Description |
|-----|------|-------------|
| `1` | Learning | Observe only, no blocking |
| `2` | Warn | Warnings only |
| `3` | Enforce | Block violations |
| `4` | Lockdown | Maximum enforcement |

### Other Actions

| Key | Action |
|-----|--------|
| `s` | Scan repository |
| `S` | View statistics |
| `r` | Reset hit counters |
| `w` | Save configuration |
| `?` | Show help |
| `q` | Quit |

---

## Views

### Filter List (Main View)

Shows all configured filters with:
- Level indicator: `[+]` Allow, `[!]` Warn, `[X]` Block, `[#]` Fatal
- Pattern (glob)
- Reason/description
- `[L]` marker for learned filters

### Add Filter

Interactive prompts for:
1. **Pattern** - Glob pattern (e.g., `*.py`, `Dockerfile`)
2. **Severity** - `a`=Allow, `w`=Warn, `b`=Block, `f`=Fatal
3. **Reason** - Description of why it's blocked

### Edit Filter

Modify an existing filter:
- Shows current values
- Press Enter to keep current value
- Change pattern, level, or reason

### Statistics

Shows aggregate information:
- Total filters
- Enabled/disabled count
- Learned filters
- Breakdown by severity
- Total pattern hits

### Scan Repository

Scan a directory for violations:
1. Enter repository path
2. View results (files scanned, violations, fatal blocks)

---

## Level Indicators

| Symbol | Color | Level | Meaning |
|--------|-------|-------|---------|
| `[+]` | Green | Allow | Explicitly permitted |
| `[!]` | Yellow | Warn | Warning only |
| `[X]` | Magenta | Block | Blocked in enforce mode |
| `[#]` | Red | Fatal | Always blocked |

---

## Mode Indicators

| Mode | Color | Description |
|------|-------|-------------|
| `[LEARNING]` | Blue | Observing only |
| `[WARN]` | Yellow | Warnings only |
| `[ENFORCE]` | Magenta | Blocking enabled |
| `[LOCKDOWN]` | Red | Maximum enforcement |

---

## Example Workflows

### Adding a Custom Filter

1. Press `a` to add
2. Enter pattern: `*.legacy`
3. Enter severity: `b` (block)
4. Enter reason: `Legacy code not permitted`
5. Press `w` to save configuration

### Editing a Filter

1. Navigate to the filter with `j`/`k`
2. Press `e` to edit
3. Modify values (or press Enter to keep)
4. Press `w` to save

### Scanning a Project

1. Press `s` to scan
2. Enter path: `/path/to/project`
3. Review results
4. Press any key to return

### Changing Enforcement Mode

1. Press `1` for learning mode (testing)
2. Press `3` for enforce mode (production)
3. Press `4` for lockdown mode (high security)

---

## Configuration File

The TUI saves configuration to `techstack.toml` in the current directory.

To load a specific configuration:
```bash
cd /path/with/config
techstack-tui
```

## See Also

- [CLI Reference](./cli-reference.md)
- [Configuration](./configuration.md)
- [Filter Patterns](./filter-patterns.md)
