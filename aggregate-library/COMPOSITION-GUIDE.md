# SPDX-License-Identifier: PMPL-1.0-or-later

# Aggregate Library Composition Guide

**Author:** Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>
**Date:** 2026-02-01

## The Formula

```
aggregate-library = (common elements of phronesis stdlib ∩ Rust stdlib ∩ Haskell stdlib)
                  ∪ (compiler utilities)
```

**Translation:** Find what's common across ALL THREE language stlibs, extract it to aggregate-library choosing the BEST implementation for each, and each language keeps its specialized parts.

This creates a **leaner library** with **no duplication** - a single source of truth for universal patterns.

---

## How It Works

### 1. Identify Common Patterns

Look for operations that exist across **all three** language stlibs:
- Phronesis (Elixir stdlib)
- Rust stdlib
- Haskell stdlib (Prelude, Data.*)

### 2. Choose Best-of-Breed Implementation

For each common pattern, select the implementation with the best characteristics:

| Pattern | Best From | Why |
|---------|-----------|-----|
| Result/Option types | **Elixir** | Cleanest API ({:ok, value} \| {:error, reason}) |
| Collections | **Haskell** | Most elegant, composable (map, filter, fold) |
| Strings | **Elixir** | Best Unicode handling |
| File I/O | **Elixir** | Built-in Result handling |
| Time/Duration | **Rust** | Best precision, no allocations |

### 3. Extract to aggregate-library

Create modules in aggregate-library with the chosen implementations:
- `AggregateLibrary.Result` - Elixir-style
- `AggregateLibrary.Collections` - Haskell-style
- `AggregateLibrary.FileIO` - Elixir-style
- `AggregateLibrary.Stream` - Cross-language patterns
- `AggregateLibrary.Time` - Rust-style

### 4. Each Language Keeps Specialized Parts

**What stays in language-specific stlibs:**

**Phronesis (lib/phronesis/stdlib/):**
- `Std.Consensus` - Raft consensus, distributed voting (policy-specific)
- `Std.BGP` - AS path analysis, route validation (network-specific)
- `Std.RPKI` - ROA validation (network-specific)
- `Std.Temporal` - Policy-specific time logic (is_expired, within_window)

**Rust stdlib:**
- Ownership/borrowing utilities (Arc, Mutex, unsafe)
- Low-level I/O (Read, Write traits)
- Platform-specific APIs (Windows/Linux/macOS)

**Haskell stdlib:**
- Type-level programming (DataKinds, GADTs)
- Monad transformers (StateT, ReaderT)
- Lazy evaluation primitives (seq, deepseq)

---

## Example: Time Module

### Before (Duplicated)

**Phronesis.Stdlib.Temporal:**
```elixir
def now(), do: DateTime.utc_now()
def duration(seconds), do: %{seconds: seconds}
def is_expired(timestamp, duration)  # policy-specific
def within_window(start, end)         # policy-specific
```

**Rust std::time:**
```rust
Duration::from_secs(60)
Instant::now()
instant.elapsed()
```

**Haskell Data.Time:**
```haskell
getCurrentTime :: IO UTCTime
addUTCTime :: NominalDiffTime -> UTCTime -> UTCTime
```

### After (Extracted)

**AggregateLibrary.Time (universal):**
```elixir
def now() - Current timestamp
def duration(seconds) - Create duration
def add(time, duration) - Time arithmetic
def elapsed(start, end) - Calculate difference
def parse(string) - ISO8601 parsing
def format(datetime) - ISO8601 formatting
def to_unix(datetime) - Unix timestamp conversion
```

**Phronesis.Stdlib.Temporal (policy-specific only):**
```elixir
def is_expired(timestamp, duration) - Policy expiration check
def within_window(start, end) - Policy time window check
```

**Result:**
- ✅ ONE best implementation of time ops in aggregate-library
- ✅ Phronesis uses aggregate-library for basic time ops
- ✅ Phronesis keeps only policy-specific time logic
- ✅ **Less code, better quality, single source of truth**

---

## Visual Structure

