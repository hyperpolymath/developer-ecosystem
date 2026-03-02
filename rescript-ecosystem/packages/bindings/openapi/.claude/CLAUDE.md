# rescript-openapi Project Instructions

## Follow-up Action Required

**Pending: Publish to crates.io**

The project is complete and ready for publishing. When the user returns, prompt them to complete the crates.io publish:

```bash
cargo login  # Get API token from https://crates.io/me
cargo publish
```

The dry run verified successfully (31 files, 185KB). Once published, it will be live at https://crates.io/crates/rescript-openapi

## Project Overview

Rust CLI tool that generates type-safe ReScript clients from OpenAPI 3.x specifications.

**Generates:**
- `ApiTypes.res` - Type definitions (records, variants, enums)
- `ApiSchema.res` - rescript-schema v9 validators
- `ApiClient.res` - HTTP client with @glennsl/rescript-fetch

## Key Features Implemented

- oneOf/anyOf → ReScript variant types with payloads
- String enums → Polymorphic variants
- Auth support: Bearer token, API key
- CLI flags: `--watch` (file watching), `--dry-run`
- Topological sorting for dependency ordering

## Commands

```bash
# Generate code
cargo run -- generate -i spec.yaml -o src/api

# With options
cargo run -- generate -i spec.yaml -o src/api --watch --dry-run

# Validate spec
cargo run -- validate -i spec.yaml

# Run tests
cargo test

# Security audit
cargo audit
```

## Dependencies (ReScript side)

```json
{
  "bs-dependencies": ["@rescript/core", "rescript-schema", "@glennsl/rescript-fetch"]
}
```

## Code Style

- SPDX headers on all files
- Rust 2021 edition
- Use `anyhow` for error handling
- Use `heck` for case conversion
- Snapshot tests with `insta`
