# rescript-deno

Start ReScript projects with Deno, not npm.

## Why

ReScript's compiler ships as an npm package, but your project doesn't need npm. This tool wraps `rescript` to work natively with Deno's module system — no `npm install`, no `node_modules` sprawl, no `package.json`.

## Install

```bash
# No install needed — run directly:
deno run -A https://raw.githubusercontent.com/hyperpolymath/developer-ecosystem/main/rescript-ecosystem/rescript-deno-starter/src/cli.js init my-app
```

## Usage

```bash
# Create a new project
rescript-deno init my-app
cd my-app

# Build
deno task build

# Watch mode
deno task dev

# Run
deno run src/Main.res.mjs

# Clean
deno task res:clean
```

## What it generates

```
my-app/
├── deno.json         # Deno config with ReScript tasks
├── rescript.json      # ReScript compiler config (esmodule, in-source)
├── src/
│   └── Main.res      # Entry point
└── .gitignore
```

The generated `deno.json` maps `@rescript/core` and `@rescript/runtime` to npm packages via Deno's npm specifier support. No `package.json` needed.

## How it works

Deno can import npm packages directly via `npm:` specifiers. The ReScript compiler runs through `deno run npm:rescript`, and the compiled `.res.mjs` output is native ES modules that Deno runs directly.

## License

PMPL-1.0-or-later
