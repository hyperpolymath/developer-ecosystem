<!-- SPDX-License-Identifier: MIT AND Palimpsest-0.8 -->
<!-- SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- RSR (Rhodium Standard Repositories) compliance
- Nix flake for reproducible development environment
- Justfile for task automation
- SPDX license headers on all source files

## [0.1.0] - 2024-12-06

### Added
- Initial release of rescript-tea
- Core modules:
  - `Tea_Cmd` - Commands for side effects
  - `Tea_Sub` - Subscriptions for external events
  - `Tea_App` - Application runtime with React integration
  - `Tea_Html` - Type-safe HTML helpers
  - `Tea_Json` - Elm-style JSON decoders
  - `Tea_Test` - Testing utilities
  - `Tea` - Main entry point
- Subscription types:
  - `Sub.Time.every` - Timer subscriptions
  - `Sub.Keyboard.downs/ups` - Keyboard events
  - `Sub.Mouse.clicks/moves` - Mouse events
  - `Sub.Window.resizes` - Window resize events
- Counter example demonstrating basic TEA patterns
- React hooks-based runtime implementation
- Functor-based API (`Make`, `MakeSimple`, `MakeWithDispatch`)

### Technical Details
- Built on React 18+ with hooks
- Uses Belt library for collections
- ReScript 11+ compatibility
- ESModule output format

[Unreleased]: https://github.com/Hyperpolymath/rescript-tea/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Hyperpolymath/rescript-tea/releases/tag/v0.1.0
