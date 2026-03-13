# Changelog

All notable changes to Synapse will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Nothing yet

### Changed
- Nothing yet

### Fixed
- Nothing yet

## [0.1.0-alpha] - 2025-12-14

Initial alpha release of Synapse - the Rust-to-SwiftUI meta-compiler.

### Added

**Core Features**
- Zig-based Rust struct parser (`src/parser/rust_parser.zig`)
- SwiftUI ViewModel template system (`src/templates/swift_templates.zig`)
- Command-line interface (`src/generators/synapse.zig`)

**Rust Parsing**
- Support for `#[derive(Synapse)]`, `#[derive(DriftUI)]`, `#[derive(SwiftBridge)]`
- Field extraction with type inference
- Documentation comment preservation
- Visibility modifier handling (`pub`)

**Swift Generation**
- iOS 17+ `@Observable` macro support
- iOS 14-16 `@ObservableObject` protocol support (legacy mode)
- `@MainActor` annotation for UI thread safety
- Convenience `from(rust:)` initializer extension
- SwiftUI Preview provider generation

**Type Mapping**
- Rust primitives: `i32`, `i64`, `u32`, `u64`, `f32`, `f64`, `bool`
- `String` to Swift `String`
- `Vec<T>` to `[Any]` (generic extraction TODO)
- `Option<T>` to `Any?` (generic extraction TODO)
- Custom types passed through

**Developer Experience**
- Justfile with `gen-ui`, `gen-ui-legacy`, `build`, `test`, `clean` commands
- Example Rust models (`examples/rust/models.rs`)
- Comprehensive documentation

**Compliance**
- RSR Gold repository compliance
- SPDX license headers on all source files
- `.well-known/` directory with RFC-compliant files
- Full documentation suite (README, SECURITY, CONTRIBUTING, etc.)

**CI/CD**
- GitLab CI pipeline for build, test, validate
- Automated SPDX header checking
- RSR compliance validation

### Known Limitations
- Generic type parameters not extracted (`Vec<String>` → `[Any]` not `[String]`)
- No enum support yet
- No nested struct support yet
- Build not verified on all platforms

### Technical Details
- Written in Zig 0.11+ (no external dependencies)
- Parses Rust source directly (no AST library)
- Template-based generation for easy Apple spec updates
- Zero runtime dependencies in generated code

---

## Release Notes Format

Each release includes:
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features to be removed in future versions
- **Removed**: Features removed in this version
- **Fixed**: Bug fixes
- **Security**: Security-related changes

## Versioning Policy

- **Major** (X.0.0): Breaking changes to CLI interface or generated output format
- **Minor** (0.X.0): New features, new supported types, template improvements
- **Patch** (0.0.X): Bug fixes, documentation updates, internal improvements

## Upgrade Guide

When upgrading between versions:

1. Read the changelog for breaking changes
2. Regenerate all Swift files: `just gen-ui`
3. Test your application
4. Update any custom templates if needed
