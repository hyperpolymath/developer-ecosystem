// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

//! rescript-openapi - Generate type-safe ReScript clients from OpenAPI specifications
//!
//! This library provides the core functionality for parsing OpenAPI specs
//! and generating ReScript code including types, validators, and HTTP clients.

pub mod codegen;
pub mod ir;
pub mod parser;
