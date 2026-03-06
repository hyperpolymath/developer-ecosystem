# CLAUDE.md - cadre-tea-router

## Project Overview

This is `cadre-tea-router`, a type-safe routing integration for rescript-tea applications.
It wraps `cadre-router` with TEA-specific primitives (`Tea.Cmd.t`, `Tea.Sub.t`).

## Language Policy

Same as cadre-router - see the Hyperpolymath Standard:
- **ReScript** for all source code
- **Deno** for runtime (not Node.js)
- No TypeScript

## Key Files

- `src/TeaRouter.res` - Main functor implementation
- `src/TeaRouter.resi` - Public interface
- `tests/TeaRouter_test.res` - Tests
- `examples/basic/` - Example TEA application

## Dependencies

- `cadre-router` - URL parsing and navigation primitives
- `rescript-tea` - The Elm Architecture for ReScript

## Building

```bash
deno task build   # Compile ReScript
deno task test    # Run tests
deno task watch   # Watch mode
```

## Architecture

The main export is `TeaRouter.Make`, a functor that takes:
- Route type and parser from cadre-router
- Message constructors for route changes

And produces:
- `init` - Parse current URL
- `push/replace` - Navigation commands
- `urlChanges` - URL change subscription
- `link` - Type-safe link helper

## Testing

Tests verify:
- Type correctness (compile-time)
- URL parsing through the router
- Roundtrip (serialize → parse → same route)
- Message construction