```
aggregate-library/
├── lib/aggregate_library/
│   ├── result.ex           # Elixir-style Result/Option
│   ├── collections.ex      # Haskell-style map/filter/fold
│   ├── file_io.ex          # Elixir-style file ops
│   ├── stream.ex           # Cross-language lazy iteration
│   ├── time.ex             # Rust-style precision time ops
│   │
│   └── a_lib/              # Compiler utilities (language-agnostic)
│       ├── token.ex        # Generic token structure
│       ├── position.ex     # Source location tracking
│       ├── error.ex        # Error representation
│       ├── string_utils.ex # Levenshtein, indent, wrap
│       ├── color_output.ex # ANSI colors
│       └── ast/
│           └── traversal.ex # AST tree walking
│
├── mix.exs                 # Elixir project config
└── COMPOSITION-GUIDE.md    # This file
```

---

## Integration Example

### Before

Phronesis used its own internal utilities:
```elixir
# phronesis/lib/phronesis/lexer.ex
result = Phronesis.Internal.token_result(...)
```

### After

Phronesis uses aggregate-library:
```elixir
# phronesis/mix.exs
defp deps do
  [{:aggregate_library, path: "../aggregate-library"}]
end

# phronesis/lib/phronesis/lexer.ex
alias AggregateLibrary.Result
result = Result.ok(token)
```

---

## Benefits

1. **No Duplication**: Only ONE implementation of string split, file read, time operations
2. **Best Quality**: Each function uses the best implementation from any of the three languages
3. **Single Source of Truth**: Fix a bug once, benefits all languages
4. **Leaner Codebase**: Phronesis stdlib shrinks (remove universal parts, keep domain-specific)
5. **Clear Boundaries**: Universal (aggregate-library) vs. domain (language stdlib)

---

## When to Add to aggregate-library

**✅ Add if:**
- Pattern exists in ALL THREE language stlibs (Phronesis, Rust, Haskell)
- Implementation is truly language-agnostic
- You can identify which implementation is "best"

**❌ Do NOT add if:**
- Pattern exists in only one or two languages
- Logic is domain-specific (policies, networking, consensus)
- Language-specific features (ownership, monads, macros)

---

## Fallback Strategy

If aggregate-library abstraction feels forced or doesn't work well:

1. Revert changes
2. Use language stdlib directly
3. Document why abstraction wasn't suitable

The goal is to **reduce duplication**, not force abstractions that don't fit.

---

## Next Steps for Other Languages

When you want to extend aggregate-library to other languages (Solo, Duet, Ensemble, etc.):

1. Analyze their stlibs for common patterns
2. Compare with existing aggregate-library modules
3. Extract common parts if they exist
4. Choose best implementation (might be from new language)
5. Update aggregate-library with enhanced version

**Rule:** Only add patterns that are genuinely universal. Don't force it.

---

## Success Metrics

✅ **Phronesis stdlib is leaner** (domain-specific only)
✅ **aggregate-library has universal patterns** (best-of-breed)
✅ **No duplication** across language stlibs
✅ **Clear separation** of concerns
✅ **Easy to understand** where code belongs

---

## Quick Reference

| Module | Source | Purpose |
|--------|--------|---------|
| Result | Elixir | Error handling |
| Collections | Haskell | Map/filter/reduce |
| FileIO | Elixir | File operations |
| Stream | Cross-language | Lazy iteration |
| Time | Rust | Time/duration |
| ALib.Token | Custom | Compiler tokens |
| ALib.Position | Custom | Source locations |
| ALib.Error | Custom | Error messages |
| ALib.StringUtils | Custom | String algorithms |
| ALib.ColorOutput | Custom | Terminal colors |
| ALib.AST.Traversal | Custom | AST walking |

---

## Conclusion

aggregate-library is **NOT** a monolithic standard library replacement. It's a **carefully curated set of universal patterns** extracted from the intersection of three mature language stlibs, choosing the best implementation for each.

Each language keeps its unique strengths in its own stdlib. aggregate-library just provides a common foundation to avoid reinventing the wheel.
