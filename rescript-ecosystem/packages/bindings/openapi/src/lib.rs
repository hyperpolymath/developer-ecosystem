// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

//! rescript-openapi - Generate type-safe ReScript clients from OpenAPI specifications
//!
//! This library provides the core functionality for parsing OpenAPI specs
//! and generating ReScript code including types, validators, and HTTP clients.

#![forbid(unsafe_code)]
pub mod codegen;
pub mod ir;
pub mod parser;
